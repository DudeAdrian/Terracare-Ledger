/**
 * TerraCare Ledger v2.0 - Activity API Routes
 * 
 * Handles:
 * - POST /activity/biometric: Receive bracelet streams, validate device signature
 * - POST /activity/therapy: Caregiver marks therapy completion
 * - GET /user/balance/:id: Return MINE and WELL balances
 */

import { Router } from 'express';
import { body, param, validationResult } from 'express-validator';
import { ethers } from 'ethers';
import logger from '../logger.js';
import { authenticateJWT, validateRequest, requireRole } from '../middleware/auth.js';
import { requireOracle } from '../middleware/oracleAuth.js';
import ContractService from '../services/contractService.js';
import AISignerService from '../services/aiSignerService.js';

const router = Router();

// Initialize services
const contractService = new ContractService();
const aiSigner = new AISignerService();

/**
 * POST /api/activity/biometric
 * Receive biometric streams from wearable devices
 * Requires device signature validation
 */
router.post(
  '/biometric',
  authenticateJWT,
  [
    body('deviceId').isString().notEmpty().trim(),
    body('userId').isString().notEmpty().trim(),
    body('data').isObject(),
    body('signature').isString().isLength({ min: 132, max: 132 }), // 0x + 130 hex chars
    body('timestamp').isInt({ min: 0 }),
  ],
  validateRequest,
  async (req, res) => {
    try {
      const { deviceId, userId, data, signature, timestamp } = req.body;

      // 1. Validate device signature against IdentityRegistry
      const isValidDevice = await contractService.validateDeviceSignature(
        deviceId,
        userId,
        data,
        signature
      );

      if (!isValidDevice) {
        logger.warn({ deviceId, userId }, 'Invalid device signature');
        return res.status(403).json({ 
          error: 'Invalid device signature',
          code: 'INVALID_SIGNATURE'
        });
      }

      // 2. Check user identity
      const userAddress = await contractService.getUserAddress(userId);
      if (!userAddress) {
        return res.status(404).json({ 
          error: 'User not found',
          code: 'USER_NOT_FOUND'
        });
      }

      // 3. Check daily rate limit (anti-gaming)
      const remainingPoints = await contractService.getRemainingDailyPoints(userId);
      if (remainingPoints <= 0) {
        return res.status(429).json({
          error: 'Daily points cap reached',
          code: 'DAILY_CAP_REACHED',
          retryAfter: await contractService.getSecondsUntilNextDay(userId)
        });
      }

      // 4. AI Oracle calculates value score
      const valueScore = await aiSigner.calculateBiometricValueScore({
        deviceId,
        userId,
        data,
        timestamp,
        dataQuality: data.quality || 0,
        completeness: data.completeness || 0
      });

      // Cap value score to remaining points
      const actualValueScore = Math.min(valueScore, remainingPoints);

      // 5. Generate activity ID
      const activityId = ethers.keccak256(
        ethers.solidityPacked(
          ['bytes32', 'uint256', 'bytes32', 'uint256'],
          [ethers.encodeBytes32String(userId), timestamp, ethers.encodeBytes32String(deviceId), block.timestamp]
        )
      );

      // 6. AI Oracle signs the activity proof
      const dataHash = ethers.keccak256(ethers.toUtf8Bytes(JSON.stringify(data)));
      const validatorSignature = await aiSigner.signActivityProof({
        activityId,
        userId,
        activityType: 0, // BiometricStream
        dataHash,
        valueScore: actualValueScore
      });

      // 7. Record activity on-chain (backend pays gas, subsidizes for user)
      const tx = await contractService.recordActivity({
        activityId,
        userId,
        activityType: 0, // BiometricStream
        dataHash,
        valueScore: actualValueScore,
        userAddress,
        validatorSignature
      });

      logger.info({
        activityId,
        userId,
        deviceId,
        valueScore: actualValueScore,
        txHash: tx.hash
      }, 'Biometric activity recorded');

      res.json({
        success: true,
        activityId,
        valueScore: actualValueScore,
        mineEarned: actualValueScore * 10, // 10 MINE per point
        txHash: tx.hash,
        remainingPoints: remainingPoints - actualValueScore
      });

    } catch (error) {
      logger.error({ error: error.message, stack: error.stack }, 'Error recording biometric activity');
      res.status(500).json({ 
        error: 'Failed to record activity',
        code: 'RECORD_FAILED'
      });
    }
  }
);

/**
 * POST /api/activity/therapy
 * Caregiver marks therapy completion
 * Validates AccessControl permissions
 */
