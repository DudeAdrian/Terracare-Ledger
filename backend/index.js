// --- Authentication: Login Endpoint ---
app.post('/api/login', [body('address').isString().isLength({ min: 42, max: 42 })], validateRequest, async (req, res) => {
  const { address } = req.body;
  // In production, verify signature or use OAuth2/SSO
  // Here, issue JWT for any valid address (demo only)
  const token = jwt.sign({ address }, process.env.JWT_SECRET || 'changeme', { expiresIn: '12h' });
  res.json({ token });
});


import jwt from 'jsonwebtoken';
import logger from './logger.js';
// --- JWT Authentication Middleware ---
function authenticateJWT(req, res, next) {
  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    const token = authHeader.split(' ')[1];
    jwt.verify(token, process.env.JWT_SECRET || 'changeme', (err, user) => {
      if (err) {
        return res.sendStatus(403);
      }
      req.user = user;
      next();
    });
  } else {
    res.sendStatus(401);
  }
}

import dotenv from 'dotenv';
dotenv.config();

const prisma = new PrismaClient();
// --- User Profile & Extension Management (Database) ---

// Get user profile
app.get('/api/user/:address', async (req, res) => {
  const { address } = req.params;
  const user = await prisma.user.findUnique({ where: { address } });
  res.json({ user });
});

// Update user settings
app.post('/api/user/:address/settings', async (req, res) => {
  const { address } = req.params;
  const { settings } = req.body;
  const user = await prisma.user.upsert({
    where: { address },
    update: { settings },
    create: { address, role: 'Unknown', settings },
  });
  res.json({ user });
});

// List extensions for user
app.get('/api/user/:address/extensions', async (req, res) => {
  const { address } = req.params;
  const user = await prisma.user.findUnique({ where: { address }, include: { extensions: true } });
  res.json({ extensions: user?.extensions || [] });
});

// Enable/disable extension
app.post('/api/user/:address/extensions/:name', async (req, res) => {
  const { address, name } = req.params;
  const { enabled } = req.body;
  const user = await prisma.user.upsert({
    where: { address },
    update: {},
    create: { address, role: 'Unknown' },
  });
  const ext = await prisma.extension.upsert({
    where: { userId_name: { userId: user.id, name } },
    update: { enabled },
    create: { userId: user.id, name, enabled },
  });
  res.json({ extension: ext });
});

// Log analytics event
app.post('/api/analytics', async (req, res) => {
  const { userId, type, data } = req.body;
  const event = await prisma.analyticsEvent.create({ data: { userId, type, data } });
  res.json({ event });
});



const app = express();

// --- Logging Middleware ---
app.use((req, res, next) => {
  logger.info({
    message: 'Request',
    method: req.method,
    url: req.url,
    body: req.body,
    ip: req.ip
  });
  next();
});

// --- Security Middleware ---
app.use(helmet()); // Secure HTTP headers
app.use(express.json()); // Parse JSON bodies
app.use(cors({
  origin: [
    'http://localhost:3000', // Sofie-Systems/Heartware local dev
    // Add production UI origins here
  ],
  credentials: true
}));
app.use(rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  standardHeaders: true,
  legacyHeaders: false,
}));

// --- Input Validation Example Middleware ---
function validateRequest(req, res, next) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ errors: errors.array() });
  }
  next();
}

// Example: List supported chains
app.get('/api/chains', (req, res) => {
  res.json({ chains: MultiChainConfig.listChains() });
});

// Example: Get chain status
app.get('/api/chain/:chainId/status', async (req, res) => {
  const { chainId } = req.params;
  try {
    const status = await MultiChainConfig.getChainStatus(chainId);
    res.json({ status });
  } catch (e) {
    res.status(400).json({ error: e.message });
  }
});


// --- Core API Endpoints (Stub Implementations) ---


