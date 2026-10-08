# Step 13 — dark mode (part 1: infrastructure)

## Honest scope note

This step delivers the theme system and makes it work. It does **not**
finish the job: your screens hardcode colours like
`const Color(0xFF1A3C6E)` and `Colors.white` directly, so each one needs
converting to ask for colours by role instead.

After this step you will have a working toggle, correct app bars, correct
page backgrounds, correct bottom navigation and correct dialogs
everywhere — because those come from `ThemeData`. But **cards inside your
screens will still be white in dark mode** until each screen is
converted. Part 2 does that, screen by screen.

I have split it this way deliberately: infrastructure first, so you can
see it working and decide whether the conversion is worth your remaining
time.

## 1. Add the dependency

```
flutter pub add shared_preferences
```

Used to remember the choice across restarts.

## 2. Files

**New:**
```
lib/theme/app_theme.dart
lib/theme/theme_controller.dart
lib/widgets/theme_selector_card.dart
```

**Replace:**
```
lib/main.dart
```

## 3. Add the control to the profile screen

In `lib/screens/patient/profile_screen.dart`, add the import:

```dart
import '../../widgets/theme_selector_card.dart';
```

and place this in the column of cards — just above the sign-out button is
a natural spot:

```dart
const ThemeSelectorCard(),
const SizedBox(height: 14),
```

## 4. Test

`flutter run`, go to Profile, tap **Dark**. App bars, page backgrounds
and the bottom bar switch immediately. Close the app fully and reopen —
the choice persists.

`Auto` follows the device setting, which is what most people expect as a
default.

---

# How the colour system works

Screens should never name a raw hex value again. They ask for the colour
by its **role**:

| Instead of | Use |
|---|---|
| `const Color(0xFF1A3C6E)` as a heading/label colour | `AppColors.primaryText(context)` |
| `const Color(0xFF1A3C6E)` as a button/appbar fill | `AppColors.primary` |
| `Colors.white` as a card background | `AppColors.card(context)` |
| `const Color(0xFFF5F7FA)` as page background | `AppColors.background(context)` |
| `const Color(0xFFF5F7FA)` as an input fill | `AppColors.field(context)` |
| `const Color(0xFFEEF3FA)` | `AppColors.tint(context)` |
| `Colors.grey.withValues(alpha: 0.15)` borders | `AppColors.border(context)` |
| `Colors.grey[600]` | `AppColors.textSecondary(context)` |
| `Colors.grey[400]` | `AppColors.textMuted(context)` |
| `const Color(0xFF2C2C2A)` body text | `AppColors.textPrimary(context)` |
| `const Color(0xFFA32D2D)` | `AppColors.dangerText(context)` |
| `const Color(0xFFFCEBEB)` | `AppColors.dangerBg(context)` |
| `const Color(0xFF854F0B)` | `AppColors.warningText(context)` |
| `const Color(0xFFFAEEDA)` | `AppColors.warningBg(context)` |
| `const Color(0xFF3B6D11)` | `AppColors.successText(context)` |
| `const Color(0xFFEAF3DE)` | `AppColors.successBg(context)` |

## Why blind find-and-replace will break things

`Colors.white` appears in two different roles:

```dart
// A card background — must become dark in dark mode
decoration: BoxDecoration(color: Colors.white, ...)

// Text on a navy app bar — must STAY white
style: TextStyle(color: Colors.white)
```

A project-wide replace cannot tell them apart and would turn your app bar
text invisible. The same applies to `const Color(0xFF1A3C6E)`, which is
both a fill and a text colour.

This is why part 2 is done screen by screen rather than by script.

## Two decisions worth knowing

**App bars stay navy in both modes.** The brand stays recognisable, and
white foreground text remains correct everywhere without each screen
reasoning about it.

**Clinical status colours keep their hue.** Red still means danger in
dark mode; only the background panels darken. The mapping from colour to
clinical meaning must not shift between themes — a clinician glancing at
a red chip should read it the same way regardless of the device setting.

## Part 2 — screens to convert

In rough order of how visible they are:

1. `patient_dashboard.dart`, `login_screen.dart`, `signup_screen.dart`
2. `clinician_home_screen.dart`, `patient_detail_screen.dart`
3. `log_reading_screen.dart`, `history_screen.dart`, `profile_screen.dart`
4. `chat_screen.dart`, `chat_thread_view.dart`, `patient_chat_screen.dart`
5. `risk_card.dart`, `enrolment_code_card.dart`, `clinician_link_card.dart`,
   `edit_profile_screen.dart`, `connect_clinician_screen.dart`

Tell me which batch to do next and I will convert them in full.
