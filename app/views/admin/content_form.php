<?php /** @var array|null $item */ ?>
<h2><?= $item ? 'Редактировать контент' : 'Создать контент' ?></h2>
<form method="post" action="" class="form">
  <input type="hidden" name="csrf_token" value="<?= e(Security::csrfToken()) ?>">
  <label>Тип
    <select name="type">
      <option value="movie" <?= isset($item['type']) && $item['type']==='movie'?'selected':'' ?>>Фильм</option>
      <option value="series" <?= isset($item['type']) && $item['type']==='series'?'selected':'' ?>>Сериал</option>
    </select>
  </label>
  <label>Название
    <input type="text" name="title" required value="<?= e($item['title'] ?? '') ?>">
  </label>
  <label>Описание
    <input type="text" name="description" value="<?= e($item['description'] ?? '') ?>">
  </label>
  <label>Год
    <input type="number" name="year" value="<?= e((string)($item['year'] ?? '')) ?>">
  </label>
  <label>Страна
    <input type="text" name="country" value="<?= e($item['country'] ?? '') ?>">
  </label>
  <label>Жанр ID
    <input type="number" name="genre_id" value="<?= e((string)($item['genre_id'] ?? '')) ?>">
  </label>
  <label>Постер URL
    <input type="text" name="poster_url" value="<?= e($item['poster_url'] ?? '') ?>">
  </label>
  <label><input type="checkbox" name="is_featured" <?= !empty($item['is_featured'])?'checked':'' ?>> Избранное</label>
  <label><input type="checkbox" name="is_kids" <?= !empty($item['is_kids'])?'checked':'' ?>> Детям</label>
  <label><input type="checkbox" name="is_paid" <?= !empty($item['is_paid'])?'checked':'' ?>> По подписке</label>
  <button class="btn">Сохранить</button>
</form>