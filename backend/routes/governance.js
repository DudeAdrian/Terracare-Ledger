/**
 * TerraCare Ledger v2.0 - Governance API Routes
 * 
 * Handles:
 * - POST /governance/propose: Create proposal (requires 1000 MINE)
 * - POST /governance/vote: Cast vote on proposal
 * - GET /governance/proposals: List proposals
 * - GET /governance/proposal/:id: Get proposal details
 */

import { Router } from 'express';
import { body, param, validationResult } from 'express-validator';
import { ethers } from 'ethers';
import logger from '../logger.js';
import { authenticateJWT, validateRequest, requireRole } from '../middleware/auth.js';
import ContractService from '../services/contractService.js';

const router = Router();
const contractService = new ContractService();

// Proposal threshold: 1000 MINE
const PROPOSAL_THRESHOLD = ethers.parseEther('1000');

/**
 * POST /api/governance/propose
 * Create a new proposal (requires 1000 MINE staked)
 */
router.post(
  '/propose',
  authenticateJWT,
  [
    body('title').isString().isLength({ min: 10, max: 200 }),
    body('description').isString().isLength({ min: 50, max: 10000 }),
    body('target').isEthereumAddress(),
    body('callData').isString().isLength({ min: 10 }), // 0x + function selector
  ],
  validateRequest,
  async (req, res) => {
    try {
      const { title, description, target, callData } = req.body;
      const proposerAddress = req.user.address;

      // 1. Check voting power (staked MINE)
      const votingPower = await contractService.getVotingPower(proposerAddress);
      
      if (votingPower < PROPOSAL_THRESHOLD) {
        return res.status(403).json({
          error: 'Insufficient voting power',
          code: 'INSUFFICIENT_STAKE',
          required: ethers.formatEther(PROPOSAL_THRESHOLD),
          current: ethers.formatEther(votingPower)
        });
      }

      // 2. Check governance phase
      const currentPhase = await contractService.getGovernancePhase();
      if (currentPhase === 'PoA') {
        // In PoA phase, only validators can propose
        const isValidator = await contractService.isValidator(proposerAddress);
        if (!isValidator) {
          return res.status(403).json({
            error: 'Only validators can propose during PoA phase',
            code: 'VALIDATOR_ONLY'
          });
        }
      }

      // 3. Create proposal
      const tx = await contractService.createProposal({
        proposer: proposerAddress,
        title,
        description,
        target,
        callData
      });

      // Get proposal ID from transaction receipt
      const receipt = await tx.wait();
      const proposalId = receipt.events?.find(e => e.event === 'ProposalCreated')?.args?.id;

      logger.info({
        proposalId: proposalId?.toString(),
        proposer: proposerAddress,
        title,
        target,
        txHash: tx.hash
      }, 'Proposal created');

      res.json({
        success: true,
        proposalId: proposalId?.toString(),
        title,
        proposer: proposerAddress,
        txHash: tx.hash,
        votingStarts: new Date(Date.now() + 60000).toISOString(), // 1 minute buffer
        votingEnds: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString() // 7 days
      });

    } catch (error) {
      logger.error({ error: error.message }, 'Error creating proposal');
      res.status(500).json({
        error: 'Failed to create proposal',
        code: 'PROPOSAL_FAILED',
        message: error.message
      });
    }
  }
);

/**
 * POST /api/governance/vote
 * Cast vote on a proposal
 */
