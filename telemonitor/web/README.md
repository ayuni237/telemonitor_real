# Step 6 — patient profile is real (and editable)

## What changes

`profile_screen.dart` was showing hardcoded demo data — "Nsame Rodrick,
34, O+, Amlodipine 5mg" — to every patient regardless of who was signed
in. It now reads the patient's own Firestore document, and they can
edit it themselves instead of you doing it in the console.

## Files

**New:**
```
lib/services/profile_service.dart
lib/screens/patient/edit_profile_screen.dart
```

**Replace:**
```
lib/models/app_user.dart                    — adds bloodType
lib/screens/patient/profile_screen.dart     — real data + edit button
firestore.rules                             — allows self-edit, safely
```

## The rules change is the important part

Profiles were `allow write: if false` — nothing could edit them. That
now becomes:

```
allow update: if isSelf(userId)
              && !request.resource.data
                   .diff(resource.data)
                   .affectedKeys()
                   .hasAny(['role', 'assignedClinicianId', 'email']);
allow create, delete: if false;
```

The `diff().affectedKeys()` check is what makes this safe. A patient can
change their name, age, conditions, medications — anything descriptive.
But the moment an update touches `role`, `assignedClinicianId` or
`email`, the whole write is rejected. So a patient cannot promote
themselves to clinician, attach themselves to another clinician's
roster, or change the address their account is identified by.

`ProfileService.updateOwnProfile()` simply doesn't accept those fields,
but that's convenience, not security — the enforcement is server-side,
where it belongs.

## What the patient sees

- Header with their real name, age, sex, blood type.
- Conditions, medications, physical info, contacts — each card appears
  only if there's something to show, so an empty profile isn't a wall
  of dashes.
- If nothing clinical is filled in, an amber "Complete your profile"
  prompt explaining that these details help their clinician interpret
  readings. Empty conditions should read as *not documented*, never as
  *no conditions*.
- An "Account" card showing email and whether a clinician is assigned —
  visible but not editable, so the restriction is obvious rather than
  mysterious.

Conditions and medications are entered one per line, which is easier on
a phone than comma-separated.

## Two things I removed

- **Delete Account** — it did nothing, and implementing it properly
  means deciding what happens to a patient's readings and message
  history, which is a real clinical-records question, not a button.
- **Notification toggles** — they controlled nothing (there's no FCM
  yet) and didn't persist. A switch that appears to configure something
  it can't is worse than no switch. They belong with push notifications.

## How to verify

`flutter analyze`, then:

1. Publish the new `firestore.rules`.
2. Patient on the phone → Profile. Should show *their* account, not
   "Nsame Rodrick".
3. Tap the pencil → fill in age, conditions, medications → Save.
4. Profile updates immediately.
5. **Clinician in Chrome** → open that patient → the profile card now
   shows what the patient just entered. That's the loop closing.

**Then test the restriction:** in the Firestore console, note the
patient's `role`. Nothing in the app can change it — that's the point.
If you want to prove the rule fires, temporarily add `'role': 'clinician'`
to the map in `updateOwnProfile()` and confirm the save fails with a
permission error. Remove it afterwards.

## Possible one-line fix

`edit_profile_screen.dart` uses `DropdownButtonFormField(initialValue:)`.
If `flutter analyze` complains that the parameter doesn't exist, your
Flutter version still uses the older name — change both occurrences of
`initialValue:` to `value:` and it'll be fine.
