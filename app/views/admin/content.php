<?php /** @var array $items */ ?>
<h2>Контент</h2>
<p><a class="btn" href="<?= e(url('/admin/content/create')) ?>">Добавить</a></p>
<table class="table">
  <thead><tr><th>ID</th><th>Название</th><th>Тип</th><th>Год</th><th></th></tr></thead>
  <tbody>
    <?php foreach ($items as $it): ?>
      <tr>
        <td><?= e((string)$it['id']) ?></td>
        <td><?= e($it['title']) ?></td>
        <td><?= e($it['type']) ?></td>
        <td><?= e((string)$it['year']) ?></td>
        <td>
          <a class="btn btn-outline" href="<?= e(url('/admin/content/edit/' . $it['id'])) ?>">Редактировать</a>
          <form class="inline" method="post" action="<?= e(url('/admin/content/delete/' . $it['id'])) ?>" onsubmit="return confirm('Удалить?')">
            <input type="hidden" name="csrf_token" value="<?= e(Security::csrfToken()) ?>">
            <button class="btn btn-outline">Удалить</button>
          </form>
        </td>
      </tr>
    <?php endforeach; ?>
  </tbody>
</table>