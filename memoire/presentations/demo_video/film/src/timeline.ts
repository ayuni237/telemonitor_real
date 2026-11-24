/**
 * The film, scene by scene (times in seconds). Every app screen comes from the takes of
 * 23 November 2026 (rec/*.mp4, see FILM_SCRIPT.md); AI scenes are labelled as such.
 */
import { C } from './theme';

/** A piece of a take: `start` in the source, `dur` on screen, `rate` speeds it up. */
export type Clip = { src: string; start: number; dur: number; rate?: number };
/** Camera on a device: at `t` (s from scene start) zoom `s` centred on screen point (x, y) in 0-1. */
export type Zoom = { t: number; s: number; x: number; y: number };
/** A label pointing at a screen point (x, y), placed (dx, dy) px away from it. */
export type Callout = { t: number; until?: number; text: string; x: number; y: number; dx: number; dy: number; color?: string; on?: 'web' | 'phone' };
/** A line of on-screen explanation that appears at `t`. */
export type Beat = { t: number; text: string; color?: string };

export type Scene = {
  kind: 'ai' | 'phone' | 'web' | 'split' | 'end';
  from: number;
  dur: number;
  src?: string;
  rate?: number;
  title?: boolean;
  chapter?: string;
  header?: string;
  heading?: string;
  beats?: Beat[];
  clips?: Clip[];
  phone?: Clip[];
  web?: Clip[];
  zooms?: Zoom[];
  callouts?: Callout[];
};

/** Voice-over: sentence (s..e in the voice file) placed at film time `at`; `fr` is the subtitle. */
export type Vo = { at: number; s: number; e: number; text: string; fr: string };

export const VOICE = 'voice/vo2_helena.mp3';
export const MUSIC = 'music/bed_a.mp3';

export const VO: Vo[] = [
  { at: 0.9, s: 0.0, e: 4.92, text: 'Between two visits, a patient with hypertension or diabetes is on her own.',
    fr: 'Entre deux consultations, une patiente hypertendue ou diabétique est livrée à elle-même.' },
  { at: 8.0, s: 5.69, e: 11.69, text: "With TeleMonitor, Esther joins her doctor's list with the code he gave her, in English or French.",
    fr: "Avec TeleMonitor, Esther rejoint la liste de son médecin grâce au code qu'il lui a donné, en anglais ou en français." },
  { at: 18.6, s: 12.42, e: 19.12, text: "At home, she enters two blood-pressure readings and her glucose, and can measure her pulse with the phone's camera.",
    fr: 'À la maison, elle saisit deux mesures de tension et sa glycémie, et peut mesurer son pouls avec la caméra du téléphone.' },
  { at: 31.5, s: 20.08, e: 25.55, text: 'Each reading is graded at once against guideline thresholds, even with no connection.',
    fr: 'Chaque mesure est classée aussitôt selon les seuils des recommandations, même sans connexion.' },
  { at: 37.6, s: 26.44, e: 29.76, text: 'This one is red, and the app tells her what to do.',
    fr: "Celle-ci est rouge, et l'application lui dit quoi faire." },
  { at: 42.5, s: 30.63, e: 37.73, text: 'A forecasting model then checks her recent readings: it can raise the level set by the rule, never lower it.',
    fr: "Un modèle prédictif analyse ensuite ses dernières mesures : il peut relever le niveau fixé par la règle, jamais l'abaisser." },
  { at: 53.4, s: 38.81, e: 41.43, text: 'Her history and trends are always at hand.',
    fr: 'Son historique et ses tendances sont toujours à portée de main.' },
  { at: 61.4, s: 41.86, e: 49.64, text: 'An automated assistant answers general health questions, without ever advising on medication, and points her to care nearby.',
    fr: 'Un assistant automatique répond aux questions générales de santé, sans jamais conseiller de médicament, et lui indique où se soigner à proximité.' },
  { at: 71.2, s: 50.21, e: 54.38, text: 'At the health centre, her doctor sees the red alerts first.',
    fr: "Au centre de santé, son médecin voit d'abord les alertes rouges." },
  { at: 77.2, s: 55.09, e: 58.9, text: 'His queue also flags patients who have stopped sending readings.',
    fr: "Sa file signale aussi les patients qui n'envoient plus de mesures." },
  { at: 84.5, s: 59.33, e: 63.33, text: "He opens Esther's record, confirms the alert, and writes to her.",
    fr: "Il ouvre le dossier d'Esther, confirme l'alerte et lui écrit." },
  { at: 97.6, s: 64.11, e: 67.88, text: 'Moments later, the message reaches her phone, and she replies.',
    fr: 'Quelques instants plus tard, le message arrive sur son téléphone, et elle répond.' },
  { at: 109.3, s: 68.66, e: 71.9, text: 'The app never prescribes: the clinician decides.',
    fr: "L'application ne prescrit jamais : c'est le clinicien qui décide." },
  { at: 115.2, s: 72.64, e: 78.45, text: 'TeleMonitor: home follow-up of hypertension and diabetes, between two visits.',
    fr: 'TeleMonitor : le suivi à domicile de l’hypertension et du diabète, entre deux consultations.' },
];

