# Figma AI Prompt — Security Workforce Attendance & Location Tracking App

Design a complete, production-quality mobile application UI/UX for a professional **Security Workforce Attendance & Location Tracking System**.

The application is used by a security company with **50+ employees, multiple administrators, and many permanent and temporary security workplaces such as offices, event halls, parties, concerts, and other security assignments**.

The application allows employees to securely start and end work sessions, verifies their workplace using GPS, tracks their working hours, and provides administrators with a real-time overview of active employees and attendance records.

The design must feel:

* Professional
* Modern
* Premium
* Trustworthy
* Security-focused
* Extremely easy to use
* Fast and practical for employees who may be using the app while working
* Clean rather than overly decorative

Do NOT make it look like a generic fitness, finance, or social media app.

---

# BRAND & COLOR SYSTEM

Use this exact color palette:

### Primary / Accent

`#FF8C00` — Vibrant Amber Orange

Use for:

* Primary CTA buttons
* Main actions
* Active navigation indicators
* Important icons
* Security-related highlights
* Logo/accent elements
* Important interactive states

### Secondary / Status

`#FFB74D` — Soft Muted Orange

Use for:

* Secondary actions
* Supporting icons
* Subheadings
* Warning states
* Secondary highlights

### Deep Background

`#121214` — Rich Charcoal Black

Use for:

* Main application background
* Large empty areas
* Main canvas

Do NOT use pure black `#000000`.

### Surface / Component

`#1E1E24` — Dark Slate Gray

Use for:

* Cards
* Input fields
* Navigation bars
* Dialogs
* Bottom sheets
* Tables
* Secondary containers

### Primary Text

`#FFFFFF`

Use for:

* Main headings
* Important information
* Button labels
* Employee names
* Main data

### Secondary Text

`#9AA0A6`

Use for:

* Captions
* Timestamps
* Supporting descriptions
* Disabled states
* Secondary information

### Additional Functional Colors

Use functional colors only where necessary:

* Secure/success: muted emerald green
* Error/emergency: soft crimson red
* Warning: amber/orange

Do not introduce large amounts of additional colors.

---

# COLOR HIERARCHY

Follow approximately a **60 / 30 / 10 visual hierarchy**:

* 60% `#121214`
* 30% `#1E1E24`
* 10% `#FF8C00`

Orange should feel powerful and intentional.

Do not make the entire interface orange.

Use subtle glow effects inspired by a modern security/technology aesthetic.

For important security indicators, use a very subtle orange glow:

`0 0 8px rgba(255,140,0,0.4)`

Do not overuse glow effects.

---

# DESIGN LANGUAGE

Use:

* Rounded cards
* Clean spacing
* Strong visual hierarchy
* Modern sans-serif typography
* Large readable numbers
* Clear icons
* Minimal but meaningful animations
* Subtle shadows
* Subtle orange glow around important status indicators
* Consistent 8pt spacing system
* Large touch targets
* Mobile-first layouts

Avoid:

* Excessive gradients
* Excessive glassmorphism
* Excessive neon
* Tiny text
* Clutter
* Excessive orange
* Complex navigation
* Decorative elements that interfere with usability

The application should look excellent in dark mode.

---

# APP STRUCTURE

Create the following complete screens and flows.

## AUTHENTICATION

### 1. Splash Screen

Design a premium splash screen.

Elements:

* Company/security logo
* App name
* Very subtle orange glow
* Dark background
* Minimal loading indicator

Keep it elegant and short.

---

### 2. Login Screen

Design a secure employee login screen.

Elements:

* Logo
* Welcome message
* Username input
* Password input
* Show/hide password icon
* "Remember me" or secure session option if appropriate
* Primary "Login" button
* "Forgot Password?" option
* Small security/trust indicator

Example visual hierarchy:

WELCOME BACK

Employee ID / Username
[________________]

Password
[________________]

[        LOGIN        ]

Forgot password?

The screen should immediately communicate trust and security.

---

### 3. First Device Registration

After successful first login, show a device registration/authorization screen.

Explain clearly:

"This device will be registered to your account for additional security."

Show:

* Device name
* Platform
* Registration status
* Security explanation
* Continue button

Example:

DEVICE REGISTRATION

You're signing in from a new device.

This device will be associated with your account to help prevent unauthorized attendance activity.

[ REGISTER THIS DEVICE ]

If the device requires admin approval:

