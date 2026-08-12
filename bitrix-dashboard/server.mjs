import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const root = dirname(fileURLToPath(import.meta.url));
loadEnv(join(root, '.env'));

const port = Number(process.env.PORT || 3000);
const webhookUrl = normalizeWebhookUrl(process.env.BITRIX_WEBHOOK_URL);
const cache = new Map();
const CACHE_TTL_MS = 60_000;

const contentTypes = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
};

createServer(async (request, response) => {
  try {
    if (!isAuthorized(request, response)) return;

    const url = new URL(request.url, `http://${request.headers.host}`);
    if (url.pathname === '/api/metrics') {
      if (request.method !== 'GET') return sendJson(response, 405, { error: 'Метод не поддерживается.' });
      if (!webhookUrl) return sendJson(response, 503, { error: 'Укажите BITRIX_WEBHOOK_URL в файле .env.' });

      const days = clampInteger(url.searchParams.get('days'), 1, 365, 30);
      return sendJson(response, 200, await getMetrics(days));
    }

    if (url.pathname === '/api/health') {
      return sendJson(response, 200, { ok: true, configured: Boolean(webhookUrl) });
    }

    const fileName = url.pathname === '/' ? 'index.html' : url.pathname.slice(1);
    if (!['index.html', 'app.js', 'styles.css'].includes(fileName)) return sendJson(response, 404, { error: 'Не найдено.' });
    const extension = fileName.slice(fileName.lastIndexOf('.'));
    response.writeHead(200, { 'Content-Type': contentTypes[extension], 'Cache-Control': 'no-store' });
    response.end(await readFile(join(root, 'public', fileName)));
  } catch (error) {
    console.error(error);
    sendJson(response, 500, { error: 'Не удалось получить данные Битрикс24.', details: error.message });
  }
}).listen(port, () => console.log(`Bitrix24 dashboard: http://localhost:${port}`));

async function getMetrics(days) {
  const key = `metrics:${days}`;
  const cached = cache.get(key);
  if (cached && Date.now() - cached.createdAt < CACHE_TTL_MS) return cached.value;

  const user = await callBitrix('user.current');
  const userId = String(user.ID);
  const since = new Date();
  since.setDate(since.getDate() - days);

  const [tasks, sessionsResult] = await Promise.all([
    listAll('tasks.task.list', { filter: { RESPONSIBLE_ID: userId }, select: ['ID', 'TITLE', 'STATUS', 'CREATED_DATE', 'CLOSED_DATE', 'DEADLINE'] }),
    getOpenLineSessions(userId),
  ]);

  const value = {
    generatedAt: new Date().toISOString(),
    period: { days, since: since.toISOString() },
    user: { id: userId, name: [user.NAME, user.LAST_NAME].filter(Boolean).join(' ') || user.LOGIN },
    tasks: summarizeTasks(tasks, since),
    openLines: summarizeSessions(sessionsResult.sessions, since, sessionsResult.available, sessionsResult.warning),
  };
  cache.set(key, { createdAt: Date.now(), value });
  return value;
}

async function getOpenLineSessions(userId) {
  try {
    const sessions = await listAll('imopenlines.session.list', { FILTER: { OPERATOR_ID: userId } });
    return { sessions, available: true, warning: null };
  } catch (error) {
    // Open Lines access is controlled separately from task access in Bitrix24.
    return { sessions: [], available: false, warning: error.message };
  }
}

function summarizeTasks(tasks, since) {
  const taskStatus = { '1': 'Новые', '2': 'Ждут выполнения', '3': 'В работе', '4': 'Ждут контроля', '5': 'Завершены', '6': 'Отложены' };
  const byStatus = Object.fromEntries(Object.entries(taskStatus).map(([id, name]) => [id, { name, count: 0 }]));
  const completed = tasks.filter((task) => task.STATUS === '5' && isOnOrAfter(task.CLOSED_DATE, since));
  const active = tasks.filter((task) => ['1', '2', '3', '4'].includes(task.STATUS));
  const overdue = active.filter((task) => task.DEADLINE && new Date(task.DEADLINE) < new Date());

  for (const task of tasks) {
    if (byStatus[task.STATUS]) byStatus[task.STATUS].count++;
  }

  return {
    total: tasks.length,
    closedInPeriod: completed.length,
    active: active.length,
    overdue: overdue.length,
    byStatus: Object.values(byStatus),
    recentClosed: completed
      .sort((a, b) => new Date(b.CLOSED_DATE) - new Date(a.CLOSED_DATE))
      .slice(0, 10)
      .map((task) => ({ id: task.ID, title: task.TITLE, closedAt: task.CLOSED_DATE })),
  };
}

