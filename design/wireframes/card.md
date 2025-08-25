## Content Card — Wireframe (Film/Series)

### Desktop

Layout
```
[Poster 2:3]  [Title]
              [Year • Rating • Duration]
              [Genres]
              [Synopsis 3–4 lines]
              [CTA: Watch] [Trailer] [Add]

For Series:
[Seasons ▼]  [Episodes list with progress]

[Similar / With this watch]
```

States
- No trailer; paywall; age-restricted; geo-locked; error

Interactions
- Play primary; Trailer modal; Add to list toast
- Season dropdown; episode quick start; hover previews

### Mobile

Layout
```
[Poster]
[Title]
[Meta row]
[Primary CTA]
[Synopsis]
[Seasons/Episodes (accordion)]
[Similar (h-scroll)]
```

Bottom sheet option for quick details from Home

### Smart TV

Layout
```
[Large backdrop]
[Left: Poster]
[Right: Title, Meta, CTAs]
[Row: Episodes (focusable)]
[Row: Similar]
```

TV Interactions
- D‑pad focus between CTAs, episodes, similar
- Next-up episode preselected if available

