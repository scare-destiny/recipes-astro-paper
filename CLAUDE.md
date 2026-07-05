# venger-2026 — venger.me (Astro blog + site)

Personal site and blog. AstroPaper-based, MDX posts in `src/data/blog/`, deployed via Docker/Coolify.

## Commands

- `pnpm dev` — local dev server
- `pnpm build` — `astro check && astro build` (run before committing content changes)

## Positioning (site-wide)

- Site is **engineer-first hybrid**: AI Engineer identity + technical case studies up front, consulting/services below. Full context: `~/Developer/ai-job-search/CLAUDE.md`.
- Target reader for career-adjacent posts: **FDE / AI Engineer hiring managers**. Posts should read as *evidence* of how Zhenya works — never as self-promo or a pitch.
- **Guardrails (never violate):**
  - The manufacturing client is anonymous everywhere — refer only to "a B2B manufacturing group".
  - Canonical proof point: **$4M → $9M ARR** (2021–present). Never use other figures (older drafts said "€2M→$8M" — wrong).
  - Never include education years. Mention **Claude Code** by name when referencing agentic coding.

## Blog Writing

### Voice
- English. Direct, short sentences, personal. No corporate speak, no motivational clichés, no filler.
- Mix personal experience with insight; vulnerability is the brand (a personal "weakness became strength" beat lands well).
- Hooks first: open with a concrete moment or a claim, not a windup.

### Frontmatter conventions
```yaml
pubDatetime: 2026-07-05T12:00:00.000+02:00   # ISO with timezone
title: Sentence case title
featured: false        # true only for flagship posts
draft: true            # keep true until reviewed
tags: [ai, career]     # lowercase, existing tags preferred
description: One-two sentences, benefits-forward, includes search terms the target reader uses
slug: 'kebab-case'     # optional; set explicitly for posts we link before publishing
```

### Workflow for a new post
1. Raw thoughts land in the `.mdx` file first; outline as `{/* */}` section stubs with key points + source links before drafting.
2. Every factual claim maps to a saved source (Readwise link) or verified proof points — no invented stats.
3. Pull stories/tone from Obsidian vault (`~/Developer/obsidian/Vault Index.md`) and Readwise.
4. `pnpm build` must pass before committing.
5. After publishing: consider Threads (Ukrainian, personal angle) and LinkedIn (English, professional) derivatives; check Todoist content-ideas project (`6XC9R8HVcr2v7JG8`).

### SEO habits (established in repo history)
- Focus positioning per post: one primary search intent, description tuned to it.
- Brand-SERP schema + breadcrumbs + related posts are set up site-wide — new posts inherit them; just get tags and description right.
- Internal links to related posts where natural.
- After publish: submit URL for indexing via Google Search Console MCP tools.
