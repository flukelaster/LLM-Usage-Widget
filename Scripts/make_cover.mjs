#!/usr/bin/env node
// Build docs/cover.png — the GitHub social-preview / share card.
// Composes an HTML card (theme-matched to the app) with the real popover
// screenshot, then renders it with headless Chrome at 2× for crispness.
//
//   node Scripts/make_cover.mjs
//
// Requires: Google Chrome (headless) + docs/screenshot.png.
//
// Design note: color is kept deliberately restrained — it lives only where it
// means something (the brand gauge mark and the real data bars in the
// screenshot). The surrounding chrome stays neutral navy/slate so the product
// shot is what carries the eye.

import { readFileSync, writeFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const shot = readFileSync(join(root, "docs", "screenshot.png")).toString("base64");
const htmlPath = join(root, "docs", "cover.html");
const outPath = join(root, "docs", "cover.png");

const html = /* html */ `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  html, body { width: 1280px; height: 640px; }
  body {
    font-family: -apple-system, "SF Pro Display", "Inter", system-ui, sans-serif;
    background:
      radial-gradient(1100px 760px at 92% -20%, rgba(148,163,184,.10), transparent 60%),
      linear-gradient(160deg, #1B2436 0%, #0F172A 48%, #0B1120 100%);
    color: #F8FAFC;
    overflow: hidden;
    position: relative;
  }
  /* faint decorative gauge ring, bottom-right — monochrome, just a hint */
  .ring {
    position: absolute; right: -190px; bottom: -270px;
    width: 620px; height: 620px; border-radius: 50%;
    border: 56px solid rgba(255,255,255,.05);
    transform: rotate(8deg);
  }
  .grid {
    position: relative; z-index: 1;
    display: grid; grid-template-columns: 1fr 360px;
    height: 100%; align-items: center;
    padding: 56px 60px;
    gap: 40px;
  }
  .left { max-width: 700px; }

  .brand { display: flex; align-items: center; gap: 16px; margin-bottom: 30px; }
  .logo {
    width: 60px; height: 60px; border-radius: 16px;
    background: linear-gradient(180deg, #243049, #0B1120);
    border: 1px solid rgba(255,255,255,.10);
    box-shadow: 0 12px 30px rgba(0,0,0,.45);
    display: grid; place-items: center;
  }
  .logo svg { width: 40px; height: 40px; }
  .eyebrow {
    font-size: 16px; font-weight: 600; letter-spacing: .14em; text-transform: uppercase;
    color: #8294AC;
  }

  h1 {
    font-size: 72px; line-height: 1.02; font-weight: 800; letter-spacing: -.025em;
    margin-bottom: 22px; color: #F8FAFC;
  }
  h1 .accent { color: #93A4BC; }   /* subtle tonal shift, not a new hue */
  .tag {
    font-size: 25px; line-height: 1.42; color: #AEBACE; font-weight: 450;
    max-width: 640px; margin-bottom: 34px;
  }
  .tag b { color: #F1F5F9; font-weight: 650; }

  .features { display: flex; flex-direction: column; gap: 13px; margin-bottom: 36px; }
  .feat { display: flex; align-items: center; gap: 14px; font-size: 19px; color: #D5DDEA; }
  .dot { width: 7px; height: 7px; border-radius: 50%; flex: none; background: #5B6B85; }

  .providers { display: flex; align-items: center; gap: 14px; }
  .chip {
    display: flex; align-items: center; gap: 9px;
    padding: 9px 16px 9px 12px; border-radius: 999px;
    background: rgba(15,23,42,.5); border: 1px solid rgba(255,255,255,.08);
    font-size: 17px; font-weight: 600; color: #C7D0DE;
  }
  .chip svg { width: 22px; height: 22px; }

  /* right: floating popover screenshot — the one place color lives */
  .right { display: grid; place-items: center; height: 100%; }
  .shot-wrap { position: relative; transform: rotate(-2.5deg); }
  .shot {
    height: 540px; width: auto; display: block;
    border-radius: 20px;
    border: 1px solid rgba(255,255,255,.10);
    box-shadow: 0 40px 90px rgba(0,0,0,.6), 0 0 0 1px rgba(0,0,0,.25);
  }
</style></head>
<body>
  <div class="ring"></div>
  <div class="grid">
    <div class="left">
      <div class="brand">
        <div class="logo">
          <svg viewBox="0 0 100 100" fill="none">
            <circle cx="50" cy="50" r="36" stroke="rgba(255,255,255,.12)" stroke-width="13"
                    stroke-linecap="round" stroke-dasharray="170 226" transform="rotate(135 50 50)"/>
            <circle cx="50" cy="50" r="36" stroke="url(#g)" stroke-width="13"
                    stroke-linecap="round" stroke-dasharray="118 226" transform="rotate(135 50 50)"/>
            <defs><linearGradient id="g" x1="0" y1="1" x2="1" y2="0">
              <stop offset="0" stop-color="#32D74B"/><stop offset=".5" stop-color="#FFD60A"/>
              <stop offset="1" stop-color="#FF453A"/>
            </linearGradient></defs>
          </svg>
        </div>
        <div class="eyebrow">macOS&nbsp;·&nbsp;Menu&nbsp;Bar&nbsp;App</div>
      </div>

      <h1>LLM&nbsp;Usage&nbsp;<span class="accent">Widget</span></h1>
      <p class="tag">
        Real-time usage limits for <b>Claude</b>, <b>Codex</b>, and <b>GitHub&nbsp;Copilot</b> —
        live in your menu bar, the way Claude Desktop surfaces your usage windows.
      </p>

      <div class="features">
        <div class="feat"><span class="dot"></span>
          5-hour &amp; weekly bars with % used and a reset countdown</div>
        <div class="feat"><span class="dot"></span>
          The most-constrained % shown live, right in the menu bar</div>
        <div class="feat"><span class="dot"></span>
          Near-limit notification when any window crosses 90%</div>
        <div class="feat"><span class="dot"></span>
          In-app OAuth (PKCE) — tokens live only in your Keychain</div>
      </div>

      <div class="providers">
        <div class="chip">
          <svg viewBox="0 0 24 24"><g stroke="#9AA7BC" stroke-width="2" stroke-linecap="round">
            <line x1="12" y1="3" x2="12" y2="21"/><line x1="3" y1="12" x2="21" y2="12"/>
            <line x1="5.6" y1="5.6" x2="18.4" y2="18.4"/><line x1="18.4" y1="5.6" x2="5.6" y2="18.4"/>
          </g></svg>Claude
        </div>
        <div class="chip">
          <svg viewBox="0 0 24 24" fill="none"><circle cx="12" cy="12" r="9" stroke="#9AA7BC" stroke-width="2"/>
            <path d="M9 8.5 14.5 12 9 15.5z" fill="#9AA7BC"/></svg>Codex
        </div>
        <div class="chip">
          <svg viewBox="0 0 24 24" fill="none"><rect x="3" y="6" width="18" height="12" rx="6" stroke="#9AA7BC" stroke-width="2"/>
            <circle cx="9" cy="12" r="1.6" fill="#9AA7BC"/><circle cx="15" cy="12" r="1.6" fill="#9AA7BC"/></svg>Copilot
        </div>
      </div>
    </div>

    <div class="right">
      <div class="shot-wrap">
        <img class="shot" src="data:image/png;base64,${shot}" alt="popover">
      </div>
    </div>
  </div>
</body></html>`;

writeFileSync(htmlPath, html);

const chrome = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
execFileSync(chrome, [
  "--headless",
  "--no-sandbox",
  "--hide-scrollbars",
  "--force-device-scale-factor=2",
  "--default-background-color=00000000",
  "--window-size=1280,640",
  `--screenshot=${outPath}`,
  `file://${htmlPath}`,
], { stdio: "inherit" });

console.log(`cover: wrote ${outPath}`);
