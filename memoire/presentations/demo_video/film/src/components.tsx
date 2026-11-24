import React from 'react';
import {
  AbsoluteFill, Easing, Img, OffthreadVideo, Sequence, spring, staticFile, useCurrentFrame, useVideoConfig,
} from 'remotion';
import { C, F, FPS, sec } from './theme';
import type { Beat, Callout, Clip, Scene, Zoom } from './timeline';

export type Rect = { l: number; t: number; w: number; h: number };

export const ease = Easing.inOut(Easing.cubic);
const out = Easing.out(Easing.cubic);
export const clamp = (v: number, a = 0, b = 1) => Math.max(a, Math.min(b, v));

// ---------- camera ----------

export function zoomAt(zooms: Zoom[] | undefined, t: number): Zoom {
  if (!zooms || zooms.length === 0) return { t, s: 1, x: 0.5, y: 0.5 };
  if (t <= zooms[0].t) return zooms[0];
  for (let i = 0; i < zooms.length - 1; i++) {
    const a = zooms[i];
    const b = zooms[i + 1];
    if (t <= b.t) {
      const p = ease(clamp((t - a.t) / (b.t - a.t)));
      return { t, s: a.s + (b.s - a.s) * p, x: a.x + (b.x - a.x) * p, y: a.y + (b.y - a.y) * p };
    }
  }
  return zooms[zooms.length - 1];
}

/** Translation and scale that bring the zoom point towards the centre of `r`.
 *  `inner`: the zoom happens inside the frame `r` (local coordinates), never showing past its edges. */
export function camera(z: Zoom, r: Rect, inner = false) {
  const px = r.l + z.x * r.w;
  const py = r.t + z.y * r.h;
  const k = clamp((z.s - 1) / 0.5);
  const tx = px + (r.l + r.w / 2 - px) * k;
  const ty = py + (r.t + r.h / 2 - py) * k;
  let dx = tx - z.s * px;
  let dy = ty - z.s * py;
  if (inner) {
    dx = Math.min(0, Math.max(r.w - z.s * r.w, dx));
    dy = Math.min(0, Math.max(r.h - z.s * r.h, dy));
  }
  return { s: z.s, dx, dy, map: (x: number, y: number) => ({ x: dx + z.s * (r.l + x * r.w), y: dy + z.s * (r.t + y * r.h) }) };
}

export const flat = (r: Rect) => (x: number, y: number) => ({ x: r.l + x * r.w, y: r.t + y * r.h });

// ---------- media ----------

/** Plays the clips one after the other; the first starts `lead` frames early (cross-fade). */
export const Clips: React.FC<{ clips?: Clip[]; lead: number; total: number }> = ({ clips, lead, total }) => {
  if (!clips || clips.length === 0) return <AbsoluteFill style={{ background: '#2B3440' }} />;
  let at = 0;
  return (
    <AbsoluteFill style={{ overflow: 'hidden', background: '#000' }}>
      {clips.map((c, i) => {
        const rate = c.rate ?? 1;
        const from = i === 0 ? 0 : lead + sec(at);
        const last = i === clips.length - 1;
        const dur = last ? Math.max(sec(c.dur), lead + sec(total) - from) + (i === 0 ? 0 : 0) : (i === 0 ? lead : 0) + sec(c.dur);
        at += c.dur;
        return (
          <Sequence key={i} from={from} durationInFrames={dur} layout="none">
            <AbsoluteFill>
              <OffthreadVideo
                src={staticFile(c.src)}
                trimBefore={Math.max(0, Math.round(c.start * FPS - (i === 0 ? lead * rate : 0)))}
                playbackRate={rate}
                muted
                style={{ width: '100%', height: '100%', objectFit: 'cover' }}
              />
            </AbsoluteFill>
          </Sequence>
        );
      })}
    </AbsoluteFill>
  );
};

// ---------- devices ----------

export const PHONE: Rect = { l: 1260 - 360 / 2, t: 512 - 400, w: 360, h: 800 };
export const WEB: Rect = { l: 700, t: 238, w: 1120, h: 630 };

