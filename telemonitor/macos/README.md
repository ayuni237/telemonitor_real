# Step 14 — dark mode part 2, batch 1

## Files

**Replace:**
```
lib/screens/patient/profile_screen.dart
lib/screens/patient/edit_profile_screen.dart
```

No manual edits. `ThemeSelectorCard` is already wired into the profile
screen, so the Light / Dark / Auto control appears without you touching
anything.

## What was wrong in Edit Profile

The field backgrounds were hardcoded to `0xFFF5F7FA` — a light grey. But
once a dark `ThemeData` was active, the *text* colour inside those fields
came from the theme and turned light. Light text on a light fill is what
made "Ayuni Rodrick", "24", "162" almost invisible.

Two fixes, both needed:

1. The fill now uses `AppColors.field(context)`, which darkens.
2. Each `TextField` now sets an explicit `style:` with
   `AppColors.textPrimary(context)`. Without this the field inherits the
   theme default, which is exactly how the mismatch arose.

That second point is the one to carry into the remaining screens: **any
`TextField` with a hardcoded `fillColor` needs an explicit text
`style:`**, or it will break the same way.

## Also fixed here

- The profile header keeps its navy background in both themes, matching
  the app bar — so the white avatar and name text stay correct.
- Height and weight now display with units (`162 cm`, `78 kg`) rather
  than bare numbers.
- Status colours adapt: the amber "Complete your profile" prompt now uses
  a dark amber panel instead of a pale one that would glare.

## Test

1. `flutter run`, go to **Profile**. The **Appearance** card is there
   with Light / Dark / Auto.
2. Tap **Dark**. The page, cards and text all switch.
3. Tap the pencil to open **Edit Profile** — the field values should now
   be clearly readable.
4. Tap **Light** and confirm nothing looks wrong in light mode either.
5. Force-close and reopen — the choice persists.

## Still to convert

Nine files remain hardcoded. In dark mode these will still show white
cards:

- `patient_dashboard.dart`, `log_reading_screen.dart`,
  `history_screen.dart`, `chat_screen.dart`
- `clinician_home_screen.dart`, `patient_detail_screen.dart`,
  `patient_chat_screen.dart`
- `login_screen.dart`, `signup_screen.dart`,
  `connect_clinician_screen.dart`
- `risk_card.dart`, `enrolment_code_card.dart`,
  `clinician_link_card.dart`, `chat_thread_view.dart`

Say the word and I will do the next batch — I would take
`patient_dashboard.dart` plus `risk_card.dart` next, since that is the
screen you and a jury will look at most.