// Register identity (stub, with input validation & JWT auth)
app.post(
  '/api/identity/register',
  authenticateJWT,
  [
    body('address').isString().isLength({ min: 42, max: 42 }),
    body('role').isString().notEmpty(),
  ],
  validateRequest,
   async (req, res) => {
     // Example: Call IdentityRegistry contract (stub, update ABI and address as needed)
     const { address, role, chainId = 'terracare' } = req.body;
     try {
       const abi = MultiChainConfig.abis.IdentityRegistry.abi;
       const contract = MultiChainConfig.getContract(chainId, 'IdentityRegistry', abi);
       // Example: call contract.register(address, role) (role as uint8)
       // const tx = await contract.register(address, role);
       // await tx.wait();
       res.json({ message: 'Identity registration transaction sent (stub)' });
     } catch (e) {
      logger.error({ message: 'Error in /api/identity/register', error: e.message });
      res.status(500).json({ error: e.message });
     }
  }
);



// Grant access (wired to AccessControl contract, stub)
app.post(
  '/api/access/grant',
  authenticateJWT,
  [body('caregiver').isString().isLength({ min: 42, max: 42 })],
  validateRequest,
  async (req, res) => {
    const { caregiver, chainId = 'terracare' } = req.body;
    try {
      const abi = MultiChainConfig.abis.AccessControl.abi;
      const contract = MultiChainConfig.getContract(chainId, 'AccessControl', abi);
      // Example: call contract.grant(caregiver)
      // const tx = await contract.grant(caregiver);
      // await tx.wait();
      res.json({ message: 'Access grant transaction sent (stub)' });
    } catch (e) {
      logger.error({ message: 'Error in /api/access/grant', error: e.message });
      res.status(500).json({ error: e.message });
    }
  }
);



// Revoke access (wired to AccessControl contract, stub)
app.post(
  '/api/access/revoke',
  authenticateJWT,
  [body('caregiver').isString().isLength({ min: 42, max: 42 })],
  validateRequest,
  async (req, res) => {
    const { caregiver, chainId = 'terracare' } = req.body;
    try {
      const abi = MultiChainConfig.abis.AccessControl.abi;
      const contract = MultiChainConfig.getContract(chainId, 'AccessControl', abi);
      // Example: call contract.revoke(caregiver)
      // const tx = await contract.revoke(caregiver);
      // await tx.wait();
      res.json({ message: 'Access revoke transaction sent (stub)' });
    } catch (e) {
      logger.error({ message: 'Error in /api/access/revoke', error: e.message });
      res.status(500).json({ error: e.message });
    }
  }
);



// Update record (wired to RecordRegistry contract, stub)
app.post(
  '/api/record/update',
  authenticateJWT,
  [body('dataHash').isString().isLength({ min: 66, max: 66 })],
  validateRequest,
  async (req, res) => {
    const { dataHash, chainId = 'terracare' } = req.body;
    try {
      const abi = MultiChainConfig.abis.RecordRegistry.abi;
      const contract = MultiChainConfig.getContract(chainId, 'RecordRegistry', abi);
      // Example: call contract.updateRecord(dataHash)
      // const tx = await contract.updateRecord(dataHash);
      // await tx.wait();
      res.json({ message: 'Record update transaction sent (stub)' });
    } catch (e) {
      logger.error({ message: 'Error in /api/record/update', error: e.message });
      res.status(500).json({ error: e.message });
    }
  }
);

// Get record (stub)
app.get('/api/record/:patient', (req, res) => {
  // TODO: Connect to RecordRegistry contract
  res.json({ record: null, message: 'Record fetched (stub)' });
});



// Log audit event (wired to AuditLog contract, stub)
app.post(
  '/api/audit/log',
  authenticateJWT,
  [
    body('subject').isString().isLength({ min: 42, max: 42 }),
    body('action').isString().notEmpty(),
    body('refHash').isString().isLength({ min: 66, max: 66 })
  ],
  validateRequest,
  async (req, res) => {
    const { subject, action, refHash, chainId = 'terracare' } = req.body;
    try {
      const abi = MultiChainConfig.abis.AuditLog.abi;
      const contract = MultiChainConfig.getContract(chainId, 'AuditLog', abi);
      // Example: call contract.logAccess(subject, action, refHash)
      // const tx = await contract.logAccess(subject, action, refHash);
      // await tx.wait();
      res.json({ message: 'Audit log transaction sent (stub)' });
    } catch (e) {
      logger.error({ message: 'Error in /api/audit/log', error: e.message });
      res.status(500).json({ error: e.message });
    }
  }
);

app.listen(4000, () => {
  console.log('Terracare Ledger backend running on port 4000');
});
