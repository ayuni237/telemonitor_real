# TeleMonitor in use: the film (1 min 45 s)

Replaces the 64 s cut of 22 November. Goes on slide 23 of `TeleMonitor_defence_20min.pptx`
("6 · Assessment · Demonstration"), just before the conclusion.

Same rules as before: the app is shown **only in real recordings**; Higgsfield makes the human
scenes, the voice and the music; every AI scene carries "Illustration (AI-generated)".

## Narration (Helena, about 185 words)

| # | Line |
|---|---|
| L0 | Between two visits, a patient with hypertension or diabetes is on her own. |
| L1 | With TeleMonitor, Esther joins her doctor's list with the code he gave her, in English or French. |
| L2 | At home, she enters two blood-pressure readings and her glucose, and can measure her pulse with the phone's camera. |
| L3 | Each reading is graded at once against guideline thresholds, even with no connection. This one is red, and the app tells her what to do. |
| L4 | A forecasting model then checks her recent readings: it can raise the level set by the rule, never lower it. Her history and trends are always at hand. |
| L5 | An automated assistant answers general health questions, without ever advising on medication, and points her to care nearby. |
| L6 | At the health centre, her doctor sees the red alerts first. |
| L7 | His queue also flags patients who have stopped sending readings. He opens Esther's record, confirms the alert, and writes to her. |
| L8 | Moments later, the message reaches her phone, and she replies. |
| L9 | The app never prescribes: the clinician decides. TeleMonitor: home follow-up of hypertension and diabetes, between two visits. |

## Storyboard

| Time | Picture | Source | On screen |
|---|---|---|---|
| 0:00-0:07 | Esther at home in the evening, fastening the cuff | AI, `ai/shot1_take2.mp4` (kept) | "TeleMonitor" fades in; AI label |
| 0:07-0:16 | Sign-up: English/French, name, consent boxes, code DLA7K2, "Dr Paul Ndoumbe" appears as verified | take P1 | chapter card "At home · the patient"; callout on the verified doctor |
| 0:16-0:30 | Log a reading: 186/110 then 182/108, glucose 6.1 before a meal, pulse with the camera (fingertip, 20 s sped up) | take P2 | zoom on the two readings, then on the camera pulse |
| 0:30-0:41 | Airplane mode on; Save; "This reading is out of range" | take P3 | callout "Offline"; red dot |
| 0:41-0:55 | Home: Red level, "Checked with your readings and the risk model", evolution, 14-day trend; History tab with coloured readings | take P4 | callout "Model: may raise, never lower" |
| 0:55-1:03 | Assistant: a question on diet, the answer under its "automated" banner; Find care nearby (in-app screen only) | take P5 | callout "Automated, never about medication" |
| 1:03-1:08 | Doctor at his desk in a health centre, opening the laptop (screen away) | AI, new shot A | chapter card "At the health centre · the clinician"; AI label |
| 1:08-1:24 | Web app, light theme, in a laptop frame: queue red first, Joseph yellow, Brigitte "no readings"; Esther's record (risk tier, trend); verdict and comment sent | take C1 | zooms on each row; callouts "Red before yellow", "No readings for 5 days" |
| 1:24-1:34 | Split screen: he presses send / her locked phone shows "New message from your clinician"; she opens it and replies | takes C2 + P6, recorded together | timer-free, side by side |
| 1:34-1:41 | Esther at home reads her phone, relieved (screen away) | AI, new shot B | AI label |
| 1:41-1:45 | End card | built | TeleMonitor, byline, repository, logos |

