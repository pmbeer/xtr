## Wink Theme for DataLife Engine 16.0

Modern streaming-style template aligned with the provided UI spec. Compatible with DLE 16.0.

### Install
1) Copy the `wink` folder into your DLE installation at `templates/wink`.
2) In Admin Panel → System Settings → Templates, choose `wink` as default.
3) Clear caches (system + template) and rebuild thumbnails if needed.
4) Ensure SEO URLs and CDN/static caching settings match your environment.

### Files
- `main.tpl` — base layout wrapper. Injects `{content}` and includes header/footer.
- `header.tpl` — global header, navigation, search.
- `footer.tpl` — footer, global scripts.
- `shortstory.tpl` — list item (cards) for news/posts (used on main/category/search).
- `fullstory.tpl` — full article/content page (card details).
- `profile.tpl` — user profile area basics.
- `search.tpl` — search results page wrapper.
- `navigation.tpl` — pagination.
- `css/variables.css` — design tokens (colors, spacing, typography).
- `css/style.css` — layout and components.
- `js/app.js` — interactions (search toggle, menus, focus helpers).

### Notes
- Palette and typography follow the spec: background `#0F0F12`, primary `#6C5CE7`, accent `#00C8AA`, text white/gray, error `#FF5252`.
- Cards: 2:3 aspect, 8px radius, lazy images via `loading="lazy"`.
- Accessibility: visible focus, sufficient contrast, keyboard navigation.

