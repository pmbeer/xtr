<h1 class="page-title">Восстановление пароля</h1>
<?php if (!empty($message)): ?><div class="alert alert-info"><?= e($message) ?></div><?php endif; ?>
<form method="post" action="<?= e(url('/auth/reset')) ?>" class="form auth-form">
  <input type="hidden" name="csrf_token" value="<?= e(Security::csrfToken()) ?>">
  <label>Email
    <input type="email" name="email" required>
  </label>
  <button class="btn">Отправить ссылку</button>
</form>