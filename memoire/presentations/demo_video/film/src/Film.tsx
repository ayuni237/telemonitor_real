import React from 'react';
import { AbsoluteFill, Audio, OffthreadVideo, Sequence, staticFile, useCurrentFrame } from 'remotion';
import {
  AiLabel, Backdrop, Browser, Callouts, Caption, Clips, EndCard, Header, PHONE, Phone, Rect, TitleOverlay, WEB,
  camera, flat, zoomAt,
} from './components';
import { C, FPS, sec } from './theme';
import { DURATION, MUSIC, SCENES, Scene, VO, VOICE } from './timeline';

const XF = 10;   // cross-fade, frames

const AiScene: React.FC<{ scene: Scene; t: number }> = ({ scene, t }) => {
  const k = 1 + 0.035 * (t / scene.dur);
  const [big, small] = (scene.chapter ?? '').split(' · ');
  return (
    <AbsoluteFill style={{ background: '#000' }}>
      <OffthreadVideo src={staticFile(scene.src!)} playbackRate={scene.rate ?? 1} muted
        style={{ width: '100%', height: '100%', objectFit: 'cover', transform: `scale(${k})` }} />
      {scene.title ? <TitleOverlay t={t} big="TeleMonitor" small="Home follow-up of hypertension and diabetes" out={scene.dur - 1.2} mark /> : null}
      {scene.chapter ? <TitleOverlay t={t} big={big} small={small} out={scene.dur - 1.0} /> : null}
      <AiLabel />
    </AbsoluteFill>
  );
};

const DeviceScene: React.FC<{ scene: Scene; t: number }> = ({ scene, t }) => {
  const phone = scene.kind === 'phone';
  const clips = <Clips clips={scene.clips} lead={XF} total={scene.dur} />;
  if (phone) {                                   // the whole phone moves towards the camera
    const cam = camera(zoomAt(scene.zooms, t), PHONE);
    return (
      <AbsoluteFill>
        <Backdrop />
        <AbsoluteFill style={{ transformOrigin: '0 0', transform: `translate(${cam.dx}px, ${cam.dy}px) scale(${cam.s})` }}>
          <Phone r={PHONE}>{clips}</Phone>
        </AbsoluteFill>
        <Header scene={scene} mode="side" t={t} />
        <Callouts items={scene.callouts} t={t} map={(c) => cam.map(c.x, c.y)} />
      </AbsoluteFill>
    );
  }
  const local = { l: 0, t: 0, w: WEB.w, h: WEB.h };   // the browser stays put; its page zooms inside
  const cam = camera(zoomAt(scene.zooms, t), local, true);
  return (
    <AbsoluteFill>
      <Backdrop />
      <Browser r={WEB}>
        <AbsoluteFill style={{ transformOrigin: '0 0', transform: `translate(${cam.dx}px, ${cam.dy}px) scale(${cam.s})` }}>{clips}</AbsoluteFill>
      </Browser>
      <Header scene={scene} mode="side" t={t} />
      <Callouts items={scene.callouts} t={t} map={(c) => { const p = cam.map(c.x, c.y); return { x: WEB.l + p.x, y: WEB.t + p.y }; }} />
    </AbsoluteFill>
  );
};

const SPLIT_WEB: Rect = { l: 110, t: 236, w: 1140, h: 641 };
const SPLIT_PHONE: Rect = { l: 1430, t: 168, w: 350, h: 778 };

const SplitScene: React.FC<{ scene: Scene; t: number }> = ({ scene, t }) => (
  <AbsoluteFill>
    <Backdrop />
    <Browser r={SPLIT_WEB}><Clips clips={scene.web} lead={XF} total={scene.dur} /></Browser>
    <Phone r={SPLIT_PHONE}><Clips clips={scene.phone} lead={XF} total={scene.dur} /></Phone>
    <Header scene={scene} mode="top" t={t} />
    <Callouts items={scene.callouts} t={t} map={(c) => (c.on === 'phone' ? flat(SPLIT_PHONE) : flat(SPLIT_WEB))(c.x, c.y)} />
  </AbsoluteFill>
);

const SceneView: React.FC<{ scene: Scene; lead: number }> = ({ scene, lead }) => {
  const frame = useCurrentFrame();
  const t = (frame - lead) / FPS;
  const opacity = lead > 0 ? Math.min(1, frame / lead) : 1;
  let body: React.ReactNode;
  if (scene.kind === 'ai') body = <AiScene scene={scene} t={t} />;
  else if (scene.kind === 'split') body = <SplitScene scene={scene} t={t} />;
  else if (scene.kind === 'end') body = <EndCard t={t} dur={scene.dur} />;
  else body = <DeviceScene scene={scene} t={t} />;
  return <AbsoluteFill style={{ opacity }}>{body}</AbsoluteFill>;
};

const END_AT = SCENES[SCENES.length - 1].from;

/** Splits a sentence at commas and colons into single-line chunks, timed by their length. */
function chunks(text: string, max = 70): string[] {
  const parts = text.split(/(?<=[,:])\s+/);
  const res: string[] = [];
  for (const p of parts) {
    if (res.length && (res[res.length - 1] + ' ' + p).length <= max) res[res.length - 1] += ' ' + p;
    else res.push(p);
  }
  return res;
}

/** French subtitles of the English voice-over. */
const Captions: React.FC = () => {
  const t = useCurrentFrame() / FPS;
  if (t >= END_AT) return null;
  const v = VO.find((x) => t >= x.at && t <= x.at + (x.e - x.s) + 0.3);
  if (!v) return null;
  const dur = v.e - v.s;
  const cs = chunks(v.fr);
  const total = cs.reduce((n, c) => n + c.length, 0);
  let start = 0;
  for (let i = 0; i < cs.length; i++) {
    const len = (cs[i].length / total) * dur;
    const last = i === cs.length - 1;
    if (t - v.at < start + len || last) {
      return <Caption text={cs[i]} t={t - v.at - start + (i > 0 ? 0.2 : 0)} dur={last ? dur - start : len + 0.3} />;
    }
    start += len;
  }
  return null;
};

/** Music: low under the voice, up between sentences and on the end card. */
const musicVolume = (f: number) => {
  const t = f / FPS;
  let duck = 0;
  for (const v of VO) {
    const a = v.at - 0.3;
    const b = v.at + (v.e - v.s) + 0.3;
    if (t >= a && t <= b) duck = 1;
    else if (t > a - 0.5 && t < a) duck = Math.max(duck, (t - (a - 0.5)) / 0.5);
    else if (t > b && t < b + 0.8) duck = Math.max(duck, 1 - (t - b) / 0.8);
  }
  const fadeIn = Math.min(1, t / 1.5);
  const fadeOut = Math.min(1, Math.max(0, (DURATION - t) / 3));
  return fadeIn * fadeOut * (0.34 - 0.24 * duck);
};

export const Film: React.FC = () => (
  <AbsoluteFill style={{ background: C.bg2 }}>
    {SCENES.map((sc, i) => {
      const lead = i === 0 ? 0 : XF;
      return (
        <Sequence key={i} from={sec(sc.from) - lead} durationInFrames={sec(sc.dur) + lead}>
          <SceneView scene={sc} lead={lead} />
        </Sequence>
      );
    })}
    <Captions />
    {VO.map((v, i) => (
      <Sequence key={`vo${i}`} from={sec(v.at)} durationInFrames={sec(v.e - v.s) + 3}>
        <Audio src={staticFile(VOICE)} trimBefore={sec(v.s)} />
      </Sequence>
    ))}
    <Audio src={staticFile(MUSIC)} volume={musicVolume} />
  </AbsoluteFill>
);
