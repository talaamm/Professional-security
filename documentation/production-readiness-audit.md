# Production Readiness Audit — Professional Security App

Date: 2026-09-07
Scope: Flutter app (`professional_security_app/`) + Supabase backend (`db_files/`), ahead of Google Play + Apple App Store submission.
**No code, config, or store artifacts were changed as part of this audit. No deployment, upload, or Supabase data changes were made.**

Legend: 🔴 BLOCKER · 🟠 IMPORTANT · 🟡 RECOMMENDED · 🟢 READY

---

## 1. SECURITY

| Finding | Status |
| --- | --- |
| Supabase URL/key location: `lib/config/env.dart` — real values, gitignored (`.gitignore` line 48: `/lib/config/env.dart`). Template committed as `lib/config/env.example.dart`. `git ls-files` confirms `env.dart` was never tracked, and `git log --all -p` finds no historical commit of it. | 🟢 |
| Key type in `env.dart`: `sb_publishable_...` — this is Supabase's new **publishable** key format (the modern equivalent of the legacy anon key). Correct key type for a client app. No `service_role` / `sb_secret_...` key found anywhere in `lib/`, `db_files/`, or git history. | 🟢 |
| Auth flow (`lib/services/auth_service.dart`, `lib/widgets/auth_gate.dart`): Employee ID → synthetic `{employee_id}@internal.app` → `signInWithPassword`. Role is never read from client state for authorization — every privileged Postgres function re-derives the caller's role from `auth.uid()` server-side. Password is never logged or echoed back to the UI beyond generic error text. Deactivated accounts are force-signed-out on next app open. | 🟢 |
| RLS: enabled on all 6 sensitive tables (`profiles`, `devices`, `workplaces`, `work_sessions`, `audit_logs`, `issue_reports`). Pattern is consistently `*_select_own` (row's `employee_id` = caller) + `*_select_admin` (role check), with **no client-facing INSERT/UPDATE/DELETE policy** on `work_sessions`, `devices`, or `audit_logs` — all writes must go through `SECURITY DEFINER` RPCs. `workplaces` is the sole exception (admins get direct INSERT/UPDATE via RLS, by design, no DELETE — deactivate-only). | 🟢 |
| `SECURITY DEFINER` functions (15 files in `db_files/`) — spot-checked `admin_set_employee_status`, `start_work_session`, `admin_verify_session`: each independently resolves the caller's role from `profiles` via `auth.uid()` and raises an exception if not admin, rather than trusting a client-supplied role/flag. GPS-based session start/end also **recomputes distance server-side** from submitted coordinates rather than trusting a client-picked workplace — this correctly defeats a tampered/faked `workplace_id`. | 🟢 |
| Debug/sensitive logging: no `print(`/`debugPrint(` calls anywhere in `lib/`. | 🟢 |
| Dev-only code / hardcoded test accounts: none found in `lib/`. (Test employee IDs only appear in `db_files/*.sql` seed/testing docs, which is expected and doesn't ship in the app.) | 🟢 |
| No RLS/authorization gap identified in the reviewed policies or functions. | 🟢 |

**Section verdict: no blockers.** This is the strongest section of the audit — the "server never trusts the client" discipline (role checks, GPS recomputation, audit logging on every admin write) is applied consistently.

---

## 2. ENVIRONMENT CONFIGURATION

| Finding | Status |
| --- | --- |
| **Single Supabase project.** `env.dart` points at one project (`wfytzwvohqaxyeebwhxa.supabase.co`) — the same project has been used for all development/testing per `implemented-features.txt`. There is currently no separation between a development/test Supabase project and a production one. | 🟠 |
| `.gitignore` correctly excludes `lib/config/env.dart`, Android build dirs, and IDE files. No root `.gitignore` — only `professional_security_app/.gitignore` exists, which is sufficient since that's the actual Flutter project root. | 🟢 |
| No Android `key.properties`/keystore or iOS signing secrets exist yet, so nothing to leak there (see §3/§4 — signing isn't configured at all yet). | 🟢 |

**Recommended (not automatically actioned) setup, per your instruction not to create a new Supabase project automatically:**

1. Create a **second, separate Supabase project** for production (separate URL, separate anon key, separate `auth.users`/`profiles` data — real employees, not test accounts).
2. Re-run the full migration history (`db_files/*.sql`, in order) against the new production project.
3. Keep **one Flutter build config pointed at dev, one at prod** — cleanest is `--dart-define` flavors or two `env.dart`-equivalent files selected at build time, rather than hand-editing `env.dart` before each release build (manual editing is error-prone: it's easy to accidentally ship a release build pointed at the dev database, or vice versa).
4. Decide who has dashboard/service_role access to the production project (should be far fewer people than have access to dev).

---

## 3. ANDROID RELEASE READINESS

| Item | Found | Status |
| --- | --- | --- |
| `applicationId` | `com.example.professional_security_app` (`android/app/build.gradle.kts:24`) — Flutter's default placeholder. **Google Play rejects `com.example.*` application IDs.** | 🔴 BLOCKER |
| Release signing | `buildTypes.release { signingConfig = signingConfigs.getByName("debug") }` (`build.gradle.kts:33-38`, with the file's own `// TODO: Add your own signing config`) — release builds are currently signed with the **debug key**. Play Console will not accept an app bundle signed with a debug cert; also Play App Signing enrollment is required. | 🔴 BLOCKER |
| Keystore/`key.properties` | Neither exists yet anywhere in the repo or git history (confirmed via filesystem search and `git log --all --full-history`). Nothing to leak — but nothing configured either. | 🔴 BLOCKER (needed to fix the above) |
| App name (`android:label`) | `"professional_security_app"` (raw package-style string, `AndroidManifest.xml:6`) — not a user-facing display name. iOS already has a proper display name (`"Professional Security App"`); Android should match. | 🟠 |
| Permissions | `INTERNET`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` only. No background-location permission requested, consistent with the app's "when in use" GPS check-in/out model — minimal and correctly scoped. | 🟢 |
| `minSdk`/`targetSdk`/`versionCode`/`versionName`/`compileSdk` | All pulled from Flutter tooling defaults (`flutter.minSdkVersion` etc.), not hardcoded/overridden. Current Flutter is 3.47.2 (stable, Aug 2026), so these will resolve to a current, Play-compliant `targetSdk` at build time — nothing to fix here as long as you build with an up-to-date Flutter SDK at release time. | 🟢 |
| `versionName`/`versionCode` source | `pubspec.yaml: version: 1.0.0+1` → versionName `1.0.0`, versionCode `1`. Fine as a first release; remember to bump both on every subsequent Play upload (Play rejects a re-upload with the same versionCode). | 🟢 |
| Launcher icons | `android/app/src/main/res/mipmap-*/ic_launcher.png` — file sizes (442–1443 bytes) and a shared timestamp (May 15) match the **stock default Flutter icon**, not the company logo already used on the login screen (`assets/images/logo.png`, added later, Sept 1). Google Play flags/rejects apps using the default Flutter template icon. | 🟠 |
| Debug config leaking into release | No separate `android/app/src/debug/AndroidManifest.xml` exists with extra permissions; no `android:debuggable`/`usesCleartextTraffic` flags set anywhere (so they default safely to `false`/HTTPS-only in release). | 🟢 |

**Must complete before Google Play submission:**

1. Change `applicationId` to a real reverse-domain ID (e.g. `com.yourcompany.professionalsecurity`) — **do this once, early**, since changing it later means Play treats it as a new app.
2. Generate a release keystore, create `android/key.properties` (gitignored), and wire a real `signingConfigs.release` block.
3. Replace the launcher icon set with the company logo.
4. Set a proper `android:label`.

---

## 4. IOS RELEASE READINESS

| Item | Found | Status |
| --- | --- | --- |
| Bundle Identifier | `com.example.professionalSecurityApp` (`project.pbxproj`, all 3 build configs) — same placeholder problem as Android. Apple also rejects/flags `com.example.*` at submission. | 🔴 BLOCKER |
| App name | `CFBundleDisplayName` = `"Professional Security App"` — already a proper branded name. `CFBundleName` (internal) = `professional_security_app`, which is fine (not user-facing). | 🟢 |
| Version / build number | `CFBundleShortVersionString` = `$(FLUTTER_BUILD_NAME)`, `CFBundleVersion` = `$(FLUTTER_BUILD_NUMBER)` — both correctly sourced from `pubspec.yaml`'s `version: 1.0.0+1`, consistent with Android. | 🟢 |
| Location permission description | `NSLocationWhenInUseUsageDescription` = *"We use your location to verify you're at an approved workplace when you start or finish a work session."* — present and clearly explains the actual purpose (matches the GPS check-in/out feature). No `NSLocationAlwaysAndWhenInUseUsageDescription` present, which is correct since the app never requests background/always location (matches the Android permission set — no `ACCESS_BACKGROUND_LOCATION`). | 🟢 |
| Other permission descriptions | No camera/photo/contacts/microphone usage-description keys present — consistent with the app not using any of those. | 🟢 |
| App icons | `Assets.xcassets/AppIcon.appiconset` — all sizes present, but same May 15 batch-generation pattern as the Android icons; almost certainly still the default Flutter icon, not the company logo. | 🟠 |
| Signing | `CODE_SIGN_IDENTITY[sdk=iphoneos*] = "iPhone Developer"` (generic, unassigned), no `DEVELOPMENT_TEAM` set anywhere in `project.pbxproj`. Not a code defect — it requires an actual Apple Developer Program account/team ($99/year) and can only really be finished on a Mac with Xcode — but exactly like the missing Android keystore, no signed build can be produced until this is done, so it's treated as a blocker for symmetry with §3. | 🔴 BLOCKER |
| `IPHONEOS_DEPLOYMENT_TARGET` | `13.0` across all configs — acceptable (iOS 13 released 2019; still commonly the Flutter template default), though you may want to raise it if you don't need to support very old devices, since a higher minimum simplifies testing. | 🟡 |
| Certs/provisioning profiles committed | No `.p12`/`.p8`/`.mobileprovision`/`.cer` files found anywhere under `ios/`. Nothing to leak. | 🟢 |

**Must complete before App Store submission:**

1. Change the bundle identifier off `com.example.*` — pick it to correlate with (but doesn't have to exactly match) the final Android `applicationId`.
2. Replace app icons with the company logo.
3. On a Mac: enroll in the Apple Developer Program, set the Team/signing identity in Xcode, and do a real archive build.

---

## 5. PRIVACY — Data Inventory (factual, from schema + code, nothing guessed)

**Identity / employment data** (`profiles` table): `employee_id`, `full_name`, `role`, `status` (active/inactive), `created_at`/`updated_at`/`deactivated_at`. This is standard employment identity data — no health, financial, or other special-category data collected.

**Authentication data**: handled by Supabase Auth. No real email is collected — the app uses a synthetic `{employee_id}@internal.app` address purely as Supabase Auth's required identifier; it's never used to send mail. Passwords are hashed by Supabase Auth and never visible to/stored by the app itself.

**Location data**: `work_sessions.start_latitude`/`start_longitude` and (per `phase4-end-session.sql`) equivalent end-side columns — **precise GPS coordinates**, captured only at the moment an employee starts or ends a work session (not continuous/background tracking), and always linked to that employee's `employee_id`. Retained indefinitely — the schema and `requirements-and-architecture_V1.md` (§ "Users are not physically deleted from the database", "Deleting/deactivating a workplace or user must not delete historical sessions") confirm a deliberate **soft-delete-only** design: no automatic deletion or anonymization of location/session history exists anywhere in the schema or app.

**Work session timestamps**: `started_at`/`ended_at`, plus verification metadata (`start_verification`, `end_verification`, `verified_by`). Same indefinite-retention policy as above.

**Device information**: yes — a `devices` table exists, storing `device_identifier`, `platform`, `device_name`, `app_version`, `registered_at`, `last_seen_at`, `status`, linked to `employee_id`.

**Issue reports**: free-text messages employees submit to admins (`issue_reports` table), up to 50 characters, linked to `employee_id`.

**Audit trail**: every admin action (verify/edit/delete a session, change employee status, resolve an issue, reset a password) is written to `audit_logs` with the acting admin's `employee_id`, old/new data, and an optional reason — this itself is personal data about admins' actions.

**Third-party data sharing**: none beyond Supabase itself (the app's backend processor). `pubspec.yaml` dependencies are `supabase_flutter`, `geolocator`, `shared_preferences`, `pdf`, `printing`, `cupertino_icons` — **no analytics, crash-reporting, or ad SDK** (no Firebase Analytics, Crashlytics, Sentry, etc.) is bundled, so no data is collected/sent to any party beyond your own Supabase project.

**Data deletion**: there is currently **no in-app or admin-facing way to permanently delete an employee's data** — accounts are deactivated, never deleted, by explicit design. Both Google Play's Data Safety form and Apple's App Privacy form ask whether users can request account/data deletion; as built today, the honest answer is "no, data is retained indefinitely / only deactivated." If this needs to change (e.g. to support a deletion request from a departing employee, per data-protection law in your jurisdiction), that's a scope decision for you — not something to guess at here.

**What you'll need to fill in the store forms, based on the above:**

- Data types collected: Identity info (name, employee ID), precise location, app activity/usage (session timestamps), device identifiers.
- Purpose: all data collection is for core app functionality (work-session verification), not analytics/advertising.
- Data sold to third parties: No.
- Data shared with third parties: Only your Supabase processor (infrastructure, not a "third party" in the marketing sense — but Supabase's identity/hosting region should still be disclosed if the forms ask).
- Data retention/deletion: Retained indefinitely; no self-service deletion currently exists (see above — you'll need to decide the honest answer here before submitting).
- Encryption in transit: Yes (Supabase enforces HTTPS/TLS).

---

## 6. RELEASE QUALITY

| Check | Result |
| --- | --- |
| `flutter analyze` | **No issues found** (clean run, 829s — long only because it was a cold first analysis). | 🟢 |
| `flutter test` | **FAILED.** The only test file, `test/widget_test.dart`, is Flutter's **unmodified default counter-app boilerplate** — it pumps `MyApp()` and expects to find text `"0"`, which doesn't exist in this app. It also throws before that: `Supabase.instance` is accessed by `AuthService`/`AuthGate` inside `MyApp`, but the test never calls `Supabase.initialize()`, so it crashes with `You must initialize the supabase instance before calling Supabase.instance`. **Effectively there is zero real test coverage** — this one test isn't a weakened check, it's leftover template code that has never been touched since `flutter create`. Neither store checks for test coverage, so this does not block submission — it's a code-quality/CI-hygiene gap, not a release blocker. | 🟠 |
| `print(`/`debugPrint(` in `lib/` | None found. | 🟢 |
| `TODO`/`FIXME`/`HACK` in `lib/` | None found. (The only `TODO`s in the whole project are Flutter's own template comments in `android/app/build.gradle.kts`, already covered in §3.) | 🟢 |
| Loading states | Spot-checked Login, Home (via `WorkSessionPanel`), History — all three implement an explicit `_isLoading`/spinner pattern before content renders. | 🟢 |
| Empty states | History screen explicitly renders a "no sessions this month" message (`AppStrings.t('history_empty')`) when the list is empty, rather than a blank screen. | 🟢 |
| Outdated packages | `flutter pub outdated`: all **direct** and **dev** dependencies are already at their latest resolvable versions. Only a handful of *transitive* dependencies are pinned slightly behind latest (`archive`, `clock`, `material_color_utilities`, `platform`, `qr`, `stack_trace`, `test_api`) — none of these are security-relevant for this app's usage, purely minor version lag. | 🟢 |

**Section verdict: the only real problem is the missing/broken test suite.** Code quality itself (no stray prints, no TODOs, consistent loading/empty-state handling) is in good shape for a small team's app — matches the "beginner-friendly, no overengineering" instruction in `CLAUDE.md` while still handling the basics correctly.

---

## 7. BUILD READINESS

- **Android App Bundle (.aab):** Cannot currently produce a *submittable* one — `flutter build appbundle --release` will technically succeed (the debug-signed release build type will compile), but the output would be signed with the debug key and carry the `com.example.*` application ID, both of which Play Console will reject on upload. Blocked on §3 items 1–2.
- **iOS release build:** Cannot currently produce a submittable `.ipa` — no Apple Developer Team/signing identity is configured, and this specifically requires a Mac + Xcode (this environment is Windows, so an actual iOS build couldn't be attempted here even for verification). Blocked on §4 item 3, and requires Mac hardware for the actual build step.
- No signing identities were changed or created during this audit, per your instruction.

---

## 8. SUMMARY BY SEVERITY

### 🔴 BLOCKER — must fix before release

1. Android `applicationId` is still `com.example.professional_security_app`.
2. Android release build is signed with the **debug** keystore — no real signing config exists.
3. iOS bundle identifier is still `com.example.professionalSecurityApp`.
4. Apple Developer Team/signing identity not configured — no signed iOS build can be produced at all until this is set up (needs a Mac + a paid Apple Developer Program account).

### 🟠 IMPORTANT — should fix before release

5. Single shared Supabase project for dev and prod — no environment separation yet.
2. Android/iOS launcher icons are still the default Flutter icon, not the company logo already used elsewhere in the app.
3. Android `android:label` is the raw package string, not a proper display name (iOS already has one — Android should match).
4. No in-app/admin path to permanently delete an employee's data — confirm this is an acceptable answer for the Play/Apple privacy forms, or decide if it needs to be built.
5. `flutter test` fails — the sole test is unmodified template boilerplate unrelated to this app; there is no real automated test coverage. Doesn't block store submission, but leaves zero regression protection for a feature-complete app.

### 🟡 RECOMMENDED — production improvement
 1. `IPHONEOS_DEPLOYMENT_TARGET` is 13.0 — consider raising if you don't need to support very old devices.
 2. A handful of transitive dependencies are slightly behind latest (non-security, cosmetic).

### 🟢 READY — already correctly configured

- No hardcoded secrets, no `service_role` key exposure, `env.dart` properly gitignored and never committed.
- RLS enabled and correctly scoped on every sensitive table; all writes gated through role-checked `SECURITY DEFINER` functions; GPS distance is always recomputed server-side, never trusted from the client.
- No debug prints, no leftover TODOs, no dev-only code paths in `lib/`.
- Android permissions and iOS usage-description text are minimal, accurate, and consistent with each other (location-when-in-use only).
- `flutter analyze` clean; loading/empty states present on every screen spot-checked.
- No third-party analytics/ad SDKs bundled — data collection is limited to what the app actually needs.
- Version numbering (`1.0.0+1`) is consistently sourced from `pubspec.yaml` across both platforms.

---

## Proposed production-preparation plan (small, sequential — not started)

1. **Rename application IDs** (Android `applicationId` + iOS bundle identifier) to your real reverse-domain ID — do this first since it can't be changed after the first store upload.
2. **Set up Android release signing**: generate a keystore, add `android/key.properties` (gitignored), wire `signingConfigs.release` in `build.gradle.kts`.
3. **Replace launcher icons** on both platforms with the company logo.
4. **Set a real Android app label**.
5. **Write a minimal real test** (or two) covering something concrete — e.g. the employee-ID/9-digit validator, or a widget test that properly initializes a fake Supabase client — so `flutter test` reflects actual app behavior instead of failing on template code. (Given `CLAUDE.md`'s "don't overengineer" rule, this doesn't need to become a full test suite — just something real instead of the broken default.)
6. **Decide + document your environment strategy**: new prod Supabase project, migrations re-run there, and a build-time way to select dev vs. prod config (e.g. `--dart-define`) instead of hand-editing `env.dart`.
7. **Decide the data-deletion answer** for the store privacy forms (§5) — either document "retained indefinitely, deactivation only" as the real policy, or scope a deletion feature if required.
8. **On a Mac**: enroll in Apple Developer Program, configure signing team in Xcode, produce a real archive build.

None of the above has been implemented — this document is the audit and plan only, per your instructions.
