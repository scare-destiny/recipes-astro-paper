// Notifies Google of new/changed blog posts via the Indexing API.
// Usage: node scripts/notify-search-console.mjs <file1> <file2> ...
// Files are paths (relative to repo root) under src/data/blog/ that changed in the push.
//
// Note: Google's `google.com/ping?sitemap=` endpoint was deprecated in 2023
// (now returns 404), so the Indexing API is the only notification path left.

import { readFileSync } from "node:fs";
import { GoogleAuth } from "google-auth-library";
import matter from "gray-matter";
import kebabcase from "lodash.kebabcase";

const BLOG_PATH = "src/data/blog";
const SITE_URL = "https://www.venger.me";

const slugifyStr = str => kebabcase(str);

function getPath(id, filePath, includeBase = true) {
  const pathSegments = filePath
    ?.replace(BLOG_PATH, "")
    .split("/")
    .filter(p => p !== "")
    .filter(p => !p.startsWith("_"))
    .slice(0, -1)
    .map(segment => slugifyStr(segment));

  const basePath = includeBase ? "/posts" : "";

  const blogId = id.split("/");
  const slug = blogId.length > 0 ? blogId.slice(-1) : blogId;

  if (!pathSegments || pathSegments.length < 1) {
    return [basePath, slug].join("/");
  }

  return [basePath, ...pathSegments, slug].join("/");
}

function fileToUrl(filePath) {
  const relPath = filePath.replace(/^\.?\/?/, "");
  const id = relPath
    .replace(`${BLOG_PATH}/`, "")
    .replace(/\.(md|mdx)$/, "");
  const path = getPath(id, relPath);
  return `${SITE_URL}${path}/`.replace(/\/+$/, "/");
}

async function notifyIndexingApi(urls) {
  const keyJson = process.env.GOOGLE_INDEXING_SA_KEY;
  if (!keyJson) {
    console.error("GOOGLE_INDEXING_SA_KEY is not set, skipping Indexing API calls.");
    return;
  }

  const auth = new GoogleAuth({
    credentials: JSON.parse(keyJson),
    scopes: ["https://www.googleapis.com/auth/indexing"],
  });
  const client = await auth.getClient();

  for (const url of urls) {
    try {
      const res = await client.request({
        url: "https://indexing.googleapis.com/v3/urlNotifications:publish",
        method: "POST",
        data: { url, type: "URL_UPDATED" },
      });
      console.log(`[indexing-api] ${url} -> ${res.status}`);
    } catch (err) {
      console.error(`[indexing-api] ${url} failed:`, err.message);
    }
  }
}

async function main() {
  const files = process.argv.slice(2).filter(f => /\.(md|mdx)$/.test(f));

  if (files.length === 0) {
    console.log("No changed blog post files to process.");
    return;
  }

  const urls = [];
  for (const file of files) {
    let raw;
    try {
      raw = readFileSync(file, "utf-8");
    } catch (err) {
      console.error(`Could not read ${file}, skipping:`, err.message);
      continue;
    }

    const { data: frontmatter } = matter(raw);
    if (frontmatter.draft) {
      console.log(`[skip] ${file} is a draft`);
      continue;
    }

    urls.push(fileToUrl(file));
  }

  if (urls.length > 0) {
    console.log("Requesting indexing for:", urls);
    await notifyIndexingApi(urls);
  } else {
    console.log("No published posts among changed files.");
  }
}

main();