export const Phone: React.FC<{ r: Rect; children: React.ReactNode }> = ({ r, children }) => {
  const b = 13;
  return (
    <div style={{
      position: 'absolute', left: r.l - b, top: r.t - b, width: r.w + 2 * b, height: r.h + 2 * b,
      borderRadius: 58, background: '#0E1116', padding: b, boxSizing: 'border-box',
      boxShadow: '0 40px 90px rgba(18,53,91,0.35), 0 8px 20px rgba(0,0,0,0.25), inset 0 0 0 2px #2A2F37',
    }}>
      <div style={{ position: 'relative', width: r.w, height: r.h, borderRadius: 46, overflow: 'hidden', background: '#000' }}>
        {children}
      </div>
    </div>
  );
};

export const Browser: React.FC<{ r: Rect; children: React.ReactNode; label?: string }> = ({ r, children, label }) => {
  const bar = 36;
  return (
    <div style={{
      position: 'absolute', left: r.l, top: r.t - bar, width: r.w, height: r.h + bar, borderRadius: 14,
      overflow: 'hidden', background: '#fff', boxShadow: '0 40px 90px rgba(18,53,91,0.30), 0 8px 20px rgba(0,0,0,0.18)',
    }}>
      <div style={{ height: bar, background: '#EEF1F5', display: 'flex', alignItems: 'center', padding: '0 16px', gap: 8, borderBottom: '1px solid #D9DEE5' }}>
        {['#FF5F57', '#FEBC2E', '#28C840'].map((c) => <div key={c} style={{ width: 12, height: 12, borderRadius: 6, background: c }} />)}
        <div style={{ flex: 1, display: 'flex', justifyContent: 'center' }}>
          <div style={{ background: '#fff', borderRadius: 8, padding: '3px 28px', fontFamily: F.ui, fontSize: 15, color: C.grey }}>{label ?? 'TeleMonitor · clinician'}</div>
        </div>
        <div style={{ width: 52 }} />
      </div>
      <div style={{ position: 'relative', width: r.w, height: r.h, overflow: 'hidden' }}>{children}</div>
    </div>
  );
};

// ---------- text ----------

export const Backdrop: React.FC = () => (
  <AbsoluteFill style={{ background: 'radial-gradient(circle at 66% 46%, #FFFFFF 0%, #EEF2F6 42%, #D9E1EA 100%)' }} />
);

/** Words rise one after the other from behind a mask. */
export const RevealWords: React.FC<{ text: string; t: number; delay?: number; step?: number; style?: React.CSSProperties }> = ({ text, t, delay = 0, step = 0.07, style }) => (
  <div style={{ ...style, display: 'flex', flexWrap: 'wrap', columnGap: '0.26em' }}>
    {text.split(' ').map((w, i) => {
      const p = out(clamp((t - delay - i * step) / 0.5));
      return (
        <span key={i} style={{ display: 'inline-block', overflow: 'hidden', paddingBottom: '0.08em' }}>
          <span style={{ display: 'inline-block', transform: `translateY(${(1 - p) * 105}%)`, opacity: p }}>{w}</span>
        </span>
      );
    })}
  </div>
);

/** Letters rise one after the other. */
export const RevealLetters: React.FC<{ text: string; t: number; delay?: number; step?: number; style?: React.CSSProperties }> = ({ text, t, delay = 0, step = 0.035, style }) => (
  <div style={{ ...style, display: 'flex' }}>
    {text.split('').map((ch, i) => {
      const p = out(clamp((t - delay - i * step) / 0.55));
      return (
        <span key={i} style={{ display: 'inline-block', overflow: 'hidden' }}>
          <span style={{ display: 'inline-block', transform: `translateY(${(1 - p) * 100}%)`, opacity: p, whiteSpace: 'pre' }}>{ch}</span>
        </span>
      );
    })}
  </div>
);

