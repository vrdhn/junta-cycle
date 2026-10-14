import { defineConfig } from "vite";
import { svelte } from "@sveltejs/vite-plugin-svelte";

// Minimal Vite configuration for Svelte on GitHub Pages
export default defineConfig({
  plugins: [svelte()],
  base: "./",
  build: {
    outDir: "dist",
    emptyOutDir: true,
  },
});
