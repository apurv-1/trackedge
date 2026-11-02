import { formatCount, formatSize, parseRelease } from "../lib/github";
import { repo } from "../lib/site";
import { startAurora } from "./aurora";

// Fade sections up as they scroll into view.
const revealObserver = new IntersectionObserver(
  (entries) => {
    for (const entry of entries) {
      if (!entry.isIntersecting) continue;
      entry.target.classList.add("is-visible");
      revealObserver.unobserve(entry.target);
    }
  },
  { rootMargin: "0px 0px -8% 0px" },
);
document.querySelectorAll("[data-reveal]").forEach((element) => revealObserver.observe(element));

document.querySelectorAll<HTMLCanvasElement>("canvas[data-aurora]").forEach(startAurora);

// Copy buttons next to code snippets.
document.querySelectorAll<HTMLButtonElement>("[data-copy]").forEach((button) => {
  button.addEventListener("click", async () => {
    try {
      await navigator.clipboard.writeText(button.dataset.copy ?? "");
      button.dataset.state = "copied";
      setTimeout(() => delete button.dataset.state, 1600);
    } catch {
      // Clipboard access can be denied; the snippet stays selectable.
    }
  });
});

/**
 * The build bakes in GitHub numbers. This refreshes them in the browser so the
 * star count stays current between deploys. Results are cached for ten minutes
 * to stay well inside GitHub's unauthenticated rate limit.
 */
async function refreshGitHub(): Promise<void> {
  const cacheKey = "trackedge:github";
  type Cached = { at: number; stars: number | null; forks: number | null; release: unknown };
  let data: Cached | null = null;
  try {
    const cached = JSON.parse(sessionStorage.getItem(cacheKey) ?? "null") as Cached | null;
    if (cached && Date.now() - cached.at < 10 * 60 * 1000) data = cached;
  } catch {
    // Storage can be unavailable in private windows.
  }

  if (!data) {
    const api = `https://api.github.com/repos/${repo.owner}/${repo.name}`;
    const get = (url: string) => fetch(url).then((response) => (response.ok ? response.json() : null)).catch(() => null);
    const [info, release] = await Promise.all([get(api), get(`${api}/releases/latest`)]);
    if (!info) return;
    data = { at: Date.now(), stars: info.stargazers_count ?? null, forks: info.forks_count ?? null, release };
    try {
      sessionStorage.setItem(cacheKey, JSON.stringify(data));
    } catch {
      // Ignore storage failures.
    }
  }

  const set = (name: string, value: string) => {
    if (!value) return;
    document.querySelectorAll<HTMLElement>(`[data-gh="${name}"]`).forEach((element) => {
      element.textContent = value;
      element.hidden = false;
    });
  };
  set("stars", formatCount(data.stars));
  set("star-badge", data.stars ? formatCount(data.stars) : "");
  set("forks", formatCount(data.forks));

  const release = parseRelease(data.release);
  if (release) {
    set("version", `v${release.version}`);
    set("size", formatSize(release.sizeBytes));
  }
}

refreshGitHub();
