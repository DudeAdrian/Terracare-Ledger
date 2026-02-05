/**
 * TerraCare Ledger v2.0 - Revenue API Routes
 * 
 * Handles:
 * - POST /revenue/webhook: Stripe/NDIS payment webhooks
 * - GET /revenue/distribution: Get distribution stats
 * - GET /revenue/investor/:address: Get SEAL investor info
 */

import { Router } from 'express';
import { body, param, validationResult } from 'express-validator';
import { ethers } from 'ethers';
import logger from '../logger.js';
import { authenticateJWT, validateRequest, requireRole } from '../middleware/auth.js';
import { verifyWebhookSignature } from '../middleware/webhookAuth.js';
import ContractService from '../services/contractService.js';

const router = Router();
const contractService = new ContractService();

/**
 * POST /api/revenue/webhook
 * Receive Stripe/NDIS payment webhooks
 * Validates webhook signature, calls RevenueDistributor.distribute()
 */
router.post(
  '/webhook',
  // Webhook auth uses signature validation, not JWT
  verifyWebhookSignature,
  [
    body('type').isString().notEmpty(), // 'stripe' or 'ndis'
    body('amount').isNumeric(), // Amount in cents (Stripe) or dollars (NDIS)
    body('currency').isString().isLength({ min: 3, max: 3 }),
    body('paymentId').isString().notEmpty(),
    body('metadata').isObject().optional(),
  ],
  validateRequest,
  async (req, res) => {
    try {
      const { type, amount, currency, paymentId, metadata = {} } = req.body;

      // Validate payment type
      if (!['stripe', 'ndis'].includes(type)) {
        return res.status(400).json({
          error: 'Invalid payment type',
          code: 'INVALID_TYPE'
        });
      }

      // Convert amount to wei
      // Stripe: amount is in cents, NDIS: amount is in dollars
      let amountInWei;
      if (type === 'stripe') {
        // Convert cents to ETH (simplified - in production use oracle price feed)
        const ethPrice = await contractService.getETHPriceInUSD();
        const amountInUSD = Number(amount) / 100;
        const amountInETH = amountInUSD / ethPrice;
        amountInWei = ethers.parseEther(amountInETH.toFixed(18));
      } else {
        // NDIS: amount in dollars
        const ethPrice = await contractService.getETHPriceInUSD();
        const amountInETH = Number(amount) / ethPrice;
        amountInWei = ethers.parseEther(amountInETH.toFixed(18));
      }

      if (amountInWei <= 0) {
        return res.status(400).json({
          error: 'Invalid amount',
          code: 'INVALID_AMOUNT'
        });
      }

      // Call RevenueDistributor with the payment
      const tx = await contractService.distributeRevenue({
        value: amountInWei,
        source: type,
        paymentId
      });

      logger.info({
        type,
        amount,
        currency,
        paymentId,
        amountInWei: amountInWei.toString(),
        txHash: tx.hash,
        metadata
      }, 'Revenue distributed');

      // Return immediately (webhooks should respond quickly)
      res.status(202).json({
        success: true,
        received: true,
        txHash: tx.hash,
        distribution: {
          userBuybacks: ethers.formatEther((amountInWei * 30n) / 100n), // 30%
          investorRepayment: ethers.formatEther((amountInWei * 20n) / 100n), // 20%
          operations: ethers.formatEther((amountInWei * 40n) / 100n), // 40%
          reserve: ethers.formatEther((amountInWei * 10n) / 100n), // 10%
        }
      });

    } catch (error) {
      logger.error({ error: error.message, body: req.body }, 'Error processing revenue webhook');
      
      // Return 500 to trigger webhook retry
      res.status(500).json({
        error: 'Failed to process revenue',
        code: 'DISTRIBUTION_FAILED'
      });
    }
  }
);

/**
 * GET /api/revenue/distribution
 * Get revenue distribution statistics
 */
