import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

class SafeError extends Error {}
const monthFormatter = new Intl.DateTimeFormat('ru-RU', { month: 'long', year: 'numeric', timeZone: 'UTC' });
const formatDate = (date) => date.toISOString().slice(0, 10);

loadDotEnv(resolve(import.meta.dirname, '../../../../.env'));

try {
  const period = parsePeriod(process.argv.slice(2));
  const webhookUrl = normalizeWebhookUrl(process.env.BITRIX_WEBHOOK_URL);
  if (!webhookUrl) throw new SafeError('Не настроен вебхук Битрикс24. Создайте .env из .env.example и укажите BITRIX_WEBHOOK_URL.');

  const api = createBitrixClient(webhookUrl);
  const user = await api.call('user.current');
  const userId = String(user.ID);
  const [tasks, openLines] = await Promise.all([
    api.listAll('tasks.task.list', {
      filter: { RESPONSIBLE_ID: userId },
      select: ['ID', 'TITLE', 'STATUS', 'CREATED_DATE', 'CLOSED_DATE', 'DEADLINE'],
    }),
    getOpenLines(api, userId),
  ]);

  process.stdout.write(buildReport(user, period, tasks, openLines));
} catch (error) {
  process.stderr.write(`Ошибка отчёта: ${safeMessage(error)}\n`);
  process.exitCode = 1;
}

function parsePeriod(args) {
  const options = Object.fromEntries(args.filter((_, index) => index % 2 === 0 && args[index].startsWith('--')).map((key, index) => [key.slice(2), args[index * 2 + 1]]));
  const now = new Date();

  if (options.from || options.to) {
    if (!options.from || !options.to) throw new SafeError('Для точного периода укажите одновременно --from YYYY-MM-DD и --to YYYY-MM-DD.');
    return dateRange(options.from, options.to);
  }

  switch (options.period) {
    case 'last-month': {
      const from = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - 1, 1));
      const to = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 0));
      return { from, to, label: monthFormatter.format(from) };
    }
    case 'this-month': {
      const from = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1));
      return { from, to: utcDay(now), label: monthFormatter.format(from) };
    }
    case 'last-N-days': {
      const days = Number.parseInt(options.days, 10);
      if (!Number.isInteger(days) || days < 1 || days > 365) throw new SafeError('Для last-N-days укажите --days от 1 до 365.');
      const to = utcDay(now);
      const from = new Date(to);
      from.setUTCDate(from.getUTCDate() - days + 1);
      return { from, to, label: `последние ${days} дн.` };
    }
    default:
      throw new SafeError('Укажите период: --period last-month, this-month или last-N-days --days N; либо --from YYYY-MM-DD --to YYYY-MM-DD.');
  }
}

function dateRange(fromValue, toValue) {
  const from = parseDate(fromValue);
  const to = parseDate(toValue);
  if (to < from) throw new SafeError('Дата окончания не может быть раньше даты начала.');
  return { from, to, label: `${formatDate(from)} — ${formatDate(to)}` };
}

function parseDate(value) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) throw new SafeError('Дата должна иметь формат YYYY-MM-DD.');
  const date = new Date(`${value}T00:00:00.000Z`);
  if (Number.isNaN(date.valueOf()) || date.toISOString().slice(0, 10) !== value) throw new SafeError('Указана недопустимая дата.');
  return date;
}

async function getOpenLines(api, userId) {
  try {
    return { available: true, sessions: await api.listAll('imopenlines.session.list', { FILTER: { OPERATOR_ID: userId } }) };
  } catch (error) {
    return { available: false, sessions: [], warning: safeMessage(error) };
  }
}

