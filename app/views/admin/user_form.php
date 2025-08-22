<?php /** @var array $user */ ?>
<h2>Редактировать пользователя</h2>
<form method="post" action="" class="form">
  <input type="hidden" name="csrf_token" value="<?= e(Security::csrfToken()) ?>">
  <label>Имя
    <input type="text" name="name" required value="<?= e($user['name'] ?? '') ?>">
  </label>
  <label>Email
    <input type="email" name="email" required value="<?= e($user['email'] ?? '') ?>">
  </label>
  <label>Роль
    <select name="role">
      <option value="user" <?= ($user['role'] ?? '')==='user'?'selected':'' ?>>user</option>
      <option value="admin" <?= ($user['role'] ?? '')==='admin'?'selected':'' ?>>admin</option>
    </select>
  </label>
  <label>Подписка
    <select name="subscription_status">
      <option value="none" <?= ($user['subscription_status'] ?? '')==='none'?'selected':'' ?>>none</option>
      <option value="active" <?= ($user['subscription_status'] ?? '')==='active'?'selected':'' ?>>active</option>
      <option value="expired" <?= ($user['subscription_status'] ?? '')==='expired'?'selected':'' ?>>expired</option>
    </select>
  </label>
  <button class="btn">Сохранить</button>
</form>