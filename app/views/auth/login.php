<h1 class="page-title">Вход</h1>
<?php if (!empty($error)): ?><div class="alert alert-error"><?= e($error) ?></div><?php endif; ?>
<form method="post" action="<?= e(url('/auth/login')) ?>" class="form auth-form">
  <input type="hidden" name="csrf_token" value="<?= e(Security::csrfToken()) ?>">
  <label>Email
    <input type="email" name="email" required>
  </label>
  <label>Пароль
    <input type="password" name="password" required>
  </label>
  <button class="btn">Войти</button>
  <div class="form-footer">
    <a href="<?= e(url('/auth/register')) ?>">Регистрация</a>
    <a href="<?= e(url('/auth/reset')) ?>">Забыли пароль?</a>
  </div>
</form>