function summarizeSessions(sessions, since, available, warning) {
  const inPeriod = sessions.filter((session) => isOnOrAfter(session.DATE_CREATE || session.DATE_CLOSE, since));
  const closed = inPeriod.filter((session) => isClosedSession(session));
  const resolutionMinutes = closed
    .map((session) => elapsedMinutes(session.DATE_CREATE, session.DATE_CLOSE))
    .filter(Number.isFinite);

  return {
    available,
    warning,
    totalInPeriod: inPeriod.length,
    active: inPeriod.filter((session) => !isClosedSession(session)).length,
    processed: closed.length,
    averageResolutionMinutes: average(resolutionMinutes),
  };
}

function isClosedSession(session) {
  return Boolean(session.DATE_CLOSE) || ['Y', '1', 'CLOSED', 'CLOSE'].includes(String(session.CLOSED || session.STATUS || '').toUpperCase());
}

function elapsedMinutes(start, end) {
  const value = new Date(end) - new Date(start);
  return value >= 0 ? Math.round(value / 60_000) : Number.NaN;
}

function average(values) {
  return values.length ? Math.round(values.reduce((sum, value) => sum + value, 0) / values.length) : null;
}

function isOnOrAfter(date, since) {
  return date && new Date(date) >= since;
}

async function listAll(method, params) {
  const items = [];
  let start = 0;
  do {
    const page = await callBitrix(method, { ...params, start });
    const result = Array.isArray(page) ? page : page.tasks || page.items || [];
    items.push(...result);
    start = typeof page.next === 'number' ? page.next : null;
  } while (start !== null);
  return items;
}

async function callBitrix(method, params = {}) {
  const response = await fetch(`${webhookUrl}${method}.json`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(params),
  });
  if (!response.ok) throw new Error(`Битрикс24 вернул HTTP ${response.status}.`);
  const payload = await response.json();
  if (payload.error) throw new Error(payload.error_description || payload.error);
  return payload.result;
}

function normalizeWebhookUrl(value) {
  if (!value) return null;
  try {
    const url = new URL(value);
    if (!['https:', 'http:'].includes(url.protocol)) return null;
    return url.href.endsWith('/') ? url.href : `${url.href}/`;
  } catch {
    return null;
  }
}

function clampInteger(value, min, max, fallback) {
  const number = Number.parseInt(value, 10);
  return Number.isInteger(number) ? Math.min(Math.max(number, min), max) : fallback;
}

function loadEnv(path) {
  try {
    const lines = requireEnvFile(path).split(/\r?\n/);
    for (const line of lines) {
      const match = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
      if (match && !(match[1] in process.env)) process.env[match[1]] = match[2].replace(/^["']|["']$/g, '');
    }
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
  }
}

function requireEnvFile(path) {
  // Synchronous loading is intentional: configuration must exist before requests are served.
  return process.getBuiltinModule('node:fs').readFileSync(path, 'utf8');
}

function isAuthorized(request, response) {
  const username = process.env.DASHBOARD_USERNAME;
  const password = process.env.DASHBOARD_PASSWORD;
  if (!username && !password) return true;

  const supplied = request.headers.authorization?.startsWith('Basic ')
    ? Buffer.from(request.headers.authorization.slice(6), 'base64').toString()
    : '';
  if (supplied === `${username}:${password}`) return true;
  response.writeHead(401, { 'WWW-Authenticate': 'Basic realm="Bitrix24 dashboard"' });
  response.end('Требуется авторизация.');
  return false;
}

function sendJson(response, status, body) {
  response.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
  response.end(JSON.stringify(body));
}