[ REQUEST APPROVAL ]

---

# EMPLOYEE APPLICATION

Use a simple bottom navigation with approximately:

* Home
* History
* Reports
* Profile

Keep the primary attendance action on the Home screen.

---

# 4. EMPLOYEE HOME — NOT WORKING

This is the most important employee screen.

Design a highly polished dashboard.

Top:

"Good morning, Tala"

Small current date.

Then a large status card:

STATUS

● Not Working

You don't currently have an active work session.

Below it:

LOCATION

📍 Location detection available

Then a very prominent CTA:

[ START WORK ]

The Start Work button should be the strongest visual element on the screen.

Below:

Today's Summary

Sessions today: 0
Total hours today: 0h 00m

Then quick actions:

[ View History ]
[ Download Report ]

Keep the screen simple.

---

# 5. LOCATION CHECK MODAL

When employee presses START WORK:

Show a bottom sheet/modal.

Title:

"Checking your workplace"

Animated GPS/location icon.

Message:

"Verifying that you're at an approved workplace."

Show a subtle loading state.

Then transition to one of the following states.

---

# 6. LOCATION VERIFIED

Success state:

✓ Workplace detected

"Event Hall A"

"You're within the approved workplace area."

Show:

Distance: 42m
GPS accuracy: 18m

Then:

[ START WORK ]

Use a subtle emerald success indicator while retaining the orange brand language.

---

# 7. MULTIPLE/AMBIGUOUS WORKPLACE

If multiple workplaces are nearby:

"Workplace detected"

Show one or more workplace cards:

Event Hall A
120m away

Event Hall B
145m away

Allow employee to confirm the correct workplace.

[ CONFIRM LOCATION ]

---

# 8. LOCATION NOT FOUND

Design a clear error/fallback screen.

Icon: location pin with warning indicator.

Title:

"Workplace not detected"

Message:

"We couldn't automatically identify an approved workplace."

Actions:

[ TRY AGAIN ]

[ ENTER LOCATION MANUALLY ]

Manual location should visually indicate that it will be recorded as manually specified/unverified.

---

# 9. MANUAL LOCATION

Design a simple form.

Title:

"Enter workplace"

Input:

Workplace / assignment location

[________________]

Optional note:

[________________]

Show warning:

"Your location could not be verified automatically. This session will be marked as manually specified."

CTA:

[ SUBMIT ]

---

# 10. EMPLOYEE HOME — CURRENTLY WORKING

Once a session is active, completely transform the Home screen.

Top:

"You're currently working"

Large status indicator:

● WORKING

Use a subtle orange/green glow.

Main card:

WORKING SINCE

08:03

Elapsed:

04h 27m

WORKPLACE

📍 Event Hall A

Then a large primary action:

[ FINISH WORK ]

This should be visually distinct from the Start button.

Below:

Today's Sessions

08:03 → Active
Event Hall A

Previous session:
13:00 → 17:00
Location B

Also show:

Today's total:
8h 27m

---

# 11. END WORK CONFIRMATION

When employee presses Finish Work, show a confirmation dialog/bottom sheet.

Title:

"Finish your work session?"

Show:

Started:
08:03

Current duration:
08h 27m

Workplace:
Event Hall A

Primary:

[ FINISH WORK ]

Secondary:

[ CANCEL ]

If location is required for the end action, show a GPS verification step before completing.

---

# 12. END LOCATION RESULT

Possible states:

### Verified

"End location verified"

📍 Event Hall A

[ CONFIRM END ]

### Unknown Location

"Workplace could not be identified"

Provide:

[ Enter Location Manually ]

or:

[ Finish Without Location ]

with a clear explanation that the end location will be recorded as unknown/unverified.

---

# 13. FORGOT TO START

Add a secondary action on the Home screen:

"Forgot to start?"

Open a correction form.

Fields:

Date
Start time
Workplace
Optional note

Example:

"I started at 06:00 but forgot to mark my session."

CTA:

[ SUBMIT CORRECTION ]

Clearly label this as a manual correction.

---

# 14. FORGOT TO END

Add:

"Forgot to end?"

Fields:

End time
Location
Optional note

Possible location choices:

✓ Verified workplace
Manual workplace
Unknown location

CTA:

[ SUBMIT ]

Clearly communicate that this is a manual correction.

---

# 15. EMPLOYEE HISTORY

Design a History screen.

