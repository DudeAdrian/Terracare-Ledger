/**
 * TerraCare Ledger v2.0 - AI Signer Service
 * 
 * AI engine that:
 * - Calculates valueScore based on biometric quality, therapy adherence, data uniqueness
 * - Signs activity proofs with validator key before on-chain submission
 * - Provides anti-gaming detection
 */

import { ethers } from 'ethers';
import crypto from 'crypto';
import logger from '../logger.js';

class AISignerService {
  constructor() {
    // AI Oracle private key for signing
    this.privateKey = process.env.AI_SIGNER_PRIVATE_KEY;
    this.wallet = this.privateKey ? new ethers.Wallet(this.privateKey) : null;
    
    // Quality scoring weights
    this.weights = {
      biometric: {
        dataCompleteness: 0.3,
        signalQuality: 0.4,
        timestampConsistency: 0.2,
        deviceTrust: 0.1
      },
      therapy: {
        sessionDuration: 0.3,
        adherenceScore: 0.4,
        outcomeMetrics: 0.3
      },
      data: {
        dataSize: 0.2,
        anonymizationLevel: 0.3,
        uniquenessScore: 0.5
      }
    };

    // Cache for uniqueness detection
    this.dataHashCache = new Map();
    this.CACHE_SIZE = 10000;
    this.CACHE_TTL = 24 * 60 * 60 * 1000; // 24 hours

    // Sybil detection tracking
    this.userActivityPatterns = new Map();
    this.SYBIL_THRESHOLD = 50; // Max activities per hour before flagging
  }

  /**
   * Calculate value score for biometric stream data
   * @param {Object} params - Biometric data parameters
   * @returns {number} Value score (0-100)
   */
  async calculateBiometricValueScore({
    deviceId,
    userId,
    data,
    timestamp,
    dataQuality = 0,
    completeness = 0
  }) {
    logger.debug({ deviceId, userId }, 'Calculating biometric value score');

    const scores = {
      // Data completeness (0-100)
      completeness: Math.min(100, completeness * 100),
      
      // Signal quality from device (0-100)
      signalQuality: Math.min(100, dataQuality * 100),
      
      // Timestamp consistency (is data recent and consistent?)
      timestampConsistency: this._calculateTimestampScore(timestamp),
      
      // Device trust score (based on device history)
      deviceTrust: await this._calculateDeviceTrust(deviceId)
    };

    // Calculate weighted score
    const weights = this.weights.biometric;
    const valueScore = Math.round(
      scores.completeness * weights.dataCompleteness +
      scores.signalQuality * weights.signalQuality +
      scores.timestampConsistency * weights.timestampConsistency +
      scores.deviceTrust * weights.deviceTrust
    );

    // Cap at 100
    const finalScore = Math.min(100, Math.max(0, valueScore));

    logger.info({
      userId,
      deviceId,
      scores,
      finalScore
    }, 'Biometric value score calculated');

    return finalScore;
  }

  /**
   * Calculate value score for therapy completion
   * @param {Object} params - Therapy session parameters
   * @returns {number} Value score (0-100)
   */
  async calculateTherapyValueScore({
    duration,
    adherenceScore,
    outcomeMetrics = {},
    therapyType
  }) {
    const scores = {
      // Session duration (optimal: 30-60 minutes)
      sessionDuration: this._calculateDurationScore(duration),
      
      // Adherence to protocol (0-100)
      adherence: Math.min(100, adherenceScore * 100),
      
      // Outcome metrics improvement
      outcome: this._calculateOutcomeScore(outcomeMetrics)
    };

    const weights = this.weights.therapy;
    const valueScore = Math.round(
      scores.sessionDuration * weights.sessionDuration +
      scores.adherence * weights.adherenceScore +
      scores.outcome * weights.outcomeMetrics
    );

    return Math.min(100, Math.max(0, valueScore));
  }

