<?php /** @var array $users */ ?>
<h2>Пользователи</h2>
<table class="table">
  <thead><tr><th>ID</th><th>Имя</th><th>Email</th><th>Роль</th><th>Подписка</th><th></th></tr></thead>
  <tbody>
    <?php foreach ($users as $u): ?>
      <tr>
        <td><?= e((string)$u['id']) ?></td>
        <td><?= e($u['name']) ?></td>
        <td><?= e($u['email']) ?></td>
        <td><?= e($u['role']) ?></td>
        <td><?= e($u['subscription_status']) ?></td>
        <td>
          <a class="btn btn-outline" href="<?= e(url('/admin/user/edit/' . $u['id'])) ?>">Редактировать</a>
          <form class="inline" method="post" action="<?= e(url('/admin/user/delete/' . $u['id'])) ?>" onsubmit="return confirm('Удалить?')">
            <input type="hidden" name="csrf_token" value="<?= e(Security::csrfToken()) ?>">
            <button class="btn btn-outline">Удалить</button>
          </form>
        </td>
      </tr>
    <?php endforeach; ?>
  </tbody>
</table>