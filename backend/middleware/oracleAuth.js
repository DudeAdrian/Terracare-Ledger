/**
 * TerraCare Ledger v2.0 - Oracle Authentication Middleware
 * 
 * Validates AI Oracle / Backend service signatures
 */

import { ethers } from 'ethers';
import logger from '../logger.js';

// Oracle public keys (configured from environment)
const ORACLE_PUBLIC_KEYS = (process.env.ORACLE_PUBLIC_KEYS || '').split(',').filter(Boolean);
const AI_SIGNER_ADDRESS = process.env.AI_SIGNER_ADDRESS || '';

/**
 * Middleware to validate oracle requests
 * Oracles sign requests with their private key, we verify with public key
 */
export function requireOracle(req, res, next) {
  const signature = req.headers['x-oracle-signature'];
  const timestamp = req.headers['x-oracle-timestamp'];
  const oracleAddress = req.headers['x-oracle-address'];

  if (!signature || !timestamp || !oracleAddress) {
    return res.status(401).json({
      error: 'Oracle authentication required',
      code: 'ORACLE_AUTH_REQUIRED'
    });
  }

  // Check if oracle is authorized
  if (!ORACLE_PUBLIC_KEYS.includes(oracleAddress) && oracleAddress !== AI_SIGNER_ADDRESS) {
    logger.warn({ oracleAddress }, 'Unauthorized oracle attempt');
    return res.status(403).json({
      error: 'Unauthorized oracle',
      code: 'UNAUTHORIZED_ORACLE'
    });
  }

  // Verify timestamp (prevent replay attacks)
  const requestTime = parseInt(timestamp);
  const now = Math.floor(Date.now() / 1000);
  
  if (Math.abs(now - requestTime) > 300) { // 5 minute window
    return res.status(401).json({
      error: 'Request timestamp too old',
      code: 'STALE_REQUEST'
    });
  }

  // Verify signature
  try {
    const message = `${req.method}:${req.originalUrl}:${timestamp}:${JSON.stringify(req.body)}`;
    const recoveredAddress = ethers.verifyMessage(message, signature);

    if (recoveredAddress.toLowerCase() !== oracleAddress.toLowerCase()) {
      return res.status(401).json({
        error: 'Invalid oracle signature',
        code: 'INVALID_SIGNATURE'
      });
    }

    req.oracle = { address: oracleAddress };
    next();
  } catch (error) {
    logger.error({ error: error.message }, 'Oracle signature verification failed');
    return res.status(401).json({
      error: 'Signature verification failed',
      code: 'SIGNATURE_FAILED'
    });
  }
}

/**
 * Validate device signature from wearable/IoT device
 */
export async function validateDeviceSignature(deviceId, userId, data, signature) {
  try {
    // Create message hash
    const message = ethers.keccak256(
      ethers.solidityPacked(
        ['string', 'bytes32', 'bytes'],
        [deviceId, ethers.encodeBytes32String(userId), ethers.toUtf8Bytes(JSON.stringify(data))]
      )
    );

    // Recover signer
    const recoveredAddress = ethers.verifyMessage(ethers.getBytes(message), signature);

    // In production: Check if recoveredAddress is a registered device for this user
    // For now, accept any valid signature
    return recoveredAddress !== ethers.ZeroAddress;
  } catch (error) {
    logger.error({ error: error.message, deviceId }, 'Device signature validation failed');
    return false;
  }
}

/**
 * Generate oracle signature (for backend use)
 */
export async function generateOracleSignature(privateKey, method, url, body, timestamp) {
  const wallet = new ethers.Wallet(privateKey);
  const message = `${method}:${url}:${timestamp}:${JSON.stringify(body)}`;
  return wallet.signMessage(message);
}

/**
 * Middleware to check if request is from authorized validator
 */
export function requireValidator(req, res, next) {
  const validatorAddress = req.headers['x-validator-address'];
  const signature = req.headers['x-validator-signature'];

  if (!validatorAddress || !signature) {
    return res.status(401).json({
      error: 'Validator authentication required',
      code: 'VALIDATOR_AUTH_REQUIRED'
    });
  }

  // In production: Check against on-chain validator list
  // For now, just pass through if headers present
  req.validator = { address: validatorAddress };
  next();
}