Header:

WORK HISTORY

Filters:

[ Month ▼ ]
[ Workplace ▼ ]

Use clean session cards/list rows.

Example:

AUGUST 2026

AUG 28
Event Hall A
08:00 → 16:00
8h 00m

AUG 27
Location B
07:55 → 15:30
7h 35m

AUG 26
Main Office
08:10 → 17:00
8h 50m

Use clear status badges for:

Verified
Manual
Adjusted
Unknown

---

# 16. SESSION DETAILS

When an employee taps a session, show:

Session Details

Date
August 28, 2026

Workplace
Event Hall A

Started
08:03

Ended
16:05

Duration
8h 02m

Start verification
✓ Verified

End verification
✓ Verified

If manually changed:

"Adjusted by Administrator"

Show note/reason if applicable.

---

# 17. EMPLOYEE REPORTS

Create a Reports screen.

Header:

MY REPORTS

Monthly report cards:

August 2026
Total hours: 168h 32m
Sessions: 22

[ DOWNLOAD ]

July 2026
Total hours: 154h 10m
Sessions: 20

[ DOWNLOAD ]

Allow:

* PDF
* Excel
* CSV

Use a clean export bottom sheet:

DOWNLOAD REPORT

Format:

○ PDF
○ Excel
○ CSV

[ DOWNLOAD ]

---

# 18. PROFILE / SETTINGS

Show:

Profile photo/avatar
Employee name
Employee ID
Username
Account status

Device:

Current device
Registered date
Device status

Actions:

Change password
Manage device
Log out

Do not expose sensitive technical information unnecessarily.

---

# ADMIN APPLICATION

Administrators have a separate dashboard experience.

Use a professional operational dashboard style.

Navigation can use:

* Dashboard
* Employees
* Workplaces
* Sessions
* Reports
* Admins
* Audit
* Profile

On smaller mobile screens, use a bottom navigation or expandable navigation drawer.

---

# 19. ADMIN DASHBOARD

This is the main admin screen.

Header:

GOOD MORNING, ADMIN

Show summary cards:

ACTIVE EMPLOYEES
17

WORKING LOCATIONS
6

TODAY'S SESSIONS
42

UNUSUAL SESSIONS
2

Then:

CURRENTLY WORKING

List active employees:

┌──────────────────────────────┐
│ Tala Abu Alamm               │
│ 📍 Event Hall A              │
│ Started 08:03                │
│ Working 04h 27m              │
│                        ●     │
└──────────────────────────────┘

Each card should show:

Employee name
Workplace
Start time
Elapsed duration
Status

Use real-time visual indicators.

---

# 20. ACTIVE EMPLOYEE DETAILS

When admin taps an active employee:

Employee:
Tala Abu Alamm

Status:
● WORKING

Workplace:
Event Hall A

Started:
08:03

Current duration:
04h 27m

Actions:

[ VIEW SESSION ]

[ END SESSION ]

If ending manually, require a reason.

Example modal:

END SESSION

You are ending Tala's active session.

End time:
[ 16:30 ]

Reason:
[ Employee left workplace ]

[ END SESSION ]

---

# 21. EMPLOYEES TAB

Create an employee management screen.

Header:

EMPLOYEES

Search:

[ 🔍 Search employees ]

Filters:

All
Active
Inactive
Admins

Employee list:

Tala Abu Alamm
Employee ID: TG-1042
● Active

Ahmad Hassan
Employee ID: TG-1037
● Active

Sara Khalil
Employee ID: TG-1019
● Inactive

Floating/action button:

[ + Add Employee ]

---

# 22. EMPLOYEE DETAILS — ADMIN

Show:

Employee name
Employee ID
Username
Status
Role

Current status:
Working / Not working

Current workplace if active

Statistics:

This month
Total hours
Sessions
Manual corrections

Actions:

[ View Sessions ]
[ Edit Employee ]
[ Manage Device ]
[ Deactivate Employee ]

If admin:

[ Remove Admin Role ]

If employee:

[ Grant Admin Role ]

---

# 23. ADD EMPLOYEE

Form:

Full name
Employee ID
Username
Temporary password
Role

Optional:

Device registration instructions

Primary:

[ CREATE EMPLOYEE ]

---

# 24. WORKPLACES TAB

Design a workplace management screen.

Header:

WORKPLACES

Search field.

Categories:

Active
Inactive
Temporary

