/**
 * Draws slow ribbons of cyan, indigo, and amber light behind the hero.
 * The canvas renders at half resolution and CSS blurs it once on the GPU,
 * which looks the same as blurring each stroke and costs far less.
 * Stops drawing while off screen or in a background tab, and draws a single
 * still frame for people who prefer reduced motion.
 */
type Ribbon = {
  color: string;
  y: number;
  amplitude: number;
  wavelength: number;
  speed: number;
  thickness: number;
  phase: number;
};

const ribbons: Ribbon[] = [
  { color: "100, 210, 255", y: 0.42, amplitude: 0.09, wavelength: 1.25, speed: 0.07, thickness: 0.16, phase: 0 },
  { color: "94, 92, 230", y: 0.52, amplitude: 0.12, wavelength: 0.95, speed: -0.05, thickness: 0.22, phase: 2.1 },
  { color: "255, 179, 64", y: 0.6, amplitude: 0.06, wavelength: 1.6, speed: 0.04, thickness: 0.08, phase: 4.2 },
];

export function startAurora(canvas: HTMLCanvasElement): void {
  const context = canvas.getContext("2d");
  if (!context) return;
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  let width = 0;
  let height = 0;
  let frame = 0;
  let visible = true;

  const resize = () => {
    const ratio = 0.5;
    width = canvas.clientWidth;
    height = canvas.clientHeight;
    canvas.width = Math.round(width * ratio);
    canvas.height = Math.round(height * ratio);
    context.setTransform(ratio, 0, 0, ratio, 0, 0);
  };

  const draw = (time: number) => {
    const t = time / 1000;
    context.clearRect(0, 0, width, height);
    context.globalCompositeOperation = "lighter";
    for (const ribbon of ribbons) {
      const thickness = ribbon.thickness * height;
      for (let layer = 0; layer < 3; layer++) {
        context.beginPath();
        for (let x = -20; x <= width + 20; x += 16) {
          const u = x / width;
          const wave =
            Math.sin(u * Math.PI * 2 * ribbon.wavelength + ribbon.phase + t * ribbon.speed * 6) * ribbon.amplitude +
            Math.sin(u * Math.PI * 5.3 + t * ribbon.speed * 3 + layer) * ribbon.amplitude * 0.25;
          const y = (ribbon.y + wave + (layer - 1) * 0.02) * height;
          if (x === -20) context.moveTo(x, y);
          else context.lineTo(x, y);
        }
        context.lineWidth = thickness * (1 - layer * 0.28);
        context.strokeStyle = `rgba(${ribbon.color}, ${0.05 + layer * 0.035})`;
        context.stroke();
      }
    }
    context.globalCompositeOperation = "source-over";
  };

  const loop = (time: number) => {
    draw(time);
    if (visible && !document.hidden) frame = requestAnimationFrame(loop);
  };

  const restart = () => {
    cancelAnimationFrame(frame);
    if (reduceMotion) draw(0);
    else if (visible && !document.hidden) frame = requestAnimationFrame(loop);
  };

  resize();
  new ResizeObserver(() => {
    resize();
    if (reduceMotion) draw(0);
  }).observe(canvas);
  new IntersectionObserver(([entry]) => {
    visible = entry.isIntersecting;
    restart();
  }).observe(canvas);
  document.addEventListener("visibilitychange", restart);
  restart();
}