router.post(
  '/vote',
  authenticateJWT,
  [
    body('proposalId').isInt({ min: 1 }),
    body('support').isBoolean(), // true = for, false = against
  ],
  validateRequest,
  async (req, res) => {
    try {
      const { proposalId, support } = req.body;
      const voterAddress = req.user.address;

      // 1. Check voting power
      const votingPower = await contractService.getVotingPower(voterAddress);
      if (votingPower <= 0) {
        return res.status(403).json({
          error: 'No voting power',
          code: 'NO_VOTING_POWER',
          message: 'Stake MINE to gain voting power'
        });
      }

      // 2. Check proposal state
      const proposalState = await contractService.getProposalState(proposalId);
      if (proposalState !== 'Active') {
        return res.status(400).json({
          error: `Proposal is ${proposalState}`,
          code: 'WRONG_STATE',
          state: proposalState
        });
      }

      // 3. Check if already voted
      const hasVoted = await contractService.hasVoted(proposalId, voterAddress);
      if (hasVoted) {
        return res.status(400).json({
          error: 'Already voted on this proposal',
          code: 'ALREADY_VOTED'
        });
      }

      // 4. Cast vote
      const tx = await contractService.castVote({
        voter: voterAddress,
        proposalId,
        support
      });

      logger.info({
        proposalId,
        voter: voterAddress,
        support,
        votes: ethers.formatEther(votingPower),
        txHash: tx.hash
      }, 'Vote cast');

      res.json({
        success: true,
        proposalId,
        voter: voterAddress,
        support,
        votes: ethers.formatEther(votingPower),
        txHash: tx.hash
      });

    } catch (error) {
      logger.error({ error: error.message }, 'Error casting vote');
      res.status(500).json({
        error: 'Failed to cast vote',
        code: 'VOTE_FAILED',
        message: error.message
      });
    }
  }
);

/**
 * GET /api/governance/proposals
 * List all proposals with pagination
 */
router.get(
  '/proposals',
  async (req, res) => {
    try {
      const { page = 1, limit = 10, state } = req.query;

      const proposals = await contractService.getProposals({
        page: Number(page),
        limit: Number(limit),
        state
      });

      res.json({
        proposals: proposals.items.map(p => ({
          id: p.id,
          title: p.title,
          description: p.description.substring(0, 200) + '...',
          proposer: p.proposer,
          state: p.state,
          forVotes: ethers.formatEther(p.forVotes),
          againstVotes: ethers.formatEther(p.againstVotes),
          startTime: new Date(Number(p.startTime) * 1000).toISOString(),
          endTime: new Date(Number(p.endTime) * 1000).toISOString(),
          executed: p.executed
        })),
        pagination: {
          page: Number(page),
          limit: Number(limit),
          total: proposals.total
        }
      });

    } catch (error) {
      logger.error({ error: error.message }, 'Error fetching proposals');
      res.status(500).json({
        error: 'Failed to fetch proposals',
        code: 'FETCH_FAILED'
      });
    }
  }
);

/**
 * GET /api/governance/proposal/:id
 * Get detailed proposal information
 */
router.get(
  '/proposal/:id',
  [
    param('id').isInt({ min: 1 }),
  ],
  validateRequest,
  async (req, res) => {
    try {
      const { id } = req.params;

      const proposal = await contractService.getProposal(id);

      if (!proposal || proposal.id === 0) {
        return res.status(404).json({
          error: 'Proposal not found',
          code: 'PROPOSAL_NOT_FOUND'
        });
      }

      const totalVotes = proposal.forVotes + proposal.againstVotes;
      const forPercentage = totalVotes > 0 
        ? (Number(proposal.forVotes) / Number(totalVotes) * 100).toFixed(2) 
        : 0;

      res.json({
        id: proposal.id,
        title: proposal.title,
        description: proposal.description,
        proposer: proposal.proposer,
        target: proposal.target,
        callData: proposal.callData,
        state: proposal.state,
        votes: {
          for: ethers.formatEther(proposal.forVotes),
          against: ethers.formatEther(proposal.againstVotes),
          total: ethers.formatEther(totalVotes),
          forPercentage: forPercentage + '%',
          quorum: ethers.formatEther(proposal.quorumRequired || 0)
        },
        timeline: {
          created: new Date(Number(proposal.startTime) * 1000).toISOString(),
          votingStarts: new Date(Number(proposal.startTime) * 1000).toISOString(),
          votingEnds: new Date(Number(proposal.endTime) * 1000).toISOString(),
          executed: proposal.executed ? new Date(Number(proposal.executedAt) * 1000).toISOString() : null
        },
        executed: proposal.executed,
        canceled: proposal.canceled
      });

    } catch (error) {
      logger.error({ error: error.message }, 'Error fetching proposal');
      res.status(500).json({
        error: 'Failed to fetch proposal',
        code: 'FETCH_FAILED'
      });
    }
  }
);

