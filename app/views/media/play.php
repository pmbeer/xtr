<?php /** @var array $media */ ?>
<article class="player-page">
  <h1><?= e($media['title']) ?></h1>
  <video id="video" class="video-js vjs-big-play-centered" controls preload="auto" width="100%" height="480" data-setup='{"playbackRates":[0.75,1,1.25,1.5]}'></video>
  <script>
  document.addEventListener('DOMContentLoaded', function(){
    var player = videojs('video');
    var sources = <?php echo json_encode(array_map(function($s){return ['src'=>$s['url'],'type'=>$s['mime'], 'label'=>$s['quality'].'p'];}, $media['sources']), JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES); ?>;
    // choose highest quality by default
    player.src(sources);
  });
  </script>
</article>