router.get(
  '/distribution',
  authenticateJWT,
  requireRole(['Admin', 'System']),
  async (req, res) => {
    try {
      const stats = await contractService.getRevenueStats();

      res.json({
        totalRevenue: ethers.formatEther(stats.totalRevenue),
        distributed: {
          users: ethers.formatEther(stats.totalToUsers),
          investors: ethers.formatEther(stats.totalToInvestors),
          operations: ethers.formatEther(stats.totalToOperations),
          reserve: ethers.formatEther(stats.totalToReserve)
        },
        seal: {
          totalInvested: ethers.formatEther(stats.totalSEALInvested),
          totalPaid: ethers.formatEther(stats.totalSEALPaid),
          investors: stats.investors.map(inv => ({
            address: inv.investorAddress,
            initialInvestment: ethers.formatEther(inv.initialInvestment),
            repaymentCap: ethers.formatEther(inv.repaymentCap),
            paidAmount: ethers.formatEther(inv.paidAmount),
            capReached: inv.capReached,
            progress: (Number(inv.paidAmount) / Number(inv.repaymentCap) * 100).toFixed(2) + '%'
          }))
        },
        split: {
          userBuybacks: '30%',
          investorRepayment: '20%',
          operations: '40%',
          reserve: '10%'
        }
      });

    } catch (error) {
      logger.error({ error: error.message }, 'Error fetching revenue distribution');
      res.status(500).json({
        error: 'Failed to fetch distribution stats',
        code: 'FETCH_FAILED'
      });
    }
  }
);

/**
 * GET /api/revenue/investor/:address
 * Get SEAL investor information
 */
router.get(
  '/investor/:address',
  authenticateJWT,
  [
    param('address').isEthereumAddress(),
  ],
  validateRequest,
  async (req, res) => {
    try {
      const { address } = req.params;

      const investorInfo = await contractService.getSEALInvestor(address);

      if (!investorInfo || investorInfo.investorAddress === ethers.ZeroAddress) {
        return res.status(404).json({
          error: 'Investor not found',
          code: 'INVESTOR_NOT_FOUND'
        });
      }

      const progress = Number(investorInfo.paidAmount) / Number(investorInfo.repaymentCap);

      res.json({
        address: investorInfo.investorAddress,
        initialInvestment: ethers.formatEther(investorInfo.initialInvestment),
        repaymentCap: ethers.formatEther(investorInfo.repaymentCap),
        paidAmount: ethers.formatEther(investorInfo.paidAmount),
        remaining: ethers.formatEther(investorInfo.repaymentCap - investorInfo.paidAmount),
        capReached: investorInfo.capReached,
        investmentDate: new Date(Number(investorInfo.investmentDate) * 1000).toISOString(),
        progress: (progress * 100).toFixed(2) + '%',
        multiplier: (Number(investorInfo.repaymentCap) / Number(investorInfo.initialInvestment)).toFixed(2) + 'x'
      });

    } catch (error) {
      logger.error({ error: error.message }, 'Error fetching investor info');
      res.status(500).json({
        error: 'Failed to fetch investor info',
        code: 'FETCH_FAILED'
      });
    }
  }
);

/**
 * GET /api/revenue/buyback-price
 * Get current WELL buyback price
 */
router.get(
  '/buyback-price',
  async (req, res) => {
    try {
      const price = await contractService.getWellBuybackPrice();
      
      res.json({
        priceInWei: price.toString(),
        priceInETH: ethers.formatEther(price),
        priceInUSD: await contractService.convertETHtoUSD(price)
      });

    } catch (error) {
      logger.error({ error: error.message }, 'Error fetching buyback price');
      res.status(500).json({
        error: 'Failed to fetch price',
        code: 'FETCH_FAILED'
      });
    }
  }
);

/**
 * POST /api/revenue/sell-well
 * Sell WELL tokens back to the platform
 */
router.post(
  '/sell-well',
  authenticateJWT,
  [
    body('amount').isNumeric(), // Amount in WELL tokens
  ],
  validateRequest,
  async (req, res) => {
    try {
      const { amount } = req.body;
      const userAddress = req.user.address;

      const amountInWei = ethers.parseEther(amount.toString());
      
      // Calculate expected payment
      const price = await contractService.getWellBuybackPrice();
      const expectedPayment = amountInWei * price;

      // Execute sell
      const tx = await contractService.sellWell({
        from: userAddress,
        amount: amountInWei
      });

      logger.info({
        user: userAddress,
        amount: amountInWei.toString(),
        payment: expectedPayment.toString(),
        txHash: tx.hash
      }, 'WELL sold');

      res.json({
        success: true,
        amount: amount,
        paymentInWei: expectedPayment.toString(),
        paymentInETH: ethers.formatEther(expectedPayment),
        txHash: tx.hash
      });

    } catch (error) {
      logger.error({ error: error.message }, 'Error selling WELL');
      res.status(500).json({
        error: 'Failed to sell WELL',
        code: 'SELL_FAILED',
        message: error.message
      });
    }
  }
);

export default router;