  /**
   * Calculate value score for data contribution
   * @param {Object} params - Data contribution parameters
   * @returns {number} Value score (0-100)
   */
  async calculateDataValueScore({
    dataSize,
    isAnonymized,
    dataHash,
    dataType
  }) {
    // Check uniqueness
    const uniquenessScore = await this._calculateUniquenessScore(dataHash);

    const scores = {
      // Data size (larger datasets more valuable, but diminishing returns)
      size: Math.min(100, Math.log2(dataSize / 1024 + 1) * 10),
      
      // Anonymization bonus
      anonymization: isAnonymized ? 100 : 0,
      
      // Uniqueness (is this new data or duplicate?)
      uniqueness: uniquenessScore
    };

    const weights = this.weights.data;
    const valueScore = Math.round(
      scores.size * weights.dataSize +
      scores.anonymization * weights.anonymizationLevel +
      scores.uniqueness * weights.uniquenessScore
    );

    // Store hash for future uniqueness checks
    this._cacheDataHash(dataHash);

    return Math.min(100, Math.max(0, valueScore));
  }

  /**
   * Sign activity proof with AI Oracle key
   * @param {Object} activity - Activity to sign
   * @returns {string} Signature
   */
  async signActivityProof({
    activityId,
    userId,
    activityType,
    dataHash,
    valueScore
  }) {
    if (!this.wallet) {
      throw new Error('AI Signer not initialized - no private key');
    }

    // Create structured hash for signing
    const messageHash = ethers.keccak256(
      ethers.solidityPacked(
        ['bytes32', 'bytes32', 'uint8', 'bytes32', 'uint256', 'uint256'],
        [
          activityId,
          ethers.encodeBytes32String(userId),
          activityType,
          dataHash,
          valueScore,
          Math.floor(Date.now() / 1000) // Timestamp for replay protection
        ]
      )
    );

    // Sign with Ethereum personal sign
    const signature = await this.wallet.signMessage(ethers.getBytes(messageHash));

    logger.debug({
      activityId,
      userId,
      validator: this.wallet.address
    }, 'Activity proof signed');

    return signature;
  }

  /**
   * Verify activity signature
   * @param {Object} activity - Activity to verify
   * @param {string} signature - Signature to verify
   * @returns {boolean} Is valid
   */
  async verifyActivitySignature(activity, signature) {
    try {
      const messageHash = ethers.keccak256(
        ethers.solidityPacked(
          ['bytes32', 'bytes32', 'uint8', 'bytes32', 'uint256', 'uint256'],
          [
            activity.activityId,
            ethers.encodeBytes32String(activity.userId),
            activity.activityType,
            activity.dataHash,
            activity.valueScore,
            activity.timestamp
          ]
        )
      );

      const recoveredAddress = ethers.verifyMessage(
        ethers.getBytes(messageHash),
        signature
      );

      // Check if recovered address is an authorized validator
      return recoveredAddress === this.wallet?.address;
    } catch (error) {
      logger.error({ error: error.message }, 'Signature verification failed');
      return false;
    }
  }

  /**
   * Anti-gaming: Detect suspicious activity patterns
   * @param {string} userId - User to check
   * @param {Object} activity - Activity data
   * @returns {Object} Detection result
   */
  async detectGaming({ userId, activityType, timestamp, deviceId }) {
    const now = Date.now();
    const hourAgo = now - 60 * 60 * 1000;

    // Get or initialize user pattern
    if (!this.userActivityPatterns.has(userId)) {
      this.userActivityPatterns.set(userId, []);
    }

    const patterns = this.userActivityPatterns.get(userId);
    
    // Clean old entries
    const recentPatterns = patterns.filter(p => p.timestamp > hourAgo);
    
    // Add current activity
    recentPatterns.push({
      activityType,
      timestamp: now,
      deviceId
    });

    this.userActivityPatterns.set(userId, recentPatterns);

    // Detect patterns
    const alerts = [];

    // 1. Too many activities per hour
    if (recentPatterns.length > this.SYBIL_THRESHOLD) {
      alerts.push({
        type: 'RATE_EXCEEDED',
        severity: 'HIGH',
        message: `User exceeded ${this.SYBIL_THRESHOLD} activities per hour`,
        count: recentPatterns.length
      });
    }

    // 2. Rapid-fire from same device
    const deviceActivities = recentPatterns.filter(p => p.deviceId === deviceId);
    if (deviceActivities.length > 20) {
      alerts.push({
        type: 'DEVICE_SPAM',
        severity: 'MEDIUM',
        message: 'Excessive activity from single device',
        deviceId
      });
    }

    // 3. Activity type distribution (should be varied)
    const typeCounts = {};
    recentPatterns.forEach(p => {
      typeCounts[p.activityType] = (typeCounts[p.activityType] || 0) + 1;
    });
    
    const dominantType = Object.entries(typeCounts)
      .sort((a, b) => b[1] - a[1])[0];
    
    if (dominantType && dominantType[1] / recentPatterns.length > 0.8) {
      alerts.push({
        type: 'MONOTONOUS_ACTIVITY',
        severity: 'LOW',
        message: 'User activity is too uniform',
        dominantType: dominantType[0]
      });
    }

    const isSuspicious = alerts.some(a => a.severity === 'HIGH');
    const shouldBlock = alerts.filter(a => a.severity === 'HIGH').length >= 2;

    if (alerts.length > 0) {
      logger.warn({
        userId,
        alerts,
        isSuspicious,
        shouldBlock
      }, 'Gaming detection alert');
    }

    return {
      isSuspicious,
      shouldBlock,
      alerts,
      activityCount: recentPatterns.length
    };
  }

