import { defineConfig, envField } from "astro/config";
import tailwindcss from "@tailwindcss/vite";
import sitemap from "@astrojs/sitemap";
import remarkToc from "remark-toc";
import remarkCollapse from "remark-collapse";
import rehypeMermaid from "rehype-mermaid";
import {
  transformerNotationDiff,
  transformerNotationHighlight,
  transformerNotationWordHighlight,
} from "@shikijs/transformers";
import { transformerFileName } from "./src/utils/transformers/fileName";
import { SITE } from "./src/config";

import mdx from "@astrojs/mdx";

import react from "@astrojs/react";

import vercel from "@astrojs/vercel";

// https://astro.build/config
export default defineConfig({
  site: SITE.website,

  redirects: {
    '/blog/data-engineering-primer-part-1': '/posts/data-engineering-primer-part-1',
    '/blog/analytical-tools': '/posts/posthog-vs-clarity-and-hotjar'
  },

  integrations: [sitemap({
    filter: page => SITE.showArchives || !page.endsWith("/archives"),
  }), mdx(), react()],

  markdown: {
    remarkPlugins: [remarkToc, [remarkCollapse, { test: "Table of contents" }]],
    rehypePlugins: [[rehypeMermaid, { strategy: "mermaid-js" }]],
    syntaxHighlight: {
      type: "shiki",
      excludeLangs: ["mermaid"],
    },
    shikiConfig: {
      // For more themes, visit https://shiki.style/themes
      themes: { light: "min-light", dark: "night-owl" },
      defaultColor: false,
      wrap: false,
      transformers: [
        transformerFileName({ style: "v2", hideDot: false }),
        transformerNotationHighlight() as unknown,
        transformerNotationWordHighlight() as unknown,
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        transformerNotationDiff({ matchAlgorithm: "v3" }) as any,
      ],
    },
  },

  vite: {
    // eslint-disable-next-line
    // @ts-ignore
    // This will be fixed in Astro 6 with Vite 7 support
    // See: https://github.com/withastro/astro/issues/14030
    plugins: [tailwindcss()],
    optimizeDeps: {
      exclude: ["@resvg/resvg-js"],
    },
  },

  image: {
    responsiveStyles: true,
    layout: "constrained",
  },

  env: {
    schema: {
      PUBLIC_GOOGLE_SITE_VERIFICATION: envField.string({
        access: "public",
        context: "client",
        optional: true,
      }),
    },
  },

  experimental: {
    preserveScriptOrder: true,
  },

  adapter: vercel(),
});