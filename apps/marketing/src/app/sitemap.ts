import type { MetadataRoute } from "next";

export const dynamic = "force-static";

export default function sitemap(): MetadataRoute.Sitemap {
  return [
    {
      url: "https://leaguehub.ca",
      lastModified: new Date("2026-08-11"),
      changeFrequency: "monthly",
      priority: 1,
    },
    {
      url: "https://leaguehub.ca/support",
      lastModified: new Date("2026-08-11"),
      changeFrequency: "monthly",
      priority: 0.7,
    },
    {
      url: "https://leaguehub.ca/privacy",
      lastModified: new Date("2026-08-11"),
      changeFrequency: "yearly",
      priority: 0.5,
    },
    {
      url: "https://leaguehub.ca/terms",
      lastModified: new Date("2026-08-11"),
      changeFrequency: "yearly",
      priority: 0.5,
    },
  ];
}
