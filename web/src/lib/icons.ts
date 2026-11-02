/** Icon geometry shared by the Astro pages and the React demo. Stroke icons use a 24 pt grid. */
export type IconDef = { viewBox: string; paths: string[]; fill?: boolean };

export const icons = {
  github: {
    viewBox: "0 0 16 16",
    fill: true,
    paths: [
      "M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.01 8.01 0 0 0 16 8c0-4.42-3.58-8-8-8z",
    ],
  },
  star: {
    viewBox: "0 0 24 24",
    fill: true,
    paths: ["M12 2.6l2.85 5.95 6.55.85-4.8 4.55 1.22 6.5L12 17.3l-5.82 3.15 1.22-6.5-4.8-4.55 6.55-.85z"],
  },
  download: { viewBox: "0 0 24 24", paths: ["M12 4v11", "M7 10.5l5 5 5-5", "M5 20h14"] },
  speaker: {
    viewBox: "0 0 24 24",
    paths: ["M4 9.5h3.5L12 5.5v13l-4.5-4H4z", "M15.5 9a4.2 4.2 0 0 1 0 6", "M18 6.5a7.6 7.6 0 0 1 0 11"],
  },
  speakerMute: { viewBox: "0 0 24 24", paths: ["M4 9.5h3.5L12 5.5v13l-4.5-4H4z", "M16 9.5l5 5", "M21 9.5l-5 5"] },
  sun: {
    viewBox: "0 0 24 24",
    paths: [
      "M12 8.4a3.6 3.6 0 1 0 0 7.2 3.6 3.6 0 0 0 0-7.2z",
      "M12 2.5v2.2M12 19.3v2.2M2.5 12h2.2M19.3 12h2.2M5.3 5.3l1.5 1.5M17.2 17.2l1.5 1.5M5.3 18.7l1.5-1.5M17.2 6.8l1.5-1.5",
    ],
  },
  forward: { viewBox: "0 0 24 24", fill: true, paths: ["M4 6.5l7.5 5.5L4 17.5z", "M12.5 6.5L20 12l-7.5 5.5z"] },
  back: { viewBox: "0 0 24 24", fill: true, paths: ["M20 6.5L12.5 12l7.5 5.5z", "M11.5 6.5L4 12l7.5 5.5z"] },
  playPause: { viewBox: "0 0 24 24", fill: true, paths: ["M3.5 6l8 6-8 6z", "M14 6h2.6v12H14z", "M18.6 6h2.6v12h-2.6z"] },
  haptic: { viewBox: "0 0 24 24", paths: ["M2.5 12h2.2l2-5.5 3 11 3-14 3 13 2-7 1.2 2.5h2.6"] },
  cursor: { viewBox: "0 0 24 24", paths: ["M6 3.8l12 7-5.3 1.4-2.6 5.4z", "M14 14l4.5 4.5"] },
  shield: { viewBox: "0 0 24 24", paths: ["M12 3l7.5 3v5.6c0 4.4-3.2 8.1-7.5 9.4-4.3-1.3-7.5-5-7.5-9.4V6z", "M8.8 12l2.2 2.2 4.2-4.4"] },
  sliders: { viewBox: "0 0 24 24", paths: ["M6 4v16M12 4v16M18 4v16", "M4 8.5h4M10 15h4M16 11h4"] },
  menuBar: { viewBox: "0 0 24 24", paths: ["M3 5.5h18v4H3z", "M14.5 7.5h4", "M3 9.5v9h18v-9"] },
  mouse: { viewBox: "0 0 24 24", paths: ["M12 3a6 6 0 0 1 6 6v6a6 6 0 0 1-12 0V9a6 6 0 0 1 6-6z", "M12 6.5v3.5"] },
  swap: { viewBox: "0 0 24 24", paths: ["M6 7.5h12l-3.2-3.2", "M18 16.5H6l3.2 3.2"] },
  copy: { viewBox: "0 0 24 24", paths: ["M9 9h10.5v11H9z", "M5 15V4h10"] },
  check: { viewBox: "0 0 24 24", paths: ["M5 12.5l4.5 4.5L19 7.5"] },
  arrowUpRight: { viewBox: "0 0 24 24", paths: ["M7 17L17 7", "M9 7h8v8"] },
  book: { viewBox: "0 0 24 24", paths: ["M4.5 5.5A2.5 2.5 0 0 1 7 3h12.5v15H7a2.5 2.5 0 0 0-2.5 2.5z", "M4.5 5.5v15", "M19.5 18v3H7"] },
} satisfies Record<string, IconDef>;

export type IconName = keyof typeof icons;
