<?php $pageTitle = 'Регистрация — Wink'; $showPromo = false; ?>
<div class="auth-page">
	<div class="auth-card">
		<h1 class="auth-card__title">Создайте аккаунт</h1>
		<p class="auth-card__subtitle">Регистрация по email для доступа к каталогу и подпискам</p>
		<?php if (!empty($error)): ?><div class="alert alert-error"><?= e($error) ?></div><?php endif; ?>
		<form method="post" action="<?= e(url('/auth/register')) ?>" class="auth-form">
			<input type="hidden" name="csrf_token" value="<?= e(Security::csrfToken()) ?>">
			<div class="form-group">
				<label for="name">Имя</label>
				<input type="text" name="name" id="name" required>
			</div>
			<div class="form-group">
				<label for="email">Email</label>
				<input type="email" name="email" id="email" required>
			</div>
			<div class="form-group">
				<label for="password">Пароль</label>
				<input type="password" name="password" id="password" required minlength="6">
			</div>
			<button type="submit" class="btn btn--primary btn--block">Создать аккаунт</button>
		</form>
		<div class="auth-card__footer">
			<span>Уже есть аккаунт?</span>
			<a href="<?= e(url('/auth/login')) ?>">Войти</a>
		</div>
	</div>
</div>
