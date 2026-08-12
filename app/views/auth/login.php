<?php $pageTitle = 'Вход — Wink'; $showPromo = false; $mode = $mode ?? ($_GET['mode'] ?? 'phone'); ?>
<div class="auth-page">
	<div class="auth-card">
		<h1 class="auth-card__title">Войдите или создайте аккаунт</h1>
		<p class="auth-card__subtitle"><?= $mode === 'email' ? 'Вход по email и паролю' : 'Введите номер телефона, чтобы пользоваться Wink на любом устройстве' ?></p>
		<?php if (!empty($error)): ?><div class="alert alert-error"><?= e($error) ?></div><?php endif; ?>

		<?php if ($mode === 'phone'): ?>
		<form method="post" class="auth-form" id="phoneAuthForm">
			<input type="hidden" name="csrf_token" value="<?= e(Security::csrfToken()) ?>">
			<div class="form-group">
				<label for="phone">Телефон</label>
				<div class="phone-input">
					<span class="phone-input__prefix">+7</span>
					<input type="tel" name="phone" id="phone" placeholder="(999) 123-45-67" required>
				</div>
			</div>
			<button type="submit" class="btn btn--primary btn--block">Продолжить</button>
		</form>
		<p class="auth-card__legal">Демо: номер <strong>9001234567</strong> (админ)</p>
		<div class="auth-card__footer">
			<span>или</span>
			<a href="<?= e(url('/auth/login?mode=email')) ?>">Войти по email</a>
		</div>
		<?php else: ?>
		<form method="post" class="auth-form">
			<input type="hidden" name="csrf_token" value="<?= e(Security::csrfToken()) ?>">
			<input type="hidden" name="mode" value="email">
			<div class="form-group">
				<label for="email">Email</label>
				<input type="email" name="email" id="email" required>
			</div>
			<div class="form-group">
				<label for="password">Пароль</label>
				<input type="password" name="password" id="password" required>
			</div>
			<button type="submit" class="btn btn--primary btn--block">Войти</button>
		</form>
		<div class="auth-card__footer">
			<a href="<?= e(url('/auth/login')) ?>">Войти по телефону</a>
			<span>·</span>
			<a href="<?= e(url('/auth/register')) ?>">Регистрация</a>
		</div>
		<?php endif; ?>
	</div>
</div>