/** The explanation lines of a scene: each appears with the action; the newest is highlighted. */
export const Beats: React.FC<{ beats?: Beat[]; t: number }> = ({ beats, t }) => {
  if (!beats) return null;
  const shown = beats.filter((b) => t >= b.t);
  return (
    <div style={{ marginTop: 34, display: 'flex', flexDirection: 'column', gap: 16 }}>
      {beats.map((b, i) => {
        const p = out(clamp((t - b.t) / 0.45));
        if (p <= 0) return null;
        const current = b === shown[shown.length - 1];
        const col = b.color ?? C.navy;
        const fill = clamp((t - b.t) / 0.35);
        return (
          <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 16, opacity: p * (current ? 1 : 0.62), transform: `translateX(${(1 - p) * -28}px)` }}>
            <div style={{ position: 'relative', width: 30, height: 30, flex: 'none' }}>
              <svg width={30} height={30} viewBox="0 0 30 30">
                <circle cx={15} cy={15} r={13} fill={current ? col : 'none'} stroke={col} strokeWidth={2.5}
                  strokeDasharray={82} strokeDashoffset={82 * (1 - fill)} transform="rotate(-90 15 15)" />
                <path d="M9 15.5 l4 4 l8 -9" fill="none" stroke={current ? '#fff' : col} strokeWidth={2.8} strokeLinecap="round" strokeLinejoin="round"
                  strokeDasharray={22} strokeDashoffset={22 * (1 - clamp((t - b.t - 0.2) / 0.3))} />
              </svg>
            </div>
            <div style={{ fontFamily: F.ui, fontSize: 30, fontWeight: current ? 600 : 400, color: current ? C.ink : C.grey, lineHeight: 1.25 }}>{b.text}</div>
          </div>
        );
      })}
    </div>
  );
};

export const Header: React.FC<{ scene: Scene; mode: 'side' | 'top'; t: number }> = ({ scene, mode, t }) => {
  const lp = out(clamp(t / 0.5));
  const label = (
    <div style={{ fontFamily: F.ui, fontWeight: 700, fontSize: 21, textTransform: 'uppercase', color: C.red, opacity: lp,
      letterSpacing: 2 + (1 - lp) * 6, whiteSpace: 'nowrap' }}>{scene.header}</div>
  );
  if (mode === 'top') {
    return (
      <div style={{ position: 'absolute', left: 110, top: 58, width: 1700, display: 'flex', alignItems: 'baseline', gap: 26 }}>
        {label}
        <RevealWords text={scene.heading ?? ''} t={t} delay={0.15} style={{ fontFamily: F.title, fontWeight: 700, fontSize: 48, color: C.navy }} />
      </div>
    );
  }
  const left = scene.kind === 'web' ? 90 : 120;
  const width = scene.kind === 'web' ? 540 : 680;
  return (
    <div style={{ position: 'absolute', left, top: scene.kind === 'web' ? 238 : 250, width }}>
      {label}
      <div style={{ height: 14 }} />
      <RevealWords text={scene.heading ?? ''} t={t} delay={0.15} style={{ fontFamily: F.title, fontWeight: 700, fontSize: scene.kind === 'web' ? 54 : 60, lineHeight: 1.08, color: C.navy }} />
      <Beats beats={scene.beats} t={t} />
    </div>
  );
};

export const Callouts: React.FC<{ items?: Callout[]; t: number; map: (c: Callout) => { x: number; y: number } }> = ({ items, t, map }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  if (!items) return null;
  return (
    <AbsoluteFill style={{ pointerEvents: 'none' }}>
      {items.map((c, i) => {
        if (t < c.t || (c.until !== undefined && t > c.until + 0.4)) return null;
        const inP = spring({ frame: frame - Math.round(c.t * fps), fps, config: { damping: 18, stiffness: 140 } });
        const outP = c.until !== undefined ? 1 - clamp((t - c.until) / 0.4) : 1;
        const p = Math.min(inP, outP);
        const a = map(c);
        const bx = a.x + c.dx;
        const by = a.y + c.dy;
        const col = c.color ?? C.navy;
        return (
          <React.Fragment key={i}>
            <svg width={1920} height={1080} style={{ position: 'absolute', left: 0, top: 0, opacity: p }}>
              <line x1={a.x} y1={a.y} x2={a.x + (bx - a.x) * p} y2={a.y + (by - a.y) * p} stroke={col} strokeWidth={3} />
              <circle cx={a.x} cy={a.y} r={10 * p} fill={col} stroke="#fff" strokeWidth={3} />
            </svg>
            <div style={{
              position: 'absolute', left: bx, top: by, transform: `translate(-50%, -50%) scale(${0.85 + 0.15 * p})`, opacity: p,
              background: '#fff', borderRadius: 40, padding: '12px 26px', display: 'flex', alignItems: 'center', gap: 12,
              boxShadow: '0 12px 30px rgba(18,53,91,0.25)', border: `2px solid ${col}`, whiteSpace: 'nowrap',
            }}>
              <div style={{ width: 14, height: 14, borderRadius: 7, background: col }} />
              <div style={{ fontFamily: F.ui, fontWeight: 600, fontSize: 30, color: C.ink }}>{c.text}</div>
            </div>
          </React.Fragment>
        );
      })}
    </AbsoluteFill>
  );
};

