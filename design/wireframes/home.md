## Home — Wireframe

### Desktop (1440–1920)

Layout
```
[Header: Logo | Sections | Search | Notifications | Profile]

[Hero banner 16:9]
  Title • Logline • [Watch] [More]

[Row: Continue Watching]  ▣ ▣ ▣ ▣ ▣  →

[Row: Recommended]        ▣ ▣ ▣ ▣ ▣  →

[Row: Trending Now]       ▣ ▣ ▣ ▣ ▣  →

[Row: New Releases]       ▣ ▣ ▣ ▣ ▣  →

[Editorial Collections]   ▣ ▣ ▣ ▣ ▣  →

[Footer]
```

States
- Loading: hero skeleton, row skeleton cards (2:3), lazy load rows
- Empty recs: friendly copy + refresh CTA
- Error: retry control per row, offline hint
- Access: paywall gates on premium rows

Interactions
- Hover card: scale + quick actions [Play] [More] [Add]
- Row nav: arrow buttons; infinite scroll appends rows
- Search icon expands input with suggestions

Grid
- Container 1200–1320, 12 cols, 24px gutters, 8px baseline

### Mobile (360–414)

Layout
```
[Header: Logo | Search | Profile]
[Hero]
[Continue Watching]  ▣ ▣ ▣ (h-scroll)
[Recommended]        ▣ ▣ ▣ (h-scroll)
[Trending]           ▣ ▣ ▣ (h-scroll)
[New Releases]       ▣ ▣ ▣ (h-scroll)
[Collections]        ▣ ▣ ▣ (h-scroll)
```

Interactions
- Tap card: open card bottom sheet; long-press: quick actions
- Pull to refresh; lazy rows load on visibility

Grid
- 4 cols, 16px gutters, 8px base spacing

### Smart TV (1080/2160)

Layout
```
[Header (reduced)]
[Hero focusable]
[Rows with D‑pad focus]
```

TV Interactions
- D‑pad: left/right within row, up/down between rows
- Visible focus outline; hold-right triggers row fast-scroll
- Info panel on long-press OK

Safe area
- 5–7% inset; ensure focus outline stays within safe zone