function buildReport(user, period, tasks, openLines) {
  const closed = tasks.filter((task) => task.STATUS === '5' && isWithin(task.CLOSED_DATE, period));
  const active = tasks.filter((task) => ['1', '2', '3', '4'].includes(String(task.STATUS)));
  const overdue = active.filter((task) => task.DEADLINE && new Date(task.DEADLINE) < new Date());
  const statuses = [
    ['1', 'Новые'], ['2', 'Ждут выполнения'], ['3', 'В работе'],
    ['4', 'Ждут контроля'], ['5', 'Завершены'], ['6', 'Отложены'],
  ].map(([id, name]) => `${name}: ${tasks.filter((task) => String(task.STATUS) === id).length}`);

  const lines = [`Отчёт Битрикс24: ${[user.NAME, user.LAST_NAME].filter(Boolean).join(' ') || user.LOGIN}`, `Период: ${period.label}`, '', 'Задачи', `• Завершено за период: ${closed.length}`, `• Активных сейчас: ${active.length}`, `• Просрочено сейчас: ${overdue.length}`, `• Всего, где вы ответственный: ${tasks.length}`, `• Статусы: ${statuses.join('; ')}`];

  if (!openLines.available) {
    lines.push('', 'Открытые линии', `• Метрики недоступны: ${openLines.warning}. Проверьте право вебхука «Открытые линии».`);
  } else {
    const sessions = openLines.sessions.filter((session) => isWithin(session.DATE_CREATE || session.DATE_CLOSE, period));
    const closedSessions = sessions.filter(isClosedSession);
    const times = closedSessions.map((session) => minutesBetween(session.DATE_CREATE, session.DATE_CLOSE)).filter(Number.isFinite);
    lines.push('', 'Открытые линии', `• Обработано: ${closedSessions.length}`, `• Активно: ${sessions.length - closedSessions.length}`, `• Среднее время решения: ${times.length ? formatMinutes(Math.round(times.reduce((sum, value) => sum + value, 0) / times.length)) : 'нет данных'}`);
  }

  return `${lines.join('\n')}\n`;
}

function createBitrixClient(webhookUrl) {
  return {
    async call(method, params = {}) {
      const response = await fetch(`${webhookUrl}${method}.json`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8' },
        body: encodeParams(params).toString(),
      });
      if (!response.ok) throw new SafeError(`Битрикс24 вернул HTTP ${response.status}.`);
      const payload = await response.json();
      if (payload.error) throw new SafeError(payload.error_description || payload.error);
      return payload.result;
    },
    async listAll(method, params) {
      const items = [];
      let start = 0;
      do {
        const result = await this.call(method, { ...params, start });
        items.push(...extractItems(result));
        start = typeof result?.next === 'number' ? result.next : null;
      } while (start !== null);
      return items;
    },
  };
}

function extractItems(result) {
  if (Array.isArray(result)) return result;
  for (const key of ['tasks', 'items', 'sessions']) {
    if (Array.isArray(result?.[key])) return result[key];
  }
  return [];
}

function encodeParams(input, prefix = '', output = new URLSearchParams()) {
  for (const [key, value] of Object.entries(input)) {
    const name = prefix ? `${prefix}[${key}]` : key;
    if (Array.isArray(value)) value.forEach((item) => output.append(`${name}[]`, item));
    else if (value && typeof value === 'object') encodeParams(value, name, output);
    else if (value !== undefined && value !== null) output.append(name, String(value));
  }
  return output;
}

function isWithin(value, { from, to }) {
  if (!value) return false;
  const date = new Date(value);
  return !Number.isNaN(date.valueOf()) && date >= from && date < nextDay(to);
}

function isClosedSession(session) {
  return Boolean(session.DATE_CLOSE) || ['Y', '1', 'CLOSED', 'CLOSE'].includes(String(session.CLOSED || session.STATUS || '').toUpperCase());
}

function minutesBetween(from, to) {
  const result = new Date(to) - new Date(from);
  return result >= 0 ? Math.round(result / 60_000) : Number.NaN;
}

function formatMinutes(value) {
  const hours = Math.floor(value / 60);
  return hours ? `${hours} ч${value % 60 ? ` ${value % 60} мин` : ''}` : `${value} мин`;
}

function nextDay(date) {
  const value = new Date(date);
  value.setUTCDate(value.getUTCDate() + 1);
  return value;
}

function utcDay(date) {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
}

function normalizeWebhookUrl(value) {
  if (!value) return null;
  try {
    const url = new URL(value);
    return url.protocol === 'https:' ? (url.href.endsWith('/') ? url.href : `${url.href}/`) : null;
  } catch {
    return null;
  }
}

function loadDotEnv(path) {
  try {
    for (const line of readFileSync(path, 'utf8').split(/\r?\n/)) {
      const match = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
      if (match && !(match[1] in process.env)) process.env[match[1]] = match[2].replace(/^["']|["']$/g, '');
    }
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
  }
}

function safeMessage(error) {
  return error instanceof SafeError ? error.message : 'Не удалось получить данные Битрикс24.';
}