const HOME = 'At home · the patient';
const CENTRE = 'At the health centre · the clinician';

export const SCENES: Scene[] = [
  { kind: 'ai', from: 0, dur: 7, src: 'ai/shot1_take2.mp4', rate: 0.86, title: true },
  {
    kind: 'phone', from: 7, dur: 11, header: HOME, heading: 'She joins her doctor',
    beats: [
      { t: 0.3, text: 'English or French' },
      { t: 2.7, text: 'Name, e-mail, password' },
      { t: 4.7, text: 'The code from her doctor' },
      { t: 7.4, text: 'Linked to Dr. Paul Ndoumbe', color: C.green },
      { t: 8.7, text: 'Terms accepted, research optional' },
    ],
    clips: [
      { src: 'rec/p1.mp4', start: 4.0, dur: 2.5, rate: 2 },
      { src: 'rec/p1.mp4', start: 16.0, dur: 2.0, rate: 9 },
      { src: 'rec/p1.mp4', start: 45.0, dur: 3.75, rate: 1.6 },
      { src: 'rec/p1.mp4', start: 55.5, dur: 2.9, rate: 3.45 },
    ],
    zooms: [{ t: 0, s: 1, x: 0.5, y: 0.5 }, { t: 4.6, s: 1, x: 0.5, y: 0.45 }, { t: 5.2, s: 1.7, x: 0.5, y: 0.45 }, { t: 8.0, s: 1.7, x: 0.5, y: 0.45 }, { t: 8.6, s: 1, x: 0.5, y: 0.5 }],
  },
  {
    kind: 'phone', from: 18, dur: 13, header: HOME, heading: 'She logs a reading',
    beats: [
      { t: 0.3, text: 'Two blood-pressure readings' },
      { t: 3.2, text: 'Glucose, before a meal' },
      { t: 6.2, text: 'Pulse by the phone camera' },
      { t: 11.2, text: '73 bpm in 20 seconds', color: C.navy },
    ],
    clips: [
      { src: 'rec/p2a.mp4', start: 9.5, dur: 3.0, rate: 5 },
      { src: 'rec/p2a.mp4', start: 24.5, dur: 3.0, rate: 8.3 },
      { src: 'rec/p2b.mp4', start: 5.5, dur: 2.5, rate: 2.6 },
      { src: 'rec/p2b.mp4', start: 13.5, dur: 3.0, rate: 5.5 },
      { src: 'rec/p2c.mp4', start: 0.3, dur: 2.0 },
    ],
    zooms: [
      { t: 0, s: 1, x: 0.5, y: 0.5 }, { t: 0.6, s: 1.45, x: 0.5, y: 0.58 }, { t: 5.6, s: 1.45, x: 0.5, y: 0.5 },
      { t: 6.3, s: 1.35, x: 0.5, y: 0.36 }, { t: 12.5, s: 1.35, x: 0.5, y: 0.36 },
    ],
  },
  {
    kind: 'phone', from: 31, dur: 11, header: HOME, heading: 'Graded at once, even offline',
    beats: [
      { t: 0.3, text: 'Against her home targets' },
      { t: 2.0, text: 'Blood pressure: red', color: C.red },
      { t: 4.6, text: 'No connection needed' },
      { t: 7.2, text: 'What to do, right away' },
    ],
    clips: [
      { src: 'rec/p2c.mp4', start: 9.5, dur: 4.0, rate: 1.7 },
      { src: 'rec/p3.mp4', start: 2.0, dur: 7.2, rate: 1.4 },
    ],
    zooms: [
      { t: 0, s: 1, x: 0.5, y: 0.5 }, { t: 1.6, s: 1, x: 0.5, y: 0.62 }, { t: 2.3, s: 1.6, x: 0.5, y: 0.66 },
      { t: 3.9, s: 1.6, x: 0.5, y: 0.66 }, { t: 4.4, s: 1, x: 0.5, y: 0.5 }, { t: 7.0, s: 1, x: 0.5, y: 0.5 },
      { t: 7.6, s: 1.3, x: 0.5, y: 0.5 }, { t: 11, s: 1.3, x: 0.5, y: 0.5 },
    ],
    callouts: [{ t: 4.6, until: 7.0, text: 'Offline', x: 0.81, y: 0.016, dx: 230, dy: 60, color: C.grey }],
  },
  {
    kind: 'phone', from: 42, dur: 11, header: HOME, heading: 'Her level: rule, then model',
    beats: [
      { t: 0.3, text: 'Level: red', color: C.red },
      { t: 1.8, text: 'Checked with the risk model' },
      { t: 3.6, text: 'The model may raise it, never lower it' },
      { t: 7.6, text: 'Her 14-day trend' },
    ],
    clips: [{ src: 'rec/p4.mp4', start: 0.3, dur: 11.2 }],
    zooms: [
      { t: 0, s: 1, x: 0.5, y: 0.5 }, { t: 0.8, s: 1.55, x: 0.5, y: 0.3 }, { t: 6.0, s: 1.55, x: 0.5, y: 0.3 },
      { t: 6.8, s: 1, x: 0.5, y: 0.5 },
    ],
  },
  {
    kind: 'phone', from: 53, dur: 8, header: HOME, heading: 'Her history, her profile',
    beats: [
      { t: 0.3, text: 'Every reading, colour-coded' },
      { t: 3.9, text: 'Conditions and medicines' },
      { t: 5.6, text: 'Consent and language: her choice' },
    ],
    clips: [{ src: 'rec/p4.mp4', start: 12.0, dur: 8.1, rate: 2.6 }],
    zooms: [{ t: 0, s: 1, x: 0.5, y: 0.5 }, { t: 0.5, s: 1.35, x: 0.5, y: 0.33 }, { t: 3.4, s: 1.35, x: 0.5, y: 0.33 }, { t: 3.9, s: 1, x: 0.5, y: 0.5 }],
  },
  {
    kind: 'phone', from: 61, dur: 9.5, header: HOME, heading: 'Questions, and where to go',
    beats: [
      { t: 0.3, text: 'An automated assistant, labelled' },
      { t: 2.1, text: 'Never about medication' },
      { t: 4.9, text: 'Find care nearby' },
      { t: 7.2, text: 'Her location is never stored' },
    ],
    clips: [
      { src: 'rec/p5.mp4', start: 7.8, dur: 4.5 },
      { src: 'rec/p5b.mp4', start: 45.0, dur: 2.0 },
      { src: 'rec/p5b.mp4', start: 48.8, dur: 3.0, rate: 1.4 },
    ],
    zooms: [
      { t: 0, s: 1, x: 0.5, y: 0.5 }, { t: 0.5, s: 1.5, x: 0.5, y: 0.24 }, { t: 4.2, s: 1.5, x: 0.5, y: 0.24 },
      { t: 4.8, s: 1, x: 0.5, y: 0.5 }, { t: 6.8, s: 1, x: 0.5, y: 0.5 }, { t: 7.4, s: 1.35, x: 0.5, y: 0.62 }, { t: 9.5, s: 1.35, x: 0.5, y: 0.62 },
    ],
  },
  { kind: 'ai', from: 70.5, dur: 6, src: 'ai/shotA.mp4', chapter: CENTRE },
  {
    kind: 'web', from: 76.5, dur: 17, header: CENTRE, heading: 'Red alerts first',
    beats: [
      { t: 0.3, text: 'Red before yellow', color: C.red },
      { t: 3.3, text: 'Silence flagged: no readings', color: C.amber },
      { t: 6.6, text: 'Her record: risk tier 39 %' },
      { t: 11.5, text: 'Verdict: true alert, consultation' },
    ],
    clips: [
      { src: 'rec/c1.mp4', start: 0.3, dur: 6.3 },
      { src: 'rec/c1.mp4', start: 6.7, dur: 5.0, rate: 3 },
      { src: 'rec/c1.mp4', start: 26.3, dur: 5.7, rate: 4.4 },
    ],
    zooms: [
      { t: 0, s: 1, x: 0.5, y: 0.5 }, { t: 0.6, s: 1.75, x: 0.3, y: 0.17 }, { t: 2.9, s: 1.75, x: 0.3, y: 0.17 },
      { t: 3.5, s: 1.75, x: 0.3, y: 0.43 }, { t: 5.9, s: 1.75, x: 0.3, y: 0.43 }, { t: 6.5, s: 1, x: 0.5, y: 0.5 },
      { t: 8.6, s: 1, x: 0.5, y: 0.5 }, { t: 9.2, s: 1.6, x: 0.3, y: 0.55 }, { t: 11.0, s: 1.6, x: 0.3, y: 0.55 },
      { t: 11.6, s: 1, x: 0.5, y: 0.5 }, { t: 12.6, s: 1, x: 0.5, y: 0.5 }, { t: 13.2, s: 1.5, x: 0.5, y: 0.75 }, { t: 17, s: 1.5, x: 0.5, y: 0.75 },
    ],
  },
  {
    kind: 'split', from: 93.5, dur: 15, header: 'The loop closes', heading: 'He writes, she is told',
    web: [
      { src: 'rec/c2.mp4', start: 14.5, dur: 3.5, rate: 2 },
      { src: 'rec/c2.mp4', start: 21.5, dur: 11.5 },
    ],
    phone: [
      { src: 'rec/p6a.mp4', start: 100.0, dur: 4.0 },
      { src: 'rec/p6a.mp4', start: 120.2, dur: 4.0 },
      { src: 'rec/p6b.mp4', start: 8.3, dur: 1.7 },
      { src: 'rec/p6b.mp4', start: 14.0, dur: 2.5, rate: 6.5 },
      { src: 'rec/p6b.mp4', start: 33.3, dur: 2.8 },
    ],
    callouts: [
      { t: 3.9, until: 8.0, text: 'Sent', x: 0.84, y: 0.29, dx: -120, dy: 110, color: C.navy, on: 'web' },
      { t: 4.9, until: 8.0, text: 'Notification', x: 0.3, y: 0.07, dx: -300, dy: 90, color: C.green, on: 'phone' },
      { t: 12.6, text: 'Her reply', x: 0.72, y: 0.47, dx: -400, dy: 40, color: C.navy, on: 'phone' },
    ],
  },
  { kind: 'ai', from: 108.5, dur: 6, src: 'ai/shotB.mp4' },
  { kind: 'end', from: 114.5, dur: 7.5 },
];

export const DURATION = SCENES[SCENES.length - 1].from + SCENES[SCENES.length - 1].dur;
