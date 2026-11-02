import react from "@astrojs/react";
import sitemap from "@astrojs/sitemap";
import { defineConfig } from "astro/config";

// The public address of the site. Canonical links, Open Graph tags, and the sitemap use it.
const site = process.env.SITE_URL ?? process.env.URL ?? "https://trackedge.netlify.app";

export default defineConfig({
  site,
  integrations: [react(), sitemap()],
  build: { inlineStylesheets: "auto" },
});
