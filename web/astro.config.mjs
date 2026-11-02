import react from "@astrojs/react";
import sitemap from "@astrojs/sitemap";
import { defineConfig } from "astro/config";

// GitHub Pages serves the site at https://apurv-1.github.io/trackedge/.
// With a custom domain, set `site` to that domain and remove `base`.
export default defineConfig({
  site: "https://apurv-1.github.io",
  base: "/trackedge",
  // GitHub Pages serves folders with a trailing slash, so every URL uses one.
  trailingSlash: "always",
  integrations: [react(), sitemap()],
  build: { inlineStylesheets: "auto" },
});
