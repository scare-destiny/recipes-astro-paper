export const SITE = {
  website: "https://www.venger.me/",
  author: "Eugene Venger",
  profile: "https://www.venger.me/",
  desc: "AI Engineer building AI-powered systems, automation, and the data infrastructure behind them for B2B SaaS — with notes on what I learn along the way.",
  title: "Eugene Venger — AI Engineer",
  ogImage: "venger-og.png",
  lightAndDarkMode: true,
  postPerIndex: 4,
  postPerPage: 4,
  scheduledPostMargin: 15 * 60 * 1000, // 15 minutes
  showArchives: false,
  showBackButton: true, // show back button in post detail
  editPost: {
    enabled: false,
    text: "Edit page",
    url: "https://github.com/satnaing/astro-paper/edit/main/",
  },
  dynamicOgImage: true,
  dir: "ltr", // "rtl" | "auto"
  lang: "en", // html lang code. Set this empty and default will be "en"
  timezone: "Europe/Berlin", // Default global timezone (IANA format) https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
} as const;
