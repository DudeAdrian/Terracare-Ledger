/**
 * TerraCare Ledger v2.0 - Webhook Authentication Middleware
 * 
 * Validates Stripe/NDIS webhook signatures
 */

import crypto from 'crypto';
import logger from '../logger.js';

const STRIPE_WEBHOOK_SECRET = process.env.STRIPE_WEBHOOK_SECRET || '';
const NDIS_WEBHOOK_SECRET = process.env.NDIS_WEBHOOK_SECRET || '';

/**
 * Middleware to validate webhook signatures
 */
export function verifyWebhookSignature(req, res, next) {
  const signature = req.headers['x-webhook-signature'] || req.headers['stripe-signature'];
  const timestamp = req.headers['x-webhook-timestamp'];
  const source = req.body.type; // 'stripe' or 'ndis'

  if (!signature) {
    return res.status(401).json({
      error: 'Webhook signature required',
      code: 'SIGNATURE_REQUIRED'
    });
  }

  try {
    let isValid = false;

    if (source === 'stripe') {
      isValid = verifyStripeSignature(req);
    } else if (source === 'ndis') {
      isValid = verifyNDISSignature(req);
    } else {
      // Generic webhook validation
      isValid = verifyGenericSignature(req);
    }

    if (!isValid) {
      logger.warn({ source, signature: signature.substring(0, 20) }, 'Invalid webhook signature');
      return res.status(401).json({
        error: 'Invalid webhook signature',
        code: 'INVALID_SIGNATURE'
      });
    }

    next();
  } catch (error) {
    logger.error({ error: error.message }, 'Webhook signature verification error');
    return res.status(401).json({
      error: 'Signature verification failed',
      code: 'VERIFICATION_FAILED'
    });
  }
}

/**
 * Verify Stripe webhook signature
 */
function verifyStripeSignature(req) {
  const signature = req.headers['stripe-signature'];
  const payload = req.body;

  if (!STRIPE_WEBHOOK_SECRET) {
    // In development, skip verification if no secret configured
    logger.warn('STRIPE_WEBHOOK_SECRET not set, skipping verification');
    return process.env.NODE_ENV === 'development';
  }

  // Stripe uses a specific format for signatures
  // Format: t=timestamp,v1=signature
  const elements = signature.split(',');
  const signatureHash = elements.find(el => el.startsWith('v1='))?.split('v1=')[1];
  const timestamp = elements.find(el => el.startsWith('t='))?.split('t=')[1];

  if (!signatureHash || !timestamp) {
    return false;
  }

  // Check timestamp (5 minute tolerance)
  const now = Math.floor(Date.now() / 1000);
  if (Math.abs(now - parseInt(timestamp)) > 300) {
    return false;
  }

  // Compute expected signature
  const signedPayload = `${timestamp}.${JSON.stringify(payload)}`;
  const expectedSignature = crypto
    .createHmac('sha256', STRIPE_WEBHOOK_SECRET)
    .update(signedPayload)
    .digest('hex');

  return crypto.timingSafeEqual(
    Buffer.from(signatureHash, 'hex'),
    Buffer.from(expectedSignature, 'hex')
  );
}

/**
 * Verify NDIS webhook signature
 */
function verifyNDISSignature(req) {
  const signature = req.headers['x-webhook-signature'];
  const timestamp = req.headers['x-webhook-timestamp'];
  const payload = req.body;

  if (!NDIS_WEBHOOK_SECRET) {
    logger.warn('NDIS_WEBHOOK_SECRET not set, skipping verification');
    return process.env.NODE_ENV === 'development';
  }

  // Check timestamp
  const now = Math.floor(Date.now() / 1000);
  if (Math.abs(now - parseInt(timestamp)) > 300) {
    return false;
  }

  // Compute HMAC
  const signedPayload = `${timestamp}.${JSON.stringify(payload)}`;
  const expectedSignature = crypto
    .createHmac('sha256', NDIS_WEBHOOK_SECRET)
    .update(signedPayload)
    .digest('base64');

  return signature === expectedSignature;
}

/**
 * Verify generic webhook signature
 */
function verifyGenericSignature(req) {
  const signature = req.headers['x-webhook-signature'];
  const secret = process.env.GENERIC_WEBHOOK_SECRET || '';

  if (!secret) {
    return process.env.NODE_ENV === 'development';
  }

  const payload = JSON.stringify(req.body);
  const expectedSignature = crypto
    .createHmac('sha256', secret)
    .update(payload)
    .digest('hex');

  return signature === expectedSignature;
}

/**
 * Generate webhook signature (for testing)
 */
export function generateWebhookSignature(payload, secret, timestamp) {
  const signedPayload = `${timestamp}.${JSON.stringify(payload)}`;
  return crypto
    .createHmac('sha256', secret)
    .update(signedPayload)
    .digest('base64');
}
