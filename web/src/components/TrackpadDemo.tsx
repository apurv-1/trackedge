import { useCallback, useEffect, useRef, useState, type KeyboardEvent, type PointerEvent } from "react";
import { icons, type IconName } from "../lib/icons";
import "./TrackpadDemo.css";

/** Values move in sixteenths, like the macOS volume and brightness keys. */
const STEPS = 16;
const EDGE = 0.13;
const BOTTOM = 0.17;

type Control = "volume" | "brightness";
type Hud =
  | { kind: Control; level: number; muted?: boolean }
  | { kind: "media"; icon: IconName; label: string };
type Finger = { x: number; y: number; pressed: boolean; visible: boolean };
type Gesture = {
  zone: Control | "media" | "corner" | null;
  startX: number;
  startY: number;
  startTime: number;
  moved: number;
  fired: boolean;
};

const clamp = (value: number) => Math.min(1, Math.max(0, value));
const quantize = (value: number) => Math.round(clamp(value) * STEPS) / STEPS;
const ease = (t: number) => (t < 0.5 ? 4 * t * t * t : 1 - (-2 * t + 2) ** 3 / 2);

function Glyph({ name, size = 18 }: { name: IconName; size?: number }) {
  const icon = icons[name];
  const filled = "fill" in icon && icon.fill;
  return (
    <svg
      width={size}
      height={size}
      viewBox={icon.viewBox}
      fill={filled ? "currentColor" : "none"}
      stroke={filled ? "none" : "currentColor"}
      strokeWidth={1.75}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      {icon.paths.map((d) => (
        <path key={d} d={d} />
      ))}
    </svg>
  );
}

function zoneAt(x: number, y: number): Gesture["zone"] {
  if (x > 0.84 && y > 0.78) return "corner";
  if (x < EDGE) return "brightness";
  if (x > 1 - EDGE) return "volume";
  if (y < BOTTOM) return "media";
  return null;
}

/** An element's box in pad coordinates: 0 to 1, with y growing upward like the real trackpad. */
type Box = { x: number; y: number; top: number; bottom: number };

