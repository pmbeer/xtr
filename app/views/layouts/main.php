<!DOCTYPE html>
<html lang="ru">
<head>
	<meta charset="utf-8">
	<meta name="viewport" content="width=device-width, initial-scale=1">
	<title><?= e($pageTitle ?? 'Wink — онлайн-кинотеатр') ?></title>
	<link rel="preconnect" href="https://fonts.googleapis.com">
	<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
	<link href="https://fonts.googleapis.com/css2?family=Manrope:wght@400;500;600;700;800&display=swap" rel="stylesheet">
	<link rel="stylesheet" href="<?= e(asset('assets/css/wink.css')) ?>">
	<link href="https://vjs.zencdn.net/8.12.0/video-js.css" rel="stylesheet">
	<script defer src="https://vjs.zencdn.net/8.12.0/video.min.js"></script>
</head>
<body class="wink">
	<div class="layout">
		<?php if (($showPromo ?? true) && (parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) === '/' || str_ends_with(parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '', '/public/') || str_ends_with(parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '', '/public/index.php'))): ?>
			<?php include BASE_PATH . '/app/views/partials/promo.php'; ?>
		<?php endif; ?>
		<?php include BASE_PATH . '/app/views/partials/header.php'; ?>
		<main class="main"><?= $content ?></main>
		<?php include BASE_PATH . '/app/views/partials/footer.php'; ?>
	</div>
	<button class="scroll-top" id="scrollTop" type="button" aria-label="Наверх">
		<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m18 15-6-6-6 6"/></svg>
	</button>
	<script src="<?= e(asset('assets/js/wink.js')) ?>"></script>
</body>
</html>
