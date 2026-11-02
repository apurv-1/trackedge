import { repo } from "./site";

export type Release = {
  version: string;
  sizeBytes: number | null;
};

export type RepoStats = {
  stars: number | null;
  forks: number | null;
  release: Release | null;
};

const api = `https://api.github.com/repos/${repo.owner}/${repo.name}`;

async function getJSON(url: string): Promise<unknown | null> {
  const headers: Record<string, string> = { Accept: "application/vnd.github+json" };
  // A token raises the rate limit on build machines. The site builds fine without one.
  if (process.env.GITHUB_TOKEN) headers.Authorization = `Bearer ${process.env.GITHUB_TOKEN}`;
  try {
    const response = await fetch(url, { headers, signal: AbortSignal.timeout(8000) });
    return response.ok ? await response.json() : null;
  } catch {
    return null;
  }
}

/**
 * Reads star and fork counts and the latest release at build time, so they are
 * part of the static HTML. Any failure leaves that value empty instead of
 * failing the build; the page script refreshes the numbers in the browser.
 */
export async function getRepoStats(): Promise<RepoStats> {
  const [info, latest] = await Promise.all([getJSON(api), getJSON(`${api}/releases/latest`)]);
  const repoInfo = info as { stargazers_count?: number; forks_count?: number } | null;
  return {
    stars: repoInfo?.stargazers_count ?? null,
    forks: repoInfo?.forks_count ?? null,
    release: parseRelease(latest),
  };
}

export function parseRelease(data: unknown): Release | null {
  const release = data as { tag_name?: string; assets?: { name: string; size: number }[] } | null;
  if (!release?.tag_name) return null;
  const zip = release.assets?.find((asset) => asset.name.endsWith(".zip"));
  return { version: release.tag_name.replace(/^v/, ""), sizeBytes: zip?.size ?? null };
}

export function formatCount(value: number | null): string {
  if (value === null) return "";
  if (value < 1000) return String(value);
  return `${(value / 1000).toFixed(value < 10000 ? 1 : 0).replace(/\.0$/, "")}k`;
}

export function formatSize(bytes: number | null): string {
  return bytes === null ? "" : `${(bytes / 1_000_000).toFixed(1)} MB`;
}