  // ============ Helper Methods ============

  _calculateTimestampScore(timestamp) {
    const now = Math.floor(Date.now() / 1000);
    const age = now - timestamp;
    
    // Data should be recent (within last hour)
    if (age < 300) return 100; // < 5 minutes: perfect
    if (age < 3600) return 80; // < 1 hour: good
    if (age < 86400) return 50; // < 1 day: acceptable
    return 20; // > 1 day: stale
  }

  async _calculateDeviceTrust(deviceId) {
    // In production: query device registry for trust score
    // For now, return high trust for known device patterns
    if (deviceId.startsWith('0x') && deviceId.length === 42) {
      return 90; // Blockchain-registered device
    }
    return 70; // Unknown device
  }

  _calculateDurationScore(durationMinutes) {
    // Optimal therapy session: 30-60 minutes
    if (durationMinutes >= 30 && durationMinutes <= 60) return 100;
    if (durationMinutes >= 20 && durationMinutes < 30) return 80;
    if (durationMinutes > 60 && durationMinutes <= 90) return 70;
    if (durationMinutes < 20) return durationMinutes * 3; // Too short
    return Math.max(0, 100 - (durationMinutes - 90)); // Too long
  }

  _calculateOutcomeScore(metrics) {
    // Calculate based on improvement in health metrics
    let score = 50; // Baseline
    
    if (metrics.painReduction) score += metrics.painReduction * 20;
    if (metrics.mobilityImprovement) score += metrics.mobilityImprovement * 20;
    if (metrics.adherenceRate) score += metrics.adherenceRate * 10;
    
    return Math.min(100, Math.max(0, score));
  }

  async _calculateUniquenessScore(dataHash) {
    // Check if we've seen this hash before
    const cached = this.dataHashCache.get(dataHash);
    
    if (cached) {
      // Data is not unique
      const age = Date.now() - cached.timestamp;
      if (age < this.CACHE_TTL) {
        return 20; // Recent duplicate: low score
      }
      return 50; // Old duplicate: medium score
    }
    
    // Data is unique
    return 100;
  }

  _cacheDataHash(dataHash) {
    // Clean cache if too large
    if (this.dataHashCache.size >= this.CACHE_SIZE) {
      const now = Date.now();
      for (const [hash, entry] of this.dataHashCache.entries()) {
        if (now - entry.timestamp > this.CACHE_TTL) {
          this.dataHashCache.delete(hash);
        }
      }
    }

    this.dataHashCache.set(dataHash, {
      timestamp: Date.now(),
      count: (this.dataHashCache.get(dataHash)?.count || 0) + 1
    });
  }

  /**
   * Get AI validator address
   */
  getValidatorAddress() {
    return this.wallet?.address || null;
  }

  /**
   * Health check
   */
  async healthCheck() {
    return {
      status: this.wallet ? 'healthy' : 'not_configured',
      validatorAddress: this.wallet?.address,
      cacheSize: this.dataHashCache.size,
      trackedUsers: this.userActivityPatterns.size
    };
  }
}

export default AISignerService;