Captions: the narration is burnt in as subtitles at the bottom (the room's speakers may be poor).
Music: a calm instrumental bed (ElevenLabs Music), lowered under the voice, up on the end card.

## Production

- Editing in Remotion (React video, rendered on this PC): device frames, eased zooms, callouts,
  chapter cards, captions, split screen. Project in `film/`.
- Recordings: one session of about 45 minutes. Phone takes are driven through adb as before
  (show_touches on, demo status bar). The web takes are recorded from a Chrome window in light
  theme at a readable zoom; the PC must not show anything else.
- Sign-up continuity: P1 uses a throwaway account with Esther's name, deleted right after; her
  seeded account (two weeks of history) carries the rest.

## Recording takes

| Take | Device | Content |
|---|---|---|
| P1 | phone | log out; language choice; sign up as "Esther Mbella" with code DLA7K2 (verified name shows), consent, account created |
| P2 | phone | as Esther (seeded): Log a reading, two BP readings, glucose before a meal, camera pulse |
| P3 | phone | airplane mode on, Save, red dialog, "I understand" |
| P4 | phone | airplane mode off; Home scroll (level, model line, evolution, trend); History tab |
| P5 | phone | Assistant: one question, answer; Find care nearby screen (no map) |
| C1 | PC | clinician web: queue, Esther's record, verdict + comment |
| C2 + P6 | PC + phone | clinician sends the message while the phone is locked; notification; open; reply |

## Recording session of 23 November 2026 (done)

Seeded at 11:18-11:23 (Douala); the app's greeting is "Good morning", so the demo status-bar
clock shows the real time. Phone takes driven by `record_phone.py`, web takes recorded headless
by `record_web.py` (Chrome via Playwright, frames from the browser, light theme, 2560 x 1440).

| Take | File | Content (useful part) |
|---|---|---|
| P1 | rec/p1.mp4 | French/English 4-10 s, form 12-42 s, code 44-51 s ("You will be linked to Dr. Paul Ndoumbe" from 49.5 s), terms 56 s, account created 64 s |
| P2 | rec/p2a.mp4, p2b.mp4, p2c.mp4 | typing 10-49 s; camera: finger 6-12 s, measuring with pulse wave 14-32 s (first try failed, the retry gave 73 bpm off camera); p2c: 73 bpm 0-3 s, "Pulse by camera: 73 bpm", context, grade BP red / glucose green at 15 s |
| P3 | rec/p3.mp4 | airplane icon, Save, "This reading is out of range" from 8.5 s |
| P4 | rec/p4.mp4 | home red + model line + trend 0-12 s, History 12-22 s, Profile 22-33 s |
| P5 | rec/p5.mp4, p5b.mp4 | assistant welcome 8-13 s (the live answer failed, see below); "Find care near you" 49-53 s |
| C1 | rec/c1.mp4 | queue (6): Esther red first, record with risk tier 39 %, verdict True alert + Consultation, closed |
| C2 | rec/c2.mp4 | Patients, Esther, "Message patient", message sent at 21.2 s (12:07) |
| P6 | rec/p6a.mp4, p6b.mp4 | Stopwatch in front (neutral), pop-up "New message from your clinician" 120.5-126 s; reply sent 34 s (12:11) |

Edit: Remotion project `film/` (timeline in `film/src/timeline.ts`), 2 min 02 s, English voice
with French subtitles, on-screen explanation lines that build up with the action, end card on
an AI-generated background (`ai/endbg_b.mp4`).

Found while recording:
- **Sign-up failed when the keyboard capitalised the e-mail** (rules compare the saved e-mail
  with the token, which Firebase keeps in lower case). Fixed in `auth_service.dart` (the saved
  e-mail is the one Firebase holds); release APK rebuilt and installed. Not committed.
- Sign-in with a capitalised e-mail failed once ("unknown"); not investigated.
- **The health assistant fails in the release build**: "Firebase App Check token is invalid".
  The app never activates App Check while the project enforces it for the AI service. The film
  shows the assistant's own welcome message (no medication advice) instead of a live answer.
- The seed wrote the clinician's name as `clinicianName`; the app reads `name` (sign-up showed
  "Your clinician"). Fixed in `seed_demo.py`.
- Re-seeding left stale "No readings received" alerts in the clinician's queue (6 items); the
  film zooms on the top rows.
- The verdict's "Send the comment to the patient" box was not ticked by the script, so the
  message to Esther was sent from her record's chat (take C2), which matches the narration.
