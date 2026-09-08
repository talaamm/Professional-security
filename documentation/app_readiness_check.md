Read `CLAUDE.md` first and inspect the entire workspace.

The application development is now considered feature-complete. We are preparing for production deployment to:

1. Google Play Store (Android)
2. Apple App Store (iOS)

DO NOT deploy the application yet.

Your task is to perform a complete PRODUCTION READINESS AUDIT of the existing Flutter + Supabase application.

Do not redesign the app or implement random new features.

Inspect the existing codebase, configuration, Android configuration, iOS configuration, Supabase integration, authentication, database access patterns, environment variables, permissions, and release configuration.

Create a clear production readiness report covering:

## 1. SECURITY

Check for:

* hardcoded secrets
* exposed Supabase keys
* accidental service_role usage in Flutter
* debug credentials
* insecure authentication flows
* insecure API/database access
* RLS assumptions
* sensitive information in logs
* development-only code
* test accounts left in production configuration

The Supabase anon/publishable key may exist in the mobile application as expected, but the service_role key must never be included.

## 2. ENVIRONMENT CONFIGURATION

Review the current environment setup.

Determine whether development and production Supabase environments are properly separated.

Do NOT automatically create a new production Supabase project.

Instead explain the recommended setup and what changes would be required.

Check that secrets/configuration files are properly excluded from Git.

## 3. ANDROID RELEASE READINESS

Inspect:

* application/package ID
* app name
* version name
* version code
* Android permissions
* release signing configuration
* AndroidManifest
* minimum SDK
* target SDK
* launcher icons
* debug configuration accidentally included in release

Identify everything that must be completed before Google Play submission.

## 4. IOS RELEASE READINESS

Inspect:

* Bundle Identifier
* application name
* version number
* build number
* iOS permissions
* Info.plist permission descriptions
* location permission descriptions
* app icons
* signing configuration
* minimum iOS version

Identify everything required before App Store submission.

Remember that the app uses GPS/location for employee work-session verification, so permission descriptions must clearly explain why location is needed.

## 5. PRIVACY

Identify what user data the app collects or processes, including:

* employee identity information
* employee ID
* location data
* work session timestamps
* device information if applicable
* authentication information

Create a list of information I will need when completing:

* Google Play Data Safety
* Apple App Privacy

Do not guess. Base the list on what the application actually does.

## 6. RELEASE QUALITY

Run:

* flutter analyze
* flutter test

Inspect for:

* debug prints
* TODO/FIXME items affecting production
* obvious crashes
* poor error handling
* missing loading states
* missing empty states

Do not make large architectural changes unless there is a genuine production blocker.

## 7. BUILD READINESS

Determine whether the project can currently produce:

* Android App Bundle (.aab)
* iOS release build

Do not upload anything.

Do not change signing identities without explaining what is required.

## 8. OUTPUT

Before making changes, give me a summary write it in a markdown file, of what you found.

Then categorize findings into:

🔴 BLOCKER — must fix before release

🟠 IMPORTANT — should fix before release

🟡 RECOMMENDED — production improvement

🟢 READY — already correctly configured

If changes are required, propose a small production-preparation plan.

Do NOT deploy the app.

Do NOT create store accounts.

Do NOT upload builds.

Do NOT change Supabase production data.

Stop after the audit and report.
