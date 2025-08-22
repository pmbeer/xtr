<?php /** @var array $media */ ?>
<section class="subscribe-callout">
  <h1><?= e($media['title']) ?></h1>
  <p>Этот контент доступен по подписке.</p>
  <a class="btn" href="<?= e(url('/subscribe')) ?>">Оформить подписку</a>
</section>