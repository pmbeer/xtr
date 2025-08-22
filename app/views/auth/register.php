<h1 class="page-title">Регистрация</h1>
<?php if (!empty($error)): ?><div class="alert alert-error"><?= e($error) ?></div><?php endif; ?>
<form method="post" action="<?= e(url('/auth/register')) ?>" class="form auth-form">
  <input type="hidden" name="csrf_token" value="<?= e(Security::csrfToken()) ?>">
  <label>Имя
    <input type="text" name="name" required>
  </label>
  <label>Email
    <input type="email" name="email" required>
  </label>
  <label>Пароль
    <input type="password" name="password" required>
  </label>
  <button class="btn">Создать аккаунт</button>
</form>