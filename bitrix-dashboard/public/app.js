const $ = (selector) => document.querySelector(selector);
const number = new Intl.NumberFormat('ru-RU');

$('#period').addEventListener('change', loadMetrics);
loadMetrics();

async function loadMetrics() {
  document.body.classList.add('loading');
  $('#error').hidden = true;
  try {
    const response = await fetch(`/api/metrics?days=${$('#period').value}`);
    const data = await response.json();
    if (!response.ok) throw new Error(data.error || 'Неизвестная ошибка.');
    render(data);
  } catch (error) {
    $('#error').textContent = `Дашборд не получил данные: ${error.message}`;
    $('#error').hidden = false;
  } finally {
    document.body.classList.remove('loading');
  }
}

function render(data) {
  $('#subtitle').textContent = `${data.user.name} · обновлено ${formatDate(data.generatedAt)}`;
  $('#closed').textContent = number.format(data.tasks.closedInPeriod);
  $('#active').textContent = number.format(data.tasks.active);
  $('#overdue').textContent = number.format(data.tasks.overdue);
  $('#total').textContent = number.format(data.tasks.total);
  $('#processed').textContent = data.openLines.available ? number.format(data.openLines.processed) : '—';
  $('#line-active').textContent = data.openLines.available ? number.format(data.openLines.active) : '—';
  $('#resolution').textContent = data.openLines.available ? formatMinutes(data.openLines.averageResolutionMinutes) : '—';

  $('#statuses').replaceChildren(...data.tasks.byStatus.map((status) => {
    const item = document.createElement('div');
    item.innerHTML = `<span>${escapeHtml(status.name)}</span><b>${number.format(status.count)}</b>`;
    return item;
  }));

  const note = $('#lines-note');
  note.hidden = data.openLines.available;
  note.textContent = data.openLines.warning
    ? `Нет доступа к Открытым линиям: ${data.openLines.warning}. Проверьте право «Открытые линии» у вебхука.`
    : '';

  $('#recent').replaceChildren(...data.tasks.recentClosed.map((task) => {
    const item = document.createElement('li');
    item.innerHTML = `<span>${escapeHtml(task.title || `Задача #${task.id}`)}</span><time>${formatDate(task.closedAt)}</time>`;
    return item;
  }));
  if (!data.tasks.recentClosed.length) $('#recent').innerHTML = '<li><span>За период нет завершённых задач.</span></li>';
}

function formatMinutes(value) {
  if (value === null) return 'Нет данных';
  if (value < 60) return `${value} мин`;
  const hours = Math.floor(value / 60);
  const minutes = value % 60;
  return minutes ? `${hours} ч ${minutes} мин` : `${hours} ч`;
}

function formatDate(value) {
  return new Intl.DateTimeFormat('ru-RU', { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(value));
}

function escapeHtml(value) {
  const node = document.createElement('span');
  node.textContent = value;
  return node.innerHTML;
}