export const AiLabel: React.FC = () => (
  <div style={{
    position: 'absolute', left: 36, top: 32, background: 'rgba(0,0,0,0.45)', color: '#fff', borderRadius: 8,
    padding: '6px 14px', fontFamily: F.ui, fontSize: 20,
  }}>Illustration (AI-generated)</div>
);

export const Caption: React.FC<{ text: string; t: number; dur: number }> = ({ text, t, dur }) => {
  const p = clamp(t / 0.2) * (1 - clamp((t - dur) / 0.25));
  return (
    <div style={{ position: 'absolute', left: 0, right: 0, bottom: 40, display: 'flex', justifyContent: 'center', opacity: p }}>
      <div style={{
        maxWidth: 1560, background: 'rgba(12,22,36,0.76)', color: '#fff', borderRadius: 12, padding: '10px 28px',
        fontFamily: F.ui, fontWeight: 600, fontSize: 34, lineHeight: 1.3, textAlign: 'center',
      }}>{text}</div>
    </div>
  );
};

/** The TeleMonitor mark: a rounded frame crossed by a heartbeat, drawn stroke by stroke. */
export const LogoMark: React.FC<{ t: number; size: number; color?: string }> = ({ t, size, color = '#fff' }) => {
  const a = out(clamp(t / 0.9));
  const b = out(clamp((t - 0.45) / 0.8));
  return (
    <svg width={size} height={size} viewBox="0 0 100 100" style={{ overflow: 'visible' }}>
      <defs>
        <filter id="glow" x="-50%" y="-50%" width="200%" height="200%">
          <feGaussianBlur stdDeviation="2.5" result="b" />
          <feMerge><feMergeNode in="b" /><feMergeNode in="SourceGraphic" /></feMerge>
        </filter>
      </defs>
      <path d="M30 22 H78 a12 12 0 0 1 12 12 V40 M90 60 V66 a12 12 0 0 1 -12 12 H22 a12 12 0 0 1 -12 -12 V60 M10 40 V34 a12 12 0 0 1 12 -12 H30"
        fill="none" stroke={color} strokeWidth={7} strokeLinecap="round" strokeLinejoin="round"
        pathLength={1} strokeDasharray={1} strokeDashoffset={1 - a} />
      <path d="M4 50 H30 L38 36 L48 66 L58 30 L66 50 H96" fill="none" stroke={color} strokeWidth={7} strokeLinecap="round" strokeLinejoin="round"
        pathLength={1} strokeDasharray={1} strokeDashoffset={1 - b} filter="url(#glow)" />
    </svg>
  );
};

export const TitleOverlay: React.FC<{ t: number; big: string; small: string; out: number; mark?: boolean }> = ({ t, big, small, out: outAt, mark }) => {
  const fade = 1 - ease(clamp((t - outAt) / 0.7));
  const bg = ease(clamp((t - 0.2) / 0.8)) * fade;
  return (
    <AbsoluteFill>
      <AbsoluteFill style={{ opacity: bg, background: 'linear-gradient(90deg, rgba(8,18,32,0.78) 0%, rgba(8,18,32,0.4) 36%, rgba(8,18,32,0) 60%)' }} />
      <div style={{ position: 'absolute', left: 110, top: 360, opacity: fade }}>
        {mark ? <div style={{ marginBottom: 18 }}><LogoMark t={t - 0.3} size={86} /></div> : null}
        <RevealLetters text={big} t={t} delay={mark ? 0.9 : 0.4} style={{ fontFamily: F.ui, fontWeight: 700, fontSize: mark ? 104 : 86, color: '#fff', letterSpacing: -1 }} />
        <RevealWords text={small} t={t} delay={mark ? 1.6 : 1.0} step={0.05} style={{ fontFamily: F.ui, fontSize: 34, color: '#D7E0EA', marginTop: 6 }} />
      </div>
    </AbsoluteFill>
  );
};

