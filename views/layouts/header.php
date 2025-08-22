<?php
use Core\CSRF;
?>
<!doctype html>
<html lang="ru">
<head>
	<meta charset="utf-8">
	<meta name="viewport" content="width=device-width, initial-scale=1">
	<title>Wink Clone</title>
	<link rel="preconnect" href="https://fonts.googleapis.com">
	<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
	<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&display=swap" rel="stylesheet">
	<link rel="stylesheet" href="/assets/css/app.css">
	<link href="https://vjs.zencdn.net/8.16.1/video-js.css" rel="stylesheet" />
	<script defer src="/assets/js/app.js"></script>
</head>
<body>
<header class="site-header">
	<div class="container header-inner">
		<a href="/" class="logo">wink</a>
		<nav class="nav">
			<a href="/movies">Фильмы</a>
			<a href="/series">Сериалы</a>
			<a href="/channels">ТВ-каналы</a>
			<a href="/kids">Детям</a>
		</nav>
		<form class="search" action="/search" method="get">
			<input type="text" name="q" placeholder="Поиск" aria-label="Поиск">
		</form>
		<div class="auth-actions">
			<a href="/login" class="btn btn-secondary">Войти</a>
			<a href="/subscribe" class="btn btn-primary">Подписка</a>
		</div>
	</div>
</header>
<main class="site-main container">