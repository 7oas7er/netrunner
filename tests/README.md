# Netrunner tests

Unit tests (Node) and Playwright e2e for the static catalog under `netrunner/`.

```bash
cd tests
npm ci
npx playwright install --with-deps chromium   # first time
npm test
```

- `unit/` — generators, catalog helpers, card counts
- `e2e/` — smoke against `static-server.mjs` on port 4173
- `static-server.mjs` — zero-dep local static server (`npm run serve`)
