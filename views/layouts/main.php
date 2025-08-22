<?php
use Core\Security;
?>
<!DOCTYPE html>
<html lang="ru">
<head>
	<meta charset="UTF-8">
	<meta name="viewport" content="width=device-width, initial-scale=1.0">
	<title>Wink Clone</title>
	<link rel="stylesheet" href="/assets/css/style.css">
	<link href="https://vjs.zencdn.net/8.16.1/video-js.css" rel="stylesheet">
</head>
<body class="theme-dark">
	<?php require __DIR__ . '/../partials/header.php'; ?>
	<main>
		<?= $content ?>
	</main>
	<?php require __DIR__ . '/../partials/footer.php'; ?>
	<script src="https://vjs.zencdn.net/8.16.1/video.min.js"></script>
	<script>window.CSRF_TOKEN = "<?= Security::e(Security::csrfToken()) ?>";</script>
	<script src="/assets/js/app.js"></script>
</body>
</html>