require('dotenv').config();
const express = require('express'), cors = require('cors'), bcrypt = require('bcryptjs'), jwt = require('jsonwebtoken');
const svc = require('./src/service'), { configured } = require('./src/gemini');
const app = express(); app.use(cors()); app.use(express.json());
const SECRET = process.env.JWT_SECRET || 'change-me-in-production', PORT = process.env.PORT || 4000;

// In-memory users (swap for PostgreSQL). Demo: forecaster@rain.ai / rain1234
const users = [{ id: 1, name: 'Demo Forecaster', email: 'forecaster@rain.ai', role: 'Meteorologist', organization: 'Regional Met Centre', passwordHash: bcrypt.hashSync('rain1234', 10) }];
const pub = u => ({ id: u.id, name: u.name, email: u.email, role: u.role, organization: u.organization });
const sign = u => jwt.sign({ id: u.id }, SECRET, { expiresIn: '7d' });
function auth(req, res, next) { const t = (req.headers.authorization || '').replace('Bearer ', '');
  try { req.user = users.find(u => u.id === jwt.verify(t, SECRET).id); if (!req.user) throw 0; next(); } catch { res.status(401).json({ error: 'Unauthorized' }); } }
const wrap = fn => (req, res) => fn(req, res).catch(e => { console.error(e); res.status(500).json({ error: e.message || 'Server error' }); });

app.get('/api/health', (_, res) => res.json({ ok: true, gemini: configured(), model: process.env.GEMINI_MODEL || 'gemini-2.5-flash' }));

app.post('/api/auth/register', (req, res) => { const { name, email, password, role, organization } = req.body;
  if (!name || !email || !password || password.length < 6) return res.status(400).json({ error: 'Name, email and 6+ char password required' });
  if (users.some(u => u.email === email.toLowerCase())) return res.status(409).json({ error: 'Email already registered' });
  const u = { id: users.length + 1, name, email: email.toLowerCase(), role: role || 'Weather Analyst', organization: organization || '', passwordHash: bcrypt.hashSync(password, 10) };
  users.push(u); res.json({ token: sign(u), user: pub(u) }); });
app.post('/api/auth/login', (req, res) => { const { email = '', password = '' } = req.body; const u = users.find(x => x.email === email.toLowerCase());
  if (!u || !bcrypt.compareSync(password, u.passwordHash)) return res.status(401).json({ error: 'Invalid email or password' }); res.json({ token: sign(u), user: pub(u) }); });
app.get('/api/auth/me', auth, (req, res) => res.json({ user: pub(req.user) }));
app.put('/api/auth/me', auth, (req, res) => { ['name', 'role', 'organization'].forEach(k => { if (req.body[k] !== undefined) req.user[k] = req.body[k]; }); res.json({ user: pub(req.user) }); });
app.post('/api/auth/logout', auth, (req, res) => res.json({ ok: true }));

app.get('/api/forecast/summary', auth, wrap(async (_, res) => res.json(await svc.summary())));
app.get('/api/forecast/districts', auth, wrap(async (_, res) => { const f = await svc.forecast();
  res.json({ threshold: svc.THRESHOLDS.heavy, veryHeavyThreshold: svc.THRESHOLDS.veryHeavy, validPeriod: '24h ending 08:30 IST', source: f.source, districts: f.districts }); }));
app.get('/api/forecast/explain/:district', auth, wrap(async (req, res) => { const r = await svc.explainDistrict(req.params.district);
  r ? res.json(r) : res.status(404).json({ error: 'District not found' }); }));
app.post('/api/forecast/refresh', auth, (_, res) => { svc.clear(); res.json({ ok: true }); });
app.get('/api/verification', auth, wrap(async (_, res) => res.json(await svc.verification())));

app.listen(PORT, () => { console.log(`RainRegime API on :${PORT} | Gemini ${configured() ? 'ON' : 'OFF (rule-based fallback)'}`);
  svc.forecast().catch(() => {}); svc.verification().catch(() => {}); }); // warm cache