Cards:

Event Hall A
📍 Jerusalem
Radius: 100m
● Active

Main Office
📍 Jerusalem
Radius: 75m
● Active

Event Venue B
📍 Jerusalem
Temporary
● Active

Primary action:

[ + ADD WORKPLACE ]

---

# 25. ADD WORKPLACE

The admin physically visits the location.

Screen:

ADD WORKPLACE

Large map/location area.

Show:

📍 Current Location

Latitude/longitude should be secondary information and not visually dominate the screen.

Detected accuracy:

18m

Fields:

Workplace name
[________________]

Default radius
[ 100m ▼ ]

Show a visual circle on the map representing the allowed area.

CTA:

[ SAVE WORKPLACE ]

---

# 26. WORKPLACE DETAILS

Show:

Workplace name

Map

Allowed radius

Status

Created by

Created date

Currently working:

8 employees

Actions:

[ Edit ]
[ Deactivate ]

---

# 27. SESSIONS TAB

Admin can browse all work sessions.

Header:

WORK SESSIONS

Filters:

Employee
Date
Workplace
Status
Verification

Table/list:

Employee
Workplace
Start
End
Duration
Status

Example:

Tala
Event Hall A
08:03
16:05
8h 02m
Verified

Ahmed
Location B
07:55
—
4h 30m
Active

---

# 28. SESSION EDITOR

Admin can edit a session.

Fields:

Employee
Date
Start time
End time
Workplace
Start verification
End verification
Note

Show warning:

"Changes to attendance records are logged."

Require:

Reason for modification

CTA:

[ SAVE CHANGES ]

Secondary:

[ CANCEL ]

---

# 29. REPORTS — ADMIN

Design a professional report generator.

Header:

REPORTS

Filters:

Employee
[ All Employees ▼ ]

Month
[ August 2026 ▼ ]

Workplace
[ All Workplaces ▼ ]

Status
[ All ▼ ]

Actions:

[ GENERATE REPORT ]

After generation:

Tala
August 2026

Total hours:
168h 32m

Sessions:
22

Manual corrections:
2

Unverified sessions:
1

Buttons:

[ Download Excel ]
[ Download PDF ]
[ Download CSV ]

Also provide:

[ Download All Employees ]

if supported.

---

# 30. ADMIN MANAGEMENT

Since all administrators have equal permissions in V1, create an Admins screen.

Header:

ADMINISTRATORS

List:

Admin Name
Status
Last active

Example:

Tala
Administrator
● Active

Ahmad
Administrator
● Active

Actions:

[ + Add Admin ]

When granting admin access:

Show confirmation:

"Grant administrator access?"

Explain:

"Administrators can manage employees, workplaces, sessions, reports, and other administrators."

[ CONFIRM ]

Removing admin access should also require confirmation.

---

# 31. AUDIT LOG

Create an administrative Audit screen.

Header:

AUDIT LOG

Filters:

User
Admin
Action
Date

Rows/cards:

ADMIN EDITED SESSION

Admin:
Ahmad

Employee:
Tala

Changed:
16:00 → 18:00

Reason:
Approved overtime

2 minutes ago

Another example:

ADMIN ENDED SESSION

Admin:
Sara

Employee:
Ahmed

Reason:
Employee left workplace

The audit interface should visually communicate that records are historical and should not be casually modified.

---

# 32. GLOBAL SEARCH

For the admin interface, include a global search capability.

Admin can search:

* Employee
* Employee ID
* Workplace
* Session

Search should be fast and simple.

---

# 33. NOTIFICATION / ALERT STATES

Create reusable notification components for:

Success
Warning
Error
Information
Security alert

Examples:

✓ Work session started

⚠ GPS accuracy is too low. Try again.

✕ No approved workplace detected.

✓ Report generated successfully.

⚠ This session has been active for an unusually long time.

---

# 34. IMPORTANT EMPTY STATES

Design empty states for:

No work history
No active employees
No workplaces
No reports
No search results
No current session

Example:

NO ACTIVE EMPLOYEES

"Nobody is currently marked as working."

Use simple illustrations/icons, not large decorative graphics.

---

# 35. LOADING STATES

Create skeleton/loading states for:

* Dashboard
* Employee list
* Session list
* Reports
* Workplace detection
* Login
* Report generation

Avoid showing blank screens while data loads.

---

# 36. ERROR STATES

Create polished error states for:

