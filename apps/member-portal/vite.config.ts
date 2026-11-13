import { defineConfig } from 'vite';

// Dependencies and the lockfile live at repository root. This app has its own
// HTML entry, dev server, build output and deployment; it never imports admin UI.
export default defineConfig({
  root: new URL('.', import.meta.url).pathname,
  envDir: new URL('../../', import.meta.url).pathname,
  server: { port: 5174, strictPort: true },
  build: { outDir: 'dist', emptyOutDir: true },
});