router.post(
  '/therapy',
  authenticateJWT,
  requireRole(['Caregiver', 'Admin', 'System']),
  [
    body('patientUserId').isString().notEmpty().trim(),
    body('therapyType').isString().notEmpty().trim(),
    body('duration').isInt({ min: 1 }),
    body('completionDate').isISO8601(),
    body('notesHash').isString().isLength({ min: 66, max: 66 }).optional(),
  ],
  validateRequest,
  async (req, res) => {
    try {
      const { patientUserId, therapyType, duration, completionDate, notesHash } = req.body;
      const caregiverAddress = req.user.address;

      // 1. Get patient address
      const patientAddress = await contractService.getUserAddress(patientUserId);
      if (!patientAddress) {
        return res.status(404).json({ 
          error: 'Patient not found',
          code: 'PATIENT_NOT_FOUND'
        });
      }

      // 2. Check caregiver has access to patient
      const hasAccess = await contractService.checkAccess(patientAddress, caregiverAddress);
      if (!hasAccess) {
        return res.status(403).json({
          error: 'No access to patient records',
          code: 'ACCESS_DENIED'
        });
      }

      // 3. Check daily rate limit for patient
      const remainingPoints = await contractService.getRemainingDailyPoints(patientUserId);
      if (remainingPoints < 20) { // Minimum for therapy completion
        return res.status(429).json({
          error: 'Patient daily points cap reached',
          code: 'DAILY_CAP_REACHED'
        });
      }

      // 4. Calculate value score based on therapy
      const valueScore = Math.min(20, remainingPoints); // Therapy completion = 20 points max

      // 5. Generate activity ID
      const activityId = ethers.keccak256(
        ethers.solidityPacked(
          ['bytes32', 'address', 'uint256', 'uint256'],
          [
            ethers.encodeBytes32String(patientUserId),
            caregiverAddress,
            Date.parse(completionDate),
            block.timestamp
          ]
        )
      );

      const dataHash = notesHash || ethers.keccak256(ethers.toUtf8Bytes(therapyType));

      // 6. AI Oracle signs
      const validatorSignature = await aiSigner.signActivityProof({
        activityId,
        userId: patientUserId,
        activityType: 1, // TherapyCompletion
        dataHash,
        valueScore
      });

      // 7. Record activity (MINE minted to patient)
      const tx = await contractService.recordActivity({
        activityId,
        userId: patientUserId,
        activityType: 1, // TherapyCompletion
        dataHash,
        valueScore,
        userAddress: patientAddress,
        validatorSignature
      });

      logger.info({
        activityId,
        patientUserId,
        caregiverAddress,
        therapyType,
        duration,
        valueScore,
        txHash: tx.hash
      }, 'Therapy completion recorded');

      res.json({
        success: true,
        activityId,
        patientUserId,
        therapyType,
        duration,
        valueScore,
        mineEarned: valueScore * 10,
        txHash: tx.hash,
        remainingPoints: remainingPoints - valueScore
      });

    } catch (error) {
      logger.error({ error: error.message }, 'Error recording therapy completion');
      res.status(500).json({ 
        error: 'Failed to record therapy',
        code: 'RECORD_FAILED'
      });
    }
  }
);

/**
 * GET /api/user/balance/:userId
 * Get MINE and WELL balances for a user
 */
router.get(
  '/user/balance/:userId',
  authenticateJWT,
  [
    param('userId').isString().notEmpty().trim(),
  ],
  validateRequest,
  async (req, res) => {
    try {
      const { userId } = req.params;

      const userAddress = await contractService.getUserAddress(userId);
      if (!userAddress) {
        return res.status(404).json({ 
          error: 'User not found',
          code: 'USER_NOT_FOUND'
        });
      }

      // Get balances
      const [mineBalance, wellBalance, stakedMine, votingPower] = await Promise.all([
        contractService.getMineBalance(userAddress),
        contractService.getWellBalance(userAddress),
        contractService.getStakedMine(userAddress),
        contractService.getVotingPower(userAddress)
      ]);

      // Get cooperative membership status
      const isMember = await contractService.isCooperativeMember(userAddress);

      res.json({
        userId,
        address: userAddress,
        balances: {
          mine: ethers.formatEther(mineBalance),
          well: ethers.formatEther(wellBalance),
          stakedMine: ethers.formatEther(stakedMine),
          votingPower: ethers.formatEther(votingPower)
        },
        membership: {
          isCooperativeMember: isMember,
          canPropose: votingPower >= ethers.parseEther('1000'),
          canVote: votingPower > 0
        },
        formatted: {
          mine: Number(ethers.formatEther(mineBalance)).toFixed(2),
          well: Number(ethers.formatEther(wellBalance)).toFixed(4),
          staked: Number(ethers.formatEther(stakedMine)).toFixed(2)
        }
      });

    } catch (error) {
      logger.error({ error: error.message }, 'Error fetching user balance');
      res.status(500).json({ 
        error: 'Failed to fetch balance',
        code: 'FETCH_FAILED'
      });
    }
  }
);

/**
 * GET /api/user/activities/:userId
 * Get activity history for a user
 */
router.get(
  '/user/activities/:userId',
  authenticateJWT,
  [
    param('userId').isString().notEmpty().trim(),
  ],
  validateRequest,
  async (req, res) => {
    try {
      const { userId } = req.params;
      const { page = 1, limit = 20 } = req.query;

      const activities = await contractService.getUserActivities(userId, page, limit);

      res.json({
        userId,
        activities: activities.map(a => ({
          activityId: a.activityId,
          type: a.activityType,
          valueScore: a.valueScore,
          timestamp: a.timestamp,
          rewarded: a.rewarded,
          txHash: a.txHash
        })),
        pagination: {
          page: Number(page),
          limit: Number(limit),
          total: activities.total
        }
      });

    } catch (error) {
      logger.error({ error: error.message }, 'Error fetching user activities');
      res.status(500).json({ 
        error: 'Failed to fetch activities',
        code: 'FETCH_FAILED'
      });
    }
  }
);

/**
 * GET /api/user/daily-status/:userId
 * Get daily points status for a user
 */
router.get(
  '/user/daily-status/:userId',
  authenticateJWT,
  [
    param('userId').isString().notEmpty().trim(),
  ],
  validateRequest,
  async (req, res) => {
    try {
      const { userId } = req.params;

      const [usedPoints, remainingPoints, nextReset] = await Promise.all([
        contractService.getUsedDailyPoints(userId),
        contractService.getRemainingDailyPoints(userId),
        contractService.getSecondsUntilNextDay(userId)
      ]);

      res.json({
        userId,
        dailyCap: 100,
        usedPoints,
        remainingPoints,
        nextResetIn: nextReset,
        canEarn: remainingPoints > 0
      });

    } catch (error) {
      logger.error({ error: error.message }, 'Error fetching daily status');
      res.status(500).json({ 
        error: 'Failed to fetch daily status',
        code: 'FETCH_FAILED'
      });
    }
  }
);

export default router;
