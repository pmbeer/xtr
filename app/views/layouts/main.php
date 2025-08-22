<?php
$user = auth_user();
?>
<!doctype html>
<html lang="ru">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Wink</title>
<link rel="stylesheet" href="<?= e(asset('assets/css/app.css')) ?>">
<link href="https://vjs.zencdn.net/8.12.0/video-js.css" rel="stylesheet">
<script defer src="https://vjs.zencdn.net/8.12.0/video.min.js"></script>
<script defer src="<?= e(asset('assets/js/app.js')) ?>"></script>
</head>
<body class="theme-dark">
<header class="site-header">
  <div class="container header-inner">
    <a href="<?= e(url('/')) ?>" class="logo">Wink</a>
    <nav class="main-nav">
      <a href="<?= e(url('/movies')) ?>">Фильмы</a>
      <a href="<?= e(url('/series')) ?>">Сериалы</a>
      <a href="<?= e(url('/tv')) ?>">ТВ-каналы</a>
      <a href="<?= e(url('/kids')) ?>">Детям</a>
      <?php if ($user && ($user['role'] ?? 'user') === 'admin'): ?>
        <a href="<?= e(url('/admin')) ?>">Админ</a>
      <?php endif; ?>
    </nav>
    <div class="header-actions">
      <form action="<?= e(url('/search')) ?>" method="get" class="search-form">
        <input type="text" name="q" placeholder="Поиск" value="<?= e($_GET['q'] ?? '') ?>">
      </form>
      <?php if ($user): ?>
        <a href="<?= e(url('/account')) ?>" class="btn">Мой Wink</a>
        <form action="<?= e(url('/auth/logout')) ?>" method="post" class="inline">
          <input type="hidden" name="csrf_token" value="<?= e(Security::csrfToken()) ?>">
          <button class="btn btn-outline">Выйти</button>
        </form>
      <?php else: ?>
        <a href="<?= e(url('/auth/login')) ?>" class="btn">Войти</a>
      <?php endif; ?>
    </div>
  </div>
</header>
<main class="content">
  <div class="container">
    <?= $content ?>
  </div>
</main>
<footer class="site-footer">
  <div class="container footer-inner">
    <div>© <?= date('Y') ?> Wink</div>
    <div class="footer-links">
      <a href="#">О проекте</a>
      <a href="#">Помощь</a>
      <a href="#">Правила</a>
    </div>
  </div>
</footer>
</body>
</html>