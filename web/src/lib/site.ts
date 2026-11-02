/** Prefixes a path with the base the site is served from, such as /trackedge on GitHub Pages. */
export function sitePath(path = ""): string {
  return `${import.meta.env.BASE_URL.replace(/\/$/, "")}/${path.replace(/^\//, "")}`;
}

export const repo = {
  owner: "apurv-1",
  name: "trackedge",
  url: "https://github.com/apurv-1/trackedge",
  releases: "https://github.com/apurv-1/trackedge/releases",
  // Every release uploads a TrackEdge.zip, so this link always serves the newest version.
  download: "https://github.com/apurv-1/trackedge/releases/latest/download/TrackEdge.zip",
  readme: "https://github.com/apurv-1/trackedge#readme",
  issues: "https://github.com/apurv-1/trackedge/issues",
};

export const product = {
  name: "TrackEdge",
  tagline: "Volume and brightness on your trackpad's edges",
  description:
    "TrackEdge is a free, open-source Mac menu bar app that turns the edges of your trackpad into volume and brightness sliders, with quick mute, a media strip, and haptic ticks.",
  minimumMacOS: "macOS 13",
};
