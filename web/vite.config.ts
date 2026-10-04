import adapter from "@sveltejs/adapter-node";
import { vitePreprocess } from "@sveltejs/vite-plugin-svelte";
import tailwindcss from "@tailwindcss/vite";
import { sveltekit } from "@sveltejs/kit/vite";
import { SvelteKitPWA } from "@vite-pwa/sveltekit";
import { defineConfig } from "vite";

export default defineConfig({
  plugins: [
    tailwindcss(),
    sveltekit({
      preprocess: vitePreprocess(),
      adapter: adapter(),
      paths: {
        origin: process.env.ORIGIN ?? "http://localhost:5173",
      },
      csp: {
        mode: "auto",
        directives: { "default-src": ["self"], "frame-ancestors": ["none"] },
      },
    }),

    SvelteKitPWA({
      registerType: "autoUpdate",
      includeAssets: ["pwa/favicon.ico", "pwa/apple-touch-icon-180x180.png"],
      manifest: {
        name: "Vapen Dashboard",
        short_name: "Vapen",
        description: "Dashboard for Elfbar Master usage and groups",
        theme_color: "#4466aa",
        background_color: "#fcfcfc",
        display: "standalone",
        orientation: "portrait-primary",
        start_url: "/",
        scope: "/",
        icons: [
          { src: "/pwa/pwa-64x64.png", sizes: "64x64", type: "image/png" },
          {
            src: "/pwa/pwa-192x192.png",
            sizes: "192x192",
            type: "image/png",
          },
          {
            src: "/pwa/pwa-512x512.png",
            sizes: "512x512",
            type: "image/png",
          },
          {
            src: "/pwa/maskable-icon-512x512.png",
            sizes: "512x512",
            type: "image/png",
            purpose: "maskable",
          },
        ],
      },
      workbox: {
        globPatterns: ["client/**/*.{js,css,ico,png,svg,webp,woff,woff2}"],
        navigateFallback: null,
        cleanupOutdatedCaches: true,
        runtimeCaching: [
          {
            urlPattern: ({ request }) => request.mode === "navigate",
            handler: "NetworkOnly",
          },
        ],
      },
      devOptions: {
        enabled: true,
        type: "module",
      },
    }),
  ],
});