/**
 * POST /api/governance/execute
 * Execute a successful proposal
 */
router.post(
  '/execute',
  authenticateJWT,
  [
    body('proposalId').isInt({ min: 1 }),
  ],
  validateRequest,
  async (req, res) => {
    try {
      const { proposalId } = req.body;

      // Check proposal state
      const state = await contractService.getProposalState(proposalId);
      if (state !== 'Succeeded') {
        return res.status(400).json({
          error: `Proposal is ${state}, cannot execute`,
          code: 'WRONG_STATE',
          state
        });
      }

      // Execute proposal (creates timelock operation)
      const tx = await contractService.executeProposal(proposalId);

      logger.info({
        proposalId,
        executor: req.user.address,
        txHash: tx.hash
      }, 'Proposal execution initiated');

      res.json({
        success: true,
        proposalId,
        txHash: tx.hash,
        message: 'Proposal queued for execution (timelock active)'
      });

    } catch (error) {
      logger.error({ error: error.message }, 'Error executing proposal');
      res.status(500).json({
        error: 'Failed to execute proposal',
        code: 'EXECUTION_FAILED'
      });
    }
  }
);

/**
 * GET /api/governance/phase
 * Get current governance phase and transition info
 */
router.get(
  '/phase',
  async (req, res) => {
    try {
      const phase = await contractService.getGovernancePhase();
      const timeUntilNext = await contractService.getTimeUntilNextPhase();
      const validators = await contractService.getValidators();

      res.json({
        currentPhase: phase,
        phases: {
          PoA: 'Proof of Authority (Month 0-18)',
          Transition: 'Gradual Transition (Month 18-24)',
          Cooperative: 'Full Cooperative Ownership (Month 24+)'
        },
        transition: {
          timeUntilNextPhase: timeUntilNext,
          nextPhaseDate: timeUntilNext > 0 
            ? new Date(Date.now() + timeUntilNext * 1000).toISOString()
            : null
        },
        validators: validators,
        proposalThreshold: ethers.formatEther(PROPOSAL_THRESHOLD),
        votingPeriod: '7 days',
        timelockDelay: '2 days'
      });

    } catch (error) {
      logger.error({ error: error.message }, 'Error fetching governance phase');
      res.status(500).json({
        error: 'Failed to fetch phase info',
        code: 'FETCH_FAILED'
      });
    }
  }
);

/**
 * GET /api/governance/delegates/:address
 * Get delegation info for an address
 */
router.get(
  '/delegates/:address',
  [
    param('address').isEthereumAddress(),
  ],
  validateRequest,
  async (req, res) => {
    try {
      const { address } = req.params;

      const delegate = await contractService.getDelegate(address);
      const delegatedPower = await contractService.getDelegatedPower(address);

      res.json({
        address,
        delegatingTo: delegate || null,
        delegatedPower: ethers.formatEther(delegatedPower),
        isDelegating: delegate !== ethers.ZeroAddress
      });

    } catch (error) {
      logger.error({ error: error.message }, 'Error fetching delegation');
      res.status(500).json({
        error: 'Failed to fetch delegation',
        code: 'FETCH_FAILED'
      });
    }
  }
);

/**
 * POST /api/governance/delegate
 * Delegate voting power
 */
router.post(
  '/delegate',
  authenticateJWT,
  [
    body('delegatee').isEthereumAddress(),
  ],
  validateRequest,
  async (req, res) => {
    try {
      const { delegatee } = req.body;
      const delegator = req.user.address;

      if (delegatee.toLowerCase() === delegator.toLowerCase()) {
        return res.status(400).json({
          error: 'Cannot delegate to yourself',
          code: 'SELF_DELEGATION'
        });
      }

      const tx = await contractService.delegate({
        delegator,
        delegatee
      });

      logger.info({
        delegator,
        delegatee,
        txHash: tx.hash
      }, 'Delegation set');

      res.json({
        success: true,
        delegator,
        delegatee,
        txHash: tx.hash
      });

    } catch (error) {
      logger.error({ error: error.message }, 'Error setting delegation');
      res.status(500).json({
        error: 'Failed to delegate',
        code: 'DELEGATION_FAILED'
      });
    }
  }
);

export default router;