* Invalid login
* Network unavailable
* GPS permission denied
* GPS unavailable
* GPS accuracy too low
* Workplace not detected
* Session already active
* No active session
* Server error
* Unauthorized action
* Report generation failure

Each error should clearly explain what happened and what the user can do next.

---

# 37. CONFIRMATION DIALOGS

Use confirmation dialogs for destructive or important actions:

* End active session as admin
* Deactivate employee
* Remove admin privileges
* Deactivate workplace
* Modify attendance record

Avoid unnecessary confirmations for ordinary actions.

---

# 38. RESPONSIVE DESIGN

The primary product is a mobile application.

Design:

* iPhone-sized layouts
* Android-sized layouts

Also create an admin-friendly larger-screen responsive version if appropriate.

The employee experience should remain mobile-first.

The admin experience should prioritize information density and operational visibility.

---

# 39. DESIGN SYSTEM

Create reusable components and Figma components for:

Buttons:

* Primary
* Secondary
* Destructive
* Disabled

Inputs:

* Default
* Focus
* Error
* Disabled

Cards:

* Status card
* Employee card
* Session card
* Workplace card
* Report card

Badges:

* Working
* Not working
* Verified
* Manual
* Unknown
* Adjusted
* Active
* Inactive

Navigation:

* Bottom navigation
* Admin navigation
* Top bars

Dialogs:

* Confirmation
* Error
* Success
* Location verification
* Manual correction

---

# 40. TYPOGRAPHY

Use a modern, highly readable sans-serif typeface.

Prioritize:

* Large headings
* Large work-hour numbers
* Highly readable timestamps
* Clear labels
* Strong contrast

The UI must remain readable outdoors and in bright environments despite using a dark theme.

---

# 41. ICONOGRAPHY

Use simple modern outline icons.

Suggested concepts:

Location pin
Shield
Clock
Calendar
User
Users
Map
Download
File
Settings
Device
Warning
Check
X
Search
Admin/security

Keep icon style consistent.

---

# 42. MICRO-INTERACTIONS

Add subtle animations for:

* Starting a session
* Ending a session
* GPS verification
* Successful workplace detection
* Loading
* Report generation
* Button press
* Active-work timer

The active work timer should update smoothly.

Avoid excessive animation.

---

# 43. SECURITY VISUAL LANGUAGE

The application should subtly communicate:

"Your attendance is verified."

Use visual concepts such as:

* Shield
* Location pin
* Verified checkmark
* Secure status
* Subtle orange glow

However, do not make the application look like a military control panel.

It should feel like a modern professional SaaS product.

---

# 44. COMPLETE SCREEN FLOW

Create the screens as an interconnected prototype.

Employee:

Splash
→ Login
→ Device Registration
→ Home / Not Working
→ Location Verification
→ Workplace Confirmation
→ Home / Working
→ End Work
→ End Location
→ Completed
→ History
→ Session Details
→ Reports
→ Download
→ Profile

Alternative flows:

Home
→ Forgot Start
→ Manual Correction

Home
→ Forgot End
→ Manual Correction

Home
→ GPS Failure
→ Manual Location

Admin:

Admin Login
→ Admin Dashboard
→ Active Employee
→ Employee Details
→ Session Details
→ End Session

Admin Dashboard
→ Employees
→ Employee Details
→ Edit Employee
→ Device Management

Admin Dashboard
→ Workplaces
→ Workplace Details
→ Add Workplace
→ Edit Workplace

Admin Dashboard
→ Sessions
→ Session Details
→ Edit Session

Admin Dashboard
→ Reports
→ Generate Report
→ Download

Admin Dashboard
→ Administrators
→ Grant Admin
→ Remove Admin

Admin Dashboard
→ Audit Log

---

# 45. FINAL VISUAL DIRECTION

The final design should feel like:

"Premium security operations + modern workforce management."

Think:

* Dark professional interface
* Amber/orange brand accents
* Strong typography
* Clean cards
* Clear operational status
* Location-aware UI
* Subtle technology aesthetic
* Premium but practical
* Extremely clear employee actions

The most important action on the employee app should always be obvious:

If not working:

[ START WORK ]

If working:

[ FINISH WORK ]

The employee should never have to wonder what they should do next.

Create a complete high-fidelity Figma design with reusable components, consistent spacing, component variants, realistic sample data, interactive states, and connected prototype flows.