export const EndCard: React.FC<{ t: number; dur: number }> = ({ t, dur }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const fadeOut = 1 - clamp((t - (dur - 0.7)) / 0.7);
  const up = (d: number, len = 0.6) => {
    const p = out(clamp((t - d) / len));
    return { opacity: p, transform: `translateY(${(1 - p) * 18}px)`, filter: `blur(${(1 - p) * 6}px)` };
  };
  const dot = (i: number) => spring({ frame: frame - Math.round((2.2 + i * 0.15) * fps), fps, config: { damping: 11, stiffness: 160 } });
  const line = out(clamp((t - 2.7) / 0.7));
  const logo = (i: number) => spring({ frame: frame - Math.round((3.9 + i * 0.15) * fps), fps, config: { damping: 16, stiffness: 120 } });
  return (
    <AbsoluteFill style={{ background: '#081A2E', opacity: fadeOut }}>
      <AbsoluteFill style={{ transform: 'scale(1.22)', transformOrigin: '50% 0%' }}>
        <OffthreadVideo src={staticFile('ai/endbg_b.mp4')} trimBefore={15} muted style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
      </AbsoluteFill>
      <AbsoluteFill style={{ background: 'radial-gradient(ellipse at 50% 38%, rgba(8,26,46,0.15) 0%, rgba(8,26,46,0.55) 70%, rgba(4,12,22,0.85) 100%)' }} />
      <AbsoluteFill style={{ alignItems: 'center', paddingTop: 128 }}>
        <LogoMark t={t - 0.2} size={110} />
        <RevealLetters text="TeleMonitor" t={t} delay={0.8} style={{ fontFamily: F.ui, fontWeight: 700, fontSize: 124, color: '#fff', letterSpacing: -1.5, marginTop: 22 }} />
        <div style={{ fontFamily: F.ui, fontSize: 38, color: '#C9D6E5', marginTop: 6, ...up(1.5, 0.8) }}>
          Home follow-up of hypertension and diabetes, between two visits
        </div>
        <div style={{ display: 'flex', gap: 18, marginTop: 34 }}>
          {[C.green, '#E0A020', C.red].map((c, i) => (
            <div key={c} style={{ width: 20, height: 20, borderRadius: 10, background: c, transform: `scale(${dot(i)})`, boxShadow: `0 0 18px ${c}` }} />
          ))}
        </div>
        <div style={{ width: 520 * line, height: 1.5, background: 'linear-gradient(90deg, rgba(255,255,255,0), rgba(255,255,255,0.7), rgba(255,255,255,0))', marginTop: 34 }} />
        <div style={{ fontFamily: F.ui, fontWeight: 600, fontSize: 34, color: '#fff', marginTop: 30, ...up(3.0) }}>NSAME AYUNI Rodrick</div>
        <div style={{ fontFamily: F.ui, fontSize: 25, color: '#C9D6E5', marginTop: 8, ...up(3.2) }}>
          Master's thesis · NHPSD, University of Douala · 2025–2026
        </div>
        <div style={{ fontFamily: F.ui, fontSize: 23, color: '#8FA8C2', marginTop: 8, letterSpacing: 0.5, ...up(3.4) }}>github.com/ayuni237/telemonitor_real</div>
        <div style={{ display: 'flex', gap: 26, marginTop: 30 }}>
          {['logos/enspd.png', 'logos/udo.png'].map((l, i) => (
            <div key={l} style={{
              background: 'rgba(255,255,255,0.94)', borderRadius: 18, padding: 10, height: 92, display: 'flex',
              boxShadow: '0 10px 30px rgba(0,0,0,0.35)', transform: `scale(${logo(i)})`, opacity: clamp(logo(i) * 1.5),
            }}>
              <Img src={staticFile(l)} style={{ height: '100%' }} />
            </div>
          ))}
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
