// @ts-check
import react from '@astrojs/react';
import sitemap from '@astrojs/sitemap';
import starlight from '@astrojs/starlight';
import tailwindcss from '@tailwindcss/vite';
import { defineConfig } from 'astro/config';
import mermaid from 'astro-mermaid';
import starlightThemeNext from 'starlight-theme-next';

export default defineConfig({
  site: 'https://github.com/atilioa/bg3-mcm',
  integrations: [
    sitemap({
      changefreq: 'weekly',
      priority: 0.7,
      lastmod: new Date(),
      entryLimit: 45_000,
    }),
    starlight({
      plugins: [starlightThemeNext()],
      title: 'BG3 Mod Configuration Menu',
      description:
        "Baldur's Gate 3 Mod Configuration Menu (MCM) documentation for mod authors integrating settings, keybindings, lists, and store APIs.",
      head: [
        { tag: 'meta', attrs: { property: 'og:type', content: 'website' } },
        { tag: 'meta', attrs: { property: 'og:title', content: 'BG3 Mod Configuration Menu (MCM)' } },
        {
          tag: 'meta',
          attrs: {
            property: 'og:description',
            content: "Baldur's Gate 3 Mod Configuration Menu documentation for settings and keybinding integration.",
          },
        },
        { tag: 'meta', attrs: { property: 'og:url', content: 'https://github.com/atilioa/bg3-mcm' } },
        { tag: 'meta', attrs: { property: 'og:site_name', content: 'BG3 Mod Configuration Menu' } },
        { tag: 'meta', attrs: { name: 'twitter:card', content: 'summary_large_image' } },
        { tag: 'meta', attrs: { name: 'twitter:title', content: 'BG3 Mod Configuration Menu (MCM)' } },
        {
          tag: 'meta',
          attrs: {
            name: 'twitter:description',
            content: "Baldur's Gate 3 Mod Configuration Menu documentation for settings and keybinding integration.",
          },
        },
        {
          tag: 'meta',
          attrs: {
            name: 'keywords',
            content:
              "Baldur's Gate 3, BG3, MCM, Mod Configuration Menu, BG3SE, Lua, mod settings, keybindings, list_v2, keybinding_v2",
          },
        },
        { tag: 'meta', attrs: { name: 'author', content: 'Volitio' } },
        {
          tag: 'meta',
          attrs: { name: 'robots', content: 'index, follow, max-image-preview:large, max-snippet:-1, max-video-preview:-1' },
        },
        { tag: 'link', attrs: { rel: 'canonical', href: 'https://github.com/atilioa/bg3-mcm' } },
        { tag: 'link', attrs: { rel: 'manifest', href: '/manifest.json' } },
        { tag: 'meta', attrs: { name: 'theme-color', content: '#3b82f6' } },
        { tag: 'meta', attrs: { name: 'msapplication-TileColor', content: '#3b82f6' } },
      ],
      social: [
        { icon: 'discord', label: 'Discord', href: 'https://discord.gg/DcS8c7KUa6' },
        { icon: 'github', label: 'GitHub', href: 'https://github.com/atilioa/bg3-mcm' },
      ],
      locales: {
        root: { label: 'English', lang: 'en' },
      },
      logo: {
        light: './src/assets/brand-logo-gray.svg',
        dark: './src/assets/brand-logo-gray.svg',
        replacesTitle: true,
      },
      customCss: ['./src/styles/global.css'],
      sidebar: [
        { label: 'Getting started', autogenerate: { directory: 'getting-started' } },
        { label: 'API', autogenerate: { directory: 'api' } },
      ],
      favicon: '/favicon.ico',
      components: {
        Hero: './src/components/starlight/hero.astro',
        ThemeSelect: './src/components/starlight/null.astro',
        ThemeProvider: './src/components/starlight/theme-provider.astro',
        LanguageSelect: './src/components/starlight/null.astro',
        Footer: './src/components/starlight/footer.astro',
      },
    }),
    react(),
    mermaid(),
  ],
  vite: {
    plugins: [tailwindcss()],
    resolve: {
      alias: {
        '@': new URL('src', import.meta.url).pathname,
      },
    },
  },
});