export default function TrackpadDemo() {
  const padRef = useRef<HTMLDivElement>(null);
  const brightnessTrackRef = useRef<HTMLDivElement>(null);
  const volumeTrackRef = useRef<HTMLDivElement>(null);
  const cornerRef = useRef<HTMLDivElement>(null);
  const stripRef = useRef<HTMLDivElement>(null);
  const [volume, setVolume] = useState(0.5);
  const [brightness, setBrightness] = useState(0.75);
  const [muted, setMuted] = useState(false);
  const [hud, setHud] = useState<Hud | null>(null);
  const [hudVisible, setHudVisible] = useState(false);
  const [finger, setFinger] = useState<Finger>({ x: 0.5, y: 0.5, pressed: false, visible: false });
  const [tick, setTick] = useState(0);
  const [ripple, setRipple] = useState<{ x: number; y: number; id: number } | null>(null);

  const values = useRef({ volume: 0.5, brightness: 0.75, muted: false });
  const hudTimer = useRef<number | undefined>(undefined);
  const gesture = useRef<Gesture | null>(null);
  const lastTap = useRef<{ zone: Gesture["zone"]; time: number } | null>(null);
  const playing = useRef(true);
  const demoAbort = useRef<AbortController | null>(null);
  const idleTimer = useRef<number | undefined>(undefined);
  const inView = useRef(false);

  const showHud = useCallback((next: Hud) => {
    setHud(next);
    setHudVisible(true);
    window.clearTimeout(hudTimer.current);
    hudTimer.current = window.setTimeout(() => setHudVisible(false), 1300);
  }, []);

  /** Moves a control by `delta` and reports whether it crossed into a new step. */
  const adjust = useCallback(
    (control: Control, delta: number) => {
      const before = values.current[control];
      const after = clamp(before + delta);
      values.current[control] = after;
      if (control === "volume") {
        // Any slide unmutes, so the fill always shows the level the finger is holding.
        if (values.current.muted && delta !== 0) {
          values.current.muted = false;
          setMuted(false);
        }
        setVolume(after);
      } else {
        setBrightness(after);
      }
      if (quantize(after) !== quantize(before)) setTick((n) => n + 1);
      showHud({ kind: control, level: quantize(after), muted: control === "volume" && values.current.muted });
    },
    [showHud],
  );

  const toggleMute = useCallback(() => {
    values.current.muted = !values.current.muted;
    setMuted(values.current.muted);
    showHud({ kind: "volume", level: quantize(values.current.volume), muted: values.current.muted });
  }, [showHud]);

  const media = useCallback(
    (action: "next" | "previous" | "playPause") => {
      if (action === "playPause") {
        playing.current = !playing.current;
        showHud({ kind: "media", icon: "playPause", label: playing.current ? "Play" : "Pause" });
      } else {
        showHud({ kind: "media", icon: action === "next" ? "forward" : "back", label: action === "next" ? "Next track" : "Previous track" });
      }
    },
    [showHud],
  );

  const burst = useCallback((x: number, y: number) => setRipple({ x, y, id: Date.now() + Math.random() }), []);

  // MARK: Geometry. The finger reads where the tracks really are, so it always sits on the line.

  const boxOf = useCallback((element: HTMLElement | null): Box => {
    const pad = padRef.current?.getBoundingClientRect();
    const rect = element?.getBoundingClientRect();
    if (!pad || !rect || pad.width === 0) return { x: 0.5, y: 0.5, top: 1, bottom: 0 };
    return {
      x: (rect.left + rect.width / 2 - pad.left) / pad.width,
      y: 1 - (rect.top + rect.height / 2 - pad.top) / pad.height,
      top: 1 - (rect.top - pad.top) / pad.height,
      bottom: 1 - (rect.bottom - pad.top) / pad.height,
    };
  }, []);

  const trackBox = useCallback(
    (control: Control) => boxOf(control === "volume" ? volumeTrackRef.current : brightnessTrackRef.current),
    [boxOf],
  );

  /** The point on a track where a level's fill ends: the finger rests exactly there. */
  const levelPoint = useCallback(
    (control: Control, level: number) => {
      const track = trackBox(control);
      return { x: track.x, y: track.bottom + level * (track.top - track.bottom) };
    },
    [trackBox],
  );

  const setLevel = useCallback(
    (control: Control, level: number) => adjust(control, clamp(level) - values.current[control]),
    [adjust],
  );

  // MARK: Scripted demo, played while nobody is touching the pad.

  const runDemo = useCallback(
    async (signal: AbortSignal) => {
      const wait = (ms: number) =>
        new Promise<void>((resolve, reject) => {
          const onAbort = () => {
            window.clearTimeout(timer);
            reject(signal.reason);
          };
          const timer = window.setTimeout(() => {
            signal.removeEventListener("abort", onAbort);
            resolve();
          }, ms);
          signal.addEventListener("abort", onAbort, { once: true });
        });
      const tween = (ms: number, step: (t: number) => void) =>
        new Promise<void>((resolve, reject) => {
          const start = performance.now();
          const frame = (now: number) => {
            if (signal.aborted) return reject(signal.reason);
            const t = Math.min(1, (now - start) / ms);
            step(ease(t));
            if (t < 1) requestAnimationFrame(frame);
            else resolve();
          };
          requestAnimationFrame(frame);
        });

      /** Lands on the current level, then drags the fill to `to` with the finger riding its top. */
      const slide = async (control: Control, to: number) => {
        const from = values.current[control];
        setFinger({ ...levelPoint(control, from), pressed: false, visible: true });
        await wait(260);
        setFinger({ ...levelPoint(control, from), pressed: true, visible: true });
        await tween(1500, (t) => {
          const level = from + (to - from) * t;
          setLevel(control, level);
          setFinger({ ...levelPoint(control, level), pressed: true, visible: true });
        });
        setFinger({ ...levelPoint(control, to), pressed: false, visible: true });
        await wait(220);
        setFinger((f) => ({ ...f, visible: false }));
      };

      const doubleTap = async (target: HTMLElement | null, action: () => void) => {
        const { x, y } = boxOf(target);
        setFinger({ x, y, pressed: false, visible: true });
        await wait(300);
        for (let i = 0; i < 2; i++) {
          setFinger({ x, y, pressed: true, visible: true });
          burst(x, y);
          await wait(110);
          setFinger({ x, y, pressed: false, visible: true });
          await wait(130);
        }
        action();
        await wait(200);
        setFinger((f) => ({ ...f, visible: false }));
      };

      const swipe = async (from: number, to: number) => {
        const { y } = boxOf(stripRef.current);
        setFinger({ x: from, y, pressed: false, visible: true });
        await wait(260);
        setFinger({ x: from, y, pressed: true, visible: true });
        await tween(560, (t) => setFinger({ x: from + (to - from) * t, y, pressed: true, visible: true }));
        media(to > from ? "next" : "previous");
        setFinger({ x: to, y, pressed: false, visible: true });
        await wait(200);
        setFinger((f) => ({ ...f, visible: false }));
      };

      for (;;) {
        await wait(700);
        await slide("volume", 0.8);
        await wait(1100);
        await slide("brightness", 0.42);
        await wait(1100);
        await doubleTap(cornerRef.current, toggleMute);
        await wait(1300);
        await doubleTap(cornerRef.current, toggleMute);
        await wait(1000);
        await swipe(0.32, 0.7);
        await wait(1200);
        await slide("volume", 0.45);
        await wait(1100);
        await slide("brightness", 0.78);
        await wait(900);
      }
    },
    [boxOf, burst, levelPoint, media, setLevel, toggleMute],
  );

  const stopDemo = useCallback(() => {
    demoAbort.current?.abort();
    demoAbort.current = null;
  }, []);

  const startDemo = useCallback(() => {
    if (demoAbort.current || !inView.current) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    const controller = new AbortController();
    demoAbort.current = controller;
    // The demo ends by being aborted. Hide its finger unless the visitor's own finger has taken over.
    runDemo(controller.signal).catch(() => {
      if (!gesture.current) setFinger((f) => ({ ...f, pressed: false, visible: false }));
    });
  }, [runDemo]);

  /** Hands the pad to the visitor, then resumes the demo after a quiet spell. */
  const userActive = useCallback(() => {
    stopDemo();
    window.clearTimeout(idleTimer.current);
    idleTimer.current = window.setTimeout(startDemo, 6000);
  }, [startDemo, stopDemo]);

  useEffect(() => {
    const pad = padRef.current;
    if (!pad) return;
    const observer = new IntersectionObserver(([entry]) => {
      inView.current = entry.isIntersecting;
      if (entry.isIntersecting) startDemo();
      else stopDemo();
    });
    observer.observe(pad);
    return () => {
      observer.disconnect();
      stopDemo();
      window.clearTimeout(idleTimer.current);
      window.clearTimeout(hudTimer.current);
    };
  }, [startDemo, stopDemo]);

  // MARK: Pointer and keyboard input.

  const point = (event: PointerEvent<HTMLDivElement>) => {
    const rect = event.currentTarget.getBoundingClientRect();
    return { x: clamp((event.clientX - rect.left) / rect.width), y: clamp(1 - (event.clientY - rect.top) / rect.height) };
  };

  const onPointerDown = (event: PointerEvent<HTMLDivElement>) => {
    userActive();
    event.currentTarget.setPointerCapture(event.pointerId);
    const { x, y } = point(event);
    gesture.current = { zone: zoneAt(x, y), startX: x, startY: y, startTime: performance.now(), moved: 0, fired: false };
    setFinger({ x, y, pressed: true, visible: true });
  };

  const onPointerMove = (event: PointerEvent<HTMLDivElement>) => {
    const current = gesture.current;
    if (!current) return;
    const { x, y } = point(event);
    current.moved = Math.max(current.moved, Math.hypot(x - current.startX, y - current.startY));
    const sliding =
      current.zone === "volume" || current.zone === "brightness" || (current.zone === "corner" && current.moved > 0.03);
    if (sliding && current.moved > 0.015) {
      // The demo works like a slider: the level follows the finger, which snaps onto the track.
      const control: Control = current.zone === "brightness" ? "brightness" : "volume";
      const track = trackBox(control);
      const level = clamp((y - track.bottom) / (track.top - track.bottom));
      setLevel(control, level);
      setFinger({ ...levelPoint(control, level), pressed: true, visible: true });
      return;
    }
    setFinger({ x, y, pressed: true, visible: true });
    if (current.zone === "media" && !current.fired && Math.abs(x - current.startX) > 0.18) {
      current.fired = true;
      media(x > current.startX ? "next" : "previous");
    }
  };

  const onPointerUp = (event: PointerEvent<HTMLDivElement>) => {
    const current = gesture.current;
    gesture.current = null;
    setFinger((f) => ({ ...f, pressed: false, visible: false }));
    if (!current) return;
    const { x, y } = point(event);
    const isTap = performance.now() - current.startTime < 300 && current.moved < 0.03;
    if (!isTap || (current.zone !== "corner" && current.zone !== "media")) return;
    burst(x, y);
    const now = performance.now();
    if (lastTap.current?.zone === current.zone && now - lastTap.current.time < 420) {
      lastTap.current = null;
      if (current.zone === "corner") toggleMute();
      else media("playPause");
    } else {
      lastTap.current = { zone: current.zone, time: now };
    }
  };

  const onKeyDown = (event: KeyboardEvent<HTMLDivElement>) => {
    const step = (event.altKey ? 0.25 : 1) / STEPS;
    const control: Control = event.shiftKey ? "brightness" : "volume";
    if (event.key === "ArrowUp" || event.key === "ArrowDown") {
      event.preventDefault();
      userActive();
      adjust(control, event.key === "ArrowUp" ? step : -step);
    } else if (event.key.toLowerCase() === "m") {
      userActive();
      toggleMute();
    } else if (event.key === "ArrowRight" || event.key === "ArrowLeft") {
      event.preventDefault();
      userActive();
      media(event.key === "ArrowRight" ? "next" : "previous");
    }
  };

  const volumeShown = muted ? 0 : volume;
  const level = hud && hud.kind !== "media" ? Math.round((hud.muted ? 0 : hud.level) * STEPS) : 0;

  return (
    <div className="td">
      <div className={`td-hud${hudVisible ? " is-visible" : ""}`} aria-live="polite">
        {hud && hud.kind !== "media" && (
          <>
            <span className="td-hud-icon">
              <Glyph name={hud.kind === "brightness" ? "sun" : hud.muted ? "speakerMute" : "speaker"} size={20} />
            </span>
            <span className="td-chiclets" aria-label={`${hud.kind} ${Math.round((hud.muted ? 0 : hud.level) * 100)} percent`}>
              {Array.from({ length: STEPS }, (_, i) => (
                <i key={i} className={i < level ? `is-on is-${hud.kind}` : undefined} />
              ))}
            </span>
          </>
        )}
        {hud && hud.kind === "media" && (
          <>
            <span className="td-hud-icon">
              <Glyph name={hud.icon} size={18} />
            </span>
            <span className="td-hud-label">{hud.label}</span>
          </>
        )}
      </div>

      <div
        ref={padRef}
        className="td-pad"
        role="application"
        tabIndex={0}
        aria-label="Interactive TrackEdge demo. Drag along the right edge for volume or the left edge for brightness. With the keyboard, use the up and down arrows for volume, hold Shift for brightness, press M to mute, and use the left and right arrows to skip tracks."
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerUp}
        onPointerCancel={onPointerUp}
        onKeyDown={onKeyDown}
      >
        <div className="td-sheen" />

        <div className="td-zone td-zone-left">
          <div className="td-track" ref={brightnessTrackRef}>
            <div className="td-fill is-brightness" style={{ height: `${brightness * 100}%` }} />
          </div>
          <span className="td-zone-icon">
            <Glyph name="sun" size={14} />
          </span>
        </div>

        <div className="td-zone td-zone-right">
          <div className="td-track" ref={volumeTrackRef}>
            <div className="td-fill is-volume" style={{ height: `${volumeShown * 100}%` }} />
          </div>
          <span className="td-zone-icon">
            <Glyph name={muted ? "speakerMute" : "speaker"} size={14} />
          </span>
        </div>

        <div ref={cornerRef} className={`td-corner${muted ? " is-muted" : ""}`}>
          <Glyph name="speakerMute" size={13} />
        </div>

        <div ref={stripRef} className="td-strip">
          <Glyph name="back" size={11} />
          <span />
          <Glyph name="playPause" size={11} />
          <span />
          <Glyph name="forward" size={11} />
        </div>

        {ripple && (
          <span
            key={ripple.id}
            className="td-ripple"
            style={{ left: `${ripple.x * 100}%`, top: `${(1 - ripple.y) * 100}%` }}
          />
        )}

        <span
          className={`td-finger${finger.visible ? " is-visible" : ""}${finger.pressed ? " is-pressed" : ""}`}
          style={{ left: `${finger.x * 100}%`, top: `${(1 - finger.y) * 100}%` }}
        >
          {/* Restarts on every step, like the haptic tick under a real finger. */}
          {tick > 0 && <span key={tick} className="td-tick" />}
        </span>
      </div>
    </div>
  );
}
