const GLYPHS = ".:'`_,-8";
const DECODE_MS = 1400;
const BLINK_MS = 140;

const randomGlyph = () => GLYPHS[Math.floor(Math.random() * GLYPHS.length)];
const randomBetween = (min, max) => min + Math.random() * (max - min);
const wait = (ms) => new Promise((r) => setTimeout(r, ms));
const reducedMotion = () =>
  window.matchMedia("(prefers-reduced-motion: reduce)").matches;

const artHeight = (tpl) =>
  tpl.content.querySelector("pre").textContent.trimEnd().split("\n").length;

export function pickArt(el) {
  const templates = [...document.querySelectorAll("template.ascii-art")];
  if (!el || templates.length === 0) return null;

  const tpl = templates[Math.floor(Math.random() * templates.length)];
  const tallest = Math.max(...templates.map(artHeight));
  const padding = "\n".repeat(Math.floor((tallest - artHeight(tpl)) / 2));
  const frames = [...tpl.content.querySelectorAll("pre")].map(
    (pre) => padding + pre.textContent
  );
  el.textContent = frames[0];
  return {
    frames,
    mode: tpl.dataset.mode,
    interval: Number(tpl.dataset.interval) || 600,
  };
}

function decode(el, art) {
  const chars = [...art];
  const lines = art.split("\n").length;
  let line = 0;
  const settleAt = chars.map((c) => {
    if (c === "\n") line++;
    if (/\s/.test(c)) return 0;
    return (line / lines) * DECODE_MS * 0.5 + Math.random() * DECODE_MS * 0.5;
  });

  el.textContent = chars.map((c) => (/\s/.test(c) ? c : randomGlyph())).join("");

  return new Promise((resolve) => {
    const start = performance.now();
    let lastFrame = 0;
    const frame = (now) => {
      const elapsed = now - start;
      if (now - lastFrame > 50 || elapsed >= DECODE_MS) {
        lastFrame = now;
        el.textContent = chars
          .map((c, i) => (elapsed >= settleAt[i] ? c : randomGlyph()))
          .join("");
      }
      if (elapsed < DECODE_MS) requestAnimationFrame(frame);
      else {
        el.textContent = art;
        resolve();
      }
    };
    requestAnimationFrame(frame);
  });
}

function blink(el, [main, alt]) {
  const blinkOnce = async () => {
    el.textContent = alt;
    await wait(BLINK_MS);
    el.textContent = main;
  };

  const schedule = () => {
    setTimeout(async () => {
      if (!document.hidden) {
        await blinkOnce();
        if (Math.random() < 0.25) {
          await wait(120);
          await blinkOnce();
        }
      }
      schedule();
    }, randomBetween(3000, 7000));
  };
  schedule();
}

function loop(el, frames, interval) {
  let i = 0;
  setInterval(() => {
    if (document.hidden) return;
    i = (i + 1) % frames.length;
    el.textContent = frames[i];
  }, interval);
}

export async function animateAscii(el, art) {
  if (!el || !art || reducedMotion()) return;

  await decode(el, art.frames[0]);
  if (art.frames.length < 2) return;
  if (art.mode === "loop") loop(el, art.frames, art.interval);
  else blink(el, art.frames);
}
