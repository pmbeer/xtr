## Player — Wireframe (VOD/Series)

### Core Controls
```
[Play/Pause] [Time • Scrubber with thumbnails] [Volume]
[Subtitles/Audio] [Quality] [Speed] [Miniplayer] [Fullscreen]
```

States
- Idle controls hidden; on move/OK show overlay
- Buffering; network error retry; no subtitles/audio tracks
- Next-up countdown (5–10s); autoplay toggle

Series Specific
- Next episode CTA; season/episode quick switch

Keyboard/Remote
- Space/OK: play-pause; arrows: seek; up/down: controls
- Long-press right: fast-seek; back: exit/minimize

### Desktop Layout
```
[Video]
[Bottom overlay: timeline + controls]
[Top: title, episode, back]
```

### Mobile Layout
```
[Video]
[Tap shows bottom sheet controls]
[Orientation: landscape controls condensed]
```

### Smart TV Layout
```
[Video]
[Bottom overlay large targets]
[Right panel (optional): episode list]
```

Accessibility
- Focus order predictable; captions styling; contrast sufficient

