/**
 * TerraCare Ledger v2.0 - Authentication Middleware
 */

import jwt from 'jsonwebtoken';
import { validationResult } from 'express-validator';
import logger from '../logger.js';

const JWT_SECRET = process.env.JWT_SECRET || 'terracare-development-secret';

/**
 * JWT Authentication Middleware
 */
export function authenticateJWT(req, res, next) {
  const authHeader = req.headers.authorization;
  
  if (authHeader && authHeader.startsWith('Bearer ')) {
    const token = authHeader.split(' ')[1];
    
    jwt.verify(token, JWT_SECRET, (err, user) => {
      if (err) {
        logger.warn({ error: err.message }, 'JWT verification failed');
        return res.status(403).json({
          error: 'Invalid or expired token',
          code: 'INVALID_TOKEN'
        });
      }
      
      req.user = user;
      next();
    });
  } else {
    res.status(401).json({
      error: 'Authentication required',
      code: 'NO_TOKEN'
    });
  }
}

/**
 * Request Validation Middleware
 */
export function validateRequest(req, res, next) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      error: 'Validation failed',
      code: 'VALIDATION_ERROR',
      details: errors.array()
    });
  }
  next();
}

/**
 * Role-based Access Control Middleware
 * @param {string[]} allowedRoles - Array of allowed roles
 */
export function requireRole(allowedRoles) {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'NO_TOKEN'
      });
    }

    const userRole = req.user.role || 'Unknown';
    
    if (!allowedRoles.includes(userRole)) {
      logger.warn({
        user: req.user.address,
        role: userRole,
        required: allowedRoles
      }, 'Insufficient role');
      
      return res.status(403).json({
        error: 'Insufficient permissions',
        code: 'FORBIDDEN',
        required: allowedRoles,
        current: userRole
      });
    }

    next();
  };
}

/**
 * Token-gated access middleware (require MINE)
 */
export function requireMINE(minBalance) {
  return async (req, res, next) => {
    if (!req.user || !req.user.address) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'NO_TOKEN'
      });
    }

    try {
      // This would check MINE balance via contract service
      // For now, just pass through
      next();
    } catch (error) {
      logger.error({ error: error.message }, 'Error checking MINE balance');
      res.status(500).json({
        error: 'Failed to verify token balance',
        code: 'BALANCE_CHECK_FAILED'
      });
    }
  };
}

/**
 * Rate limiting by user (stricter than IP-based)
 */
export function userRateLimit(windowMs = 60000, maxRequests = 10) {
  const requests = new Map();

  return (req, res, next) => {
    const userId = req.user?.address || req.ip;
    const now = Date.now();

    if (!requests.has(userId)) {
      requests.set(userId, []);
    }

    const userRequests = requests.get(userId);
    
    // Clean old requests
    const validRequests = userRequests.filter(time => now - time < windowMs);
    
    if (validRequests.length >= maxRequests) {
      return res.status(429).json({
        error: 'Rate limit exceeded',
        code: 'RATE_LIMIT',
        retryAfter: Math.ceil((validRequests[0] + windowMs - now) / 1000)
      });
    }

    validRequests.push(now);
    requests.set(userId, validRequests);
    next();
  };
}

/**
 * Generate JWT token for user
 */
export function generateToken(user) {
  return jwt.sign(
    {
      address: user.address,
      role: user.role || 'Unknown',
      userId: user.userId
    },
    JWT_SECRET,
    { expiresIn: '12h' }
  );
}

/**
 * Verify JWT token (for WebSocket auth, etc.)
 */
export function verifyToken(token) {
  try {
    return jwt.verify(token, JWT_SECRET);
  } catch (error) {
    return null;
  }
}
