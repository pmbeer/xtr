<?php /** @var array $stats */ ?>
<h1>Админ-панель</h1>
<ul class="stats">
  <li>Пользователи: <?= e((string)$stats['users']) ?></li>
  <li>Контент: <?= e((string)$stats['content']) ?></li>
  <li>Просмотры: <?= e((string)$stats['views']) ?></li>
</ul>
<nav class="admin-nav">
  <a class="btn" href="<?= e(url('/admin/content')) ?>">Контент</a>
  <a class="btn" href="<?= e(url('/admin/users')) ?>">Пользователи</a>
</nav>