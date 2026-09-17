import express from 'express';
import cookieParser from 'cookie-parser';
import { rateLimit } from 'express-rate-limit';
import { timingSafeEqual } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { dailyStats, hashToken, login, saveAttempt, secretToken } from './database.js';
import { verifyGoogle } from './auth.js';

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const today = () => new Intl.DateTimeFormat('sv-SE', { timeZone: 'Europe/Prague' }).format(new Date());
const equal = (a, b) => typeof a === 'string' && typeof b === 'string' &&
  Buffer.byteLength(a) === Buffer.byteLength(b) && timingSafeEqual(Buffer.from(a), Buffer.from(b));
const html = value => value.replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

export function createApp({ pool, origin, clientId = '', webRoot, verifyIdentity = verifyGoogle }) {
  const app = express();
  const secure = origin.startsWith('https://');
  const sessionCookie = secure ? '__Host-aaaskola_session' : 'aaaskola_session';
  const nonceCookie = secure ? '__Host-aaaskola_nonce' : 'aaaskola_nonce';
  const cookies = { httpOnly: true, secure, sameSite: 'lax', path: '/' };
  app.disable('x-powered-by');
  app.set('trust proxy', 1);
  app.use((req, res, next) => {
    res.set({ 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff', 'Referrer-Policy': 'strict-origin-when-cross-origin' });
    next();
  });
  app.use(express.json({ limit: '16kb' }), cookieParser());
  app.get('/healthz', async (req, res) => {
    await pool.query('SELECT 1');
    res.type('text').send('ok\n');
  });
  app.use('/api', rateLimit({ windowMs: 60_000, limit: 240, standardHeaders: 'draft-8', legacyHeaders: false }));
  app.get('/login', (req, res) => {
    if (!clientId) return res.status(503).type('html').send('<h1>Přihlášení zatím není připravené.</h1><a href="/">Zpět do školy</a>');
    const nonce = secretToken();
    res.cookie(nonceCookie, nonce, { ...cookies, maxAge: 10 * 60_000 });
    res.set({ 'Content-Security-Policy': "default-src 'self'; script-src 'self' https://accounts.google.com/gsi/client; frame-src https://accounts.google.com; connect-src 'self' https://accounts.google.com/gsi/; style-src 'self' https://accounts.google.com/gsi/style; img-src 'self' data: https://*.googleusercontent.com; base-uri 'none'; frame-ancestors 'none'", 'Cross-Origin-Opener-Policy': 'same-origin-allow-popups' });
    res.type('html').send(`<!doctype html><html lang="cs"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Přihlášení · AAA škola</title><link rel="stylesheet" href="/auth/login.css"><script src="https://accounts.google.com/gsi/client" defer></script><script src="/auth/login.js" defer></script></head><body><main><img src="/favicon.png" width="64" height="64" alt=""><h1>Vítej v AAA škole</h1><p>Přihlas se a uvidíš své výsledky každý den.</p><div id="google-signin" data-client-id="${html(clientId)}" data-nonce="${nonce}"></div><p id="status" role="status"></p><p>Uložíme jméno, e-mail a výsledky procvičování. Přehled uvidíš jen po přihlášení ke svému účtu.</p><a href="/">Zpět do školy</a></main></body></html>`);
  });
  app.use('/auth', express.static(fileURLToPath(new URL('./public', import.meta.url)), { dotfiles: 'deny' }));
  app.post('/api/auth/google', rateLimit({ windowMs: 60_000, limit: 15, legacyHeaders: false }), async (req, res) => {
    if (!clientId) return res.status(503).json({ error: 'Google login is not configured' });
    const { credential, nonce } = req.body ?? {};
    if (req.get('origin') !== origin || !/^[a-f0-9]{64}$/.test(nonce ?? '') || !equal(req.cookies[nonceCookie], nonce)) {
      return res.status(403).json({ error: 'Invalid login request' });
    }
    if (typeof credential !== 'string' || credential.length > 12000) return res.status(400).json({ error: 'Invalid credential' });
    let identity;
    try { identity = await verifyIdentity(credential, clientId, nonce); }
    catch { return res.status(401).json({ error: 'Google identity could not be verified' }); }
    const result = await login(pool, identity, req.cookies[sessionCookie]);
    res.cookie(sessionCookie, result.token, { ...cookies, maxAge: 30 * 86400_000 });
    res.clearCookie(nonceCookie, cookies);
    res.json({ user: result.user });
  });
  app.use('/api', async (req, res, next) => {
    const token = req.cookies[sessionCookie];
    if (typeof token === 'string' && /^[a-f0-9]{64}$/.test(token)) {
      const { rows: [session] } = await pool.query(`SELECT s.csrf, u.id, u.name, u.email
        FROM sessions s JOIN users u ON u.id = s.user_id
        WHERE token_hash = $1 AND expires_at > now()`, [hashToken(token)]);
      req.session = session;
    }
    next();
  });
  app.get('/api/me', (req, res) => {
    const session = req.session;
    res.json({ user: session ? { id: session.id, name: session.name, email: session.email } : null,
      csrf: session?.csrf ?? null, loginAvailable: Boolean(clientId),
      today: today() });
  });
  app.use('/api', (req, res, next) => {
    if (!req.session) return res.status(401).json({ error: 'Sign in required' });
    if (req.method !== 'GET' && (req.get('origin') !== origin || !equal(req.get('x-csrf-token'), req.session.csrf))) {
      return res.status(403).json({ error: 'Invalid request' });
    }
    next();
  });
  app.post('/api/logout', async (req, res) => {
    await pool.query('DELETE FROM sessions WHERE token_hash = $1', [hashToken(req.cookies[sessionCookie])]);
    res.clearCookie(sessionCookie, cookies).sendStatus(204);
  });
  app.post('/api/attempts', async (req, res) => {
    const body = req.body ?? {};
    if (!uuid.test(body.id) || !uuid.test(body.exerciseId) ||
        !(body.subject === 'math' ? [3, 5] : body.subject === 'english' ? [5, 7] : []).includes(body.grade) ||
        typeof body.correct !== 'boolean' || typeof body.completed !== 'boolean' || (body.completed && !body.correct) ||
        typeof body.occurredAt !== 'string' || !/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3,6}Z$/.test(body.occurredAt) ||
        !Number.isFinite(Date.parse(body.occurredAt)) || Date.parse(body.occurredAt) > Date.now() + 300_000) {
      return res.status(400).json({ error: 'Invalid attempt' });
    }
    const result = await saveAttempt(pool, req.session.id, body);
    res.status(result === 'conflict' ? 409 : result === 'created' ? 201 : 200).json({ result });
  });
  app.get('/api/stats', async (req, res) => {
    const { from, to } = req.query;
    const validDate = value => typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value) &&
      Number.isFinite(Date.parse(value)) && new Date(value).toISOString().slice(0, 10) === value;
    const span = Date.parse(to) - Date.parse(from);
    if (!validDate(from) || !validDate(to) || span < 0 || span > 366 * 86400_000) {
      return res.status(400).json({ error: 'Invalid date range' });
    }
    res.json({ timezone: 'Europe/Prague', today: today(), days: await dailyStats(pool, req.session.id, from, to) });
  });
  app.use('/api', (req, res) => res.sendStatus(404));
  if (webRoot) app.use(express.static(webRoot, { dotfiles: 'ignore', etag: true, maxAge: 0 }));
  app.use((req, res) => res.sendStatus(404));
  app.use((error, req, res, next) => {
    if (error.type === 'entity.parse.failed' || error.type === 'entity.too.large') return res.status(400).json({ error: 'Invalid request body' });
    console.error('Request failed', error.code ?? error.name);
    res.status(503).json({ error: 'Service temporarily unavailable' });
  });
  return app;
}
