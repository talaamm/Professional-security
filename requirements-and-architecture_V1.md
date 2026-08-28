# Employee Work Hours & Location Tracking System

## V1 Requirements & Architecture Document

**Version:** 1.0

**Date:** August 2026

**Status:** Draft for Requirements & Architecture Approval

**Platform:** Mobile Application - Android & iOS

**Primary Users:** 50+ Employees, 3+ Administrators

**Industry:** Security Services / Field Workforce Management

---

# 1. Project Overview

## 1.1 Purpose

The system is a mobile application designed to allow employees to record their working hours while providing the company with reliable information about:

* When an employee started working
* When an employee finished working
* Where the employee started their work
* Where applicable, where the employee finished their work
* Which employees are currently working
* Which workplace each active employee is assigned to
* Historical working hours
* Administrative corrections and their reasons
* Monthly work-hour reports

The company operates across multiple workplaces and temporary locations, including events and security assignments. Therefore, the system must support both permanent and temporary workplaces.

---

## 1.2 Primary Goals

The V1 system must:

1. Allow employees to securely log in.
2. Associate employees with authorized devices.
3. Allow employees to start a work session.
4. Verify their physical location using GPS.
5. Automatically determine the workplace when possible.
6. Prevent employees from starting a session outside an approved workplace.
7. Allow multiple sessions on the same day.
8. Allow sessions to cross midnight.
9. Prevent overlapping sessions.
10. Allow employees to end their active session.
11. Support forgotten start/end actions through controlled manual correction.
12. Allow administrators to manually modify sessions.
13. Allow administrators to end active sessions.
14. Maintain a complete audit trail for important changes.
15. Allow employees to view and download their historical hours.
16. Allow administrators to view active employees in real time.
17. Allow administrators to generate employee/month reports.
18. Preserve historical data when an employee leaves the company.
19. Support many workplaces and temporary event locations.
20. Provide a foundation that can scale beyond the initial 50+ employees.

---

## 1.3 Core Principle

The system follows this rule:

> **The mobile application collects information and displays information. The backend makes the final decisions.**

For example, the Flutter application may collect GPS coordinates, but it must never decide:

> "I am close enough to the workplace."

Instead:

```text
Flutter
   ↓
GPS coordinates
   ↓
Backend
   ↓
Validate coordinates
   ↓
Determine workplace
   ↓
Apply business rules
   ↓
Create/reject session
```

---

# 2. Actors & Permissions

## 2.1 Employee

Employees can:

* Log in
* Log out
* Register/authorize a device
* View their current work status
* Start a work session
* End a work session
* View their work history
* View session details
* Submit a manual correction/request
* Add a note explaining a missed action
* Download their own reports

Employees cannot:

* Modify another employee's sessions
* Create workplaces
* Modify workplace coordinates
* Manage users
* Grant admin permissions
* Delete users
* View other employees' private work histories

---

## 2.2 Administrator

All administrators have equal permissions in V1.

Administrators can:

* Perform all employee actions
* View currently active employees
* View employee locations/workplaces
* View when active employees started
* View employee history
* Modify work sessions
* End active sessions
* Create workplaces
* Disable/deactivate workplaces
* Create employees
* Disable employees
* Restore employees if required
* Grant administrator privileges
* Remove administrator privileges
* Download reports
* Review manual location entries
* Review session corrections
* View audit logs

---

## 2.3 Developer/Test User

V1 may include a dedicated testing role/account.

The preferred implementation is to avoid creating a completely separate permission system.

Instead:

```text
User
 ├── Employee
 └── Admin

Environment/Test configuration
 └── Developer/Test accounts
```

Test accounts should be clearly identifiable and should not contaminate production attendance data.

If required, a `DEVELOPER` role may be added later.

---

## 2.4 Future Role Structure

The system may eventually support:

```text
SUPER_ADMIN
ADMIN
EMPLOYEE
```

However, V1 assumes all administrators have equal permissions.

---

# 3. Complete Employee Flow

## 3.1 First Login

```text
Install application
       ↓
Open application
       ↓
Enter username + password
       ↓
Backend authenticates user
       ↓
Check account status
       ↓
Check device
       ↓
Register/authorize device if required
       ↓
Employee enters application
```

If the employee account is inactive:

```text
Access denied.
Please contact an administrator.
```

---

## 3.2 Normal Start-Work Flow

```text
Employee opens application
       ↓
Dashboard
       ↓
Press "Start Work"
       ↓
Application requests GPS
       ↓
GPS coordinates obtained
       ↓
Coordinates sent to backend
       ↓
Backend validates:
    - authentication
    - account status
    - device
    - GPS accuracy
    - workplace
    - active session
       ↓
Workplace identified
       ↓
Session created
       ↓
Dashboard changes to "Working"
```

Example:

```text
Tala

Status:
🟢 Working

Workplace:
Event Hall A

Started:
08:03
```

---

## 3.3 Multiple Sessions

An employee may have multiple sessions during the same day.

Example:

```text
08:00 → 12:00
13:00 → 17:00
22:00 → 03:00
```

The system allows this as long as sessions do not overlap.

---

## 3.4 Cross-Midnight Session

Sessions are not required to begin and end on the same calendar date.

Example:

```text
September 3, 23:00
        ↓
September 4, 03:00
```

The session duration is:

```text
4 hours
```

The database stores the actual UTC timestamps.

---

## 3.5 Normal End-Work Flow

```text
Employee
   ↓
Press "Finish Work"
   ↓
Application may request current GPS
   ↓
GPS sent to backend
   ↓
Backend finds active session
   ↓
Backend records server timestamp
   ↓
Session becomes completed
```

The exact end-location policy can be configured.

Possible result:

```text
Started:
Event Hall A

Ended:
Event Hall A
```

or:

```text
Started:
Event Hall A

Ended:
Unknown / Unverified Location
```

---

## 3.6 Forgotten Start

If an employee forgot to start their session:

```text
Dashboard
   ↓
"Forgot to Start?"
   ↓
Enter actual start time
   ↓
Select/enter workplace
   ↓
Write optional explanation
   ↓
Submit
```

Example note:

> I started at 06:00 but forgot to mark my session.

The system should clearly mark this as a manually reported/corrected session rather than treating it as a normal automatic clock-in.

---

## 3.7 Forgotten End

If an employee forgot to end:

```text
Dashboard
   ↓
"Forgot to End?"
   ↓
Enter actual end time
   ↓
Select detected workplace OR manually specify location
   ↓
Optional note
   ↓
Submit
```

Possible end-location states:

```text
VERIFIED_WORKPLACE
MANUALLY_SPECIFIED_WORKPLACE
UNKNOWN_LOCATION
```

---

# 4. Complete Admin Flow

## 4.1 Admin Dashboard

The dashboard should provide an overview:

```text
ACTIVE EMPLOYEES: 17

Employee      Workplace       Started       Duration
-----------------------------------------------------
Tala          Event Hall A    08:03         4h 20m
Ahmad         Location B      07:55         4h 28m
Sara          Location C      08:17         4h 06m
```

Administrators should be able to filter by:

* Employee
* Workplace
* Status
* Date

---

## 4.2 View Employee

Admin selects an employee:

```text
Employee:
Tala

Current status:
Working

Current workplace:
Event Hall A

Started:
08:03
```

The administrator can then view historical sessions.

---

## 4.3 End Active Session

Admin can end an employee's active session.

The system must record:

```text
ended_at
ended_by = ADMIN
admin_user_id
reason
```

The system must not make it appear as though the employee personally ended the session.

---

## 4.4 Modify Session

Admin can modify:

* Start time
* End time
* Workplace
* Location verification status
* Notes/reason

Every modification must generate an audit record.

---

## 4.5 Employee Management

Admin can:

* Create employee
* Edit employee
* Deactivate employee
* Reactivate employee
* Reset credentials
* View registered devices
* Revoke a device
* Grant admin permissions
* Remove admin permissions

Employee deletion should be implemented as **soft deletion/deactivation**.

Historical data must remain available.

---

# 5. Edge Cases

The following cases must be explicitly considered in V1.

## 5.1 Employee presses Start twice

First request:

```text
Session created.
```

Second request:

```text
You already have an active session.
```

No second active session is created.

---

## 5.2 Employee presses End without an active session

Return:

```text
No active work session was found.
```

No record should be created accidentally.

---

## 5.3 Employee forgets to start

Support a manual correction/request with:

* Actual start time
* Workplace
* Optional note
* Correction status

---

## 5.4 Employee forgets to end

Support manual ending with:

* Actual end time
* Workplace/end-location status
* Optional note

---

## 5.5 Admin ends forgotten session

Allowed.

Record:

```text
actor = ADMIN
action = END_SESSION
reason = required
```

---

## 5.6 Employee remains active for an unusually long time

The system should flag sessions exceeding a configurable threshold.

Example:

```text
Session duration > 16 hours
```

Admin dashboard:

```text
⚠ Unusually long session
```

The system should not automatically delete or modify the session.

---

## 5.7 GPS unavailable

Display:

```text
Unable to determine your location.

[Try Again]

[Manual Location]
```

Manual location should be clearly marked as unverified.

---

## 5.8 GPS accuracy is poor

If GPS accuracy is outside the configured acceptable threshold:

```text
Your location could not be determined accurately.
Please move to an area with better GPS reception and try again.
```

---

## 5.9 Employee is not near an approved workplace

Reject automatic clock-in.

Provide:

```text
No approved workplace was detected.

[Try Again]

[Enter Location Manually]
```

Manual location is recorded as unverified/manual.

---

## 5.10 Multiple workplaces are nearby

The backend may find multiple valid workplaces.

The system should either:

1. Select the closest valid workplace, or
2. Return the candidates and let the employee confirm.

Preferred V1 behavior:

```text
Closest workplace detected:
Event Hall A

[Confirm]
```

---

## 5.11 Employee changes physical location during a session

V1 does **not continuously track employee location**.

The workplace recorded for the session remains the workplace associated with the start event unless an authorized administrator modifies it.

---

## 5.12 Employee changes phone

Employee can register a replacement device.

Old device:

```text
REVOKED
```

New device:

```text
ACTIVE
```

The employee's historical sessions remain unchanged.

---

## 5.13 Shared phone / buddy clock-in

The system should prevent or discourage this through:

* Authenticated account
* Registered device
* Device authorization
* GPS verification
* Server-side validation
* Audit logs

However:

> GPS and device registration cannot mathematically prove that the human holding the phone is the account owner.

V1 should therefore treat device registration as an additional security control, not biometric identity verification.

and when user x start their session, they try to log out WHILE their session is active, give warning: "If You log out, you're session will be terminated!"

---

## 5.14 Device is lost

Admin can revoke the device.

The employee can register a replacement device through the approved process.

---

## 5.15 Network unavailable

Recommended V1 behavior:

```text
Internet connection required to start/end a session.
```

Offline attendance synchronization should remain outside V1 unless the company confirms that unreliable connectivity is common at security assignments.

---

## 5.16 Session crosses midnight

Allowed.

Duration is calculated using the complete timestamps, not calendar dates.

---

## 5.17 Employee leaves company

Account becomes:

```text
INACTIVE
```

Historical data remains available.

if they try to log-in, sorry this account is inactive, to reactivate it please contact the admins.

---

## 5.18 Workplace is no longer used (approx no such a thing)

Workplace becomes:

```text
INACTIVE
```

Historical sessions referencing it remain unchanged.

---

# 6. Functional Requirements

## Authentication

**FR-001** The system shall authenticate users using username and password.

**FR-002** Passwords shall never be stored in plaintext.

**FR-003** Inactive users shall not be allowed to log in.

**FR-004** The system shall support password reset through an administrator or approved recovery mechanism.

user id is their username which will be their ID number.

---

## Device Management

**FR-005** The system shall associate users with authorized devices.

**FR-006** The system shall detect new/unrecognized devices.

**FR-007** Administrators shall be able to revoke devices.

**FR-008** Users shall be able to register a replacement device through an approved process.

---

## Work Sessions

**FR-009** Employees shall be able to start a work session.

**FR-010** Employees shall be able to end a work session.

**FR-011** The system shall prevent overlapping active sessions for the same employee, "You already have an active session, please end it to start a new one." OR when they have an active session just show the ending UI.

**FR-012** Employees may have multiple sessions per day.

**FR-013** Sessions may cross midnight.

**FR-014** Official timestamps shall originate from the backend/server.

**FR-015** Sessions shall reference a workplace where applicable.

**FR-016** Employees shall be able to submit missed start/end corrections, "as notes".

---

## Location

**FR-017** The system shall collect GPS coordinates during relevant actions.

**FR-018** The backend shall determine whether coordinates correspond to an approved workplace.

**FR-019** Workplaces shall have configurable coordinates and allowed radius.

**FR-020** Administrators shall be able to create workplaces using their current location.

**FR-021** The system shall support temporary workplaces.

**FR-022** The system shall support manual/unverified locations.

"OPTIONAL": maybe every hour take GPS coordinates and confirm the person is at workplace, if not maybe end it?

---

## Administration

**FR-023** Administrators shall see currently active employees.

**FR-024** Administrators shall see the workplace associated with active sessions.

**FR-025** Administrators shall see session start times.

**FR-026** Administrators shall be able to end sessions.

**FR-027** Administrators shall be able to modify sessions.

**FR-028** Administrators shall be able to manage employees.

**FR-029** Administrators shall be able to manage workplaces.

**FR-030** Administrators shall be able to grant/remove administrator privileges.

---

## Reports

**FR-031** Employees shall be able to view their own history.

**FR-032** Employees shall be able to download reports.

**FR-033** Administrators shall be able to generate reports by employee.

**FR-034** Administrators shall be able to select a month.

**FR-035** Reports shall calculate total work duration.

**FR-036** Reports shall include dates, workplaces, start times, end times, and total duration.

**FR-037** Report timestamps shall be converted from UTC to the configured reporting timezone.

---

# 7. Non-Functional Requirements

## Performance

* Normal API requests should respond quickly under normal network conditions.
* The system should support at least the initial 50+ employees.
* Architecture should allow future growth without fundamental redesign.

## Availability

The production system should be available during normal company operating hours and preferably continuously.

## Reliability

Attendance data must not be lost because of a mobile application crash or refresh.

All important operations must be transactional.

## Scalability

The architecture should support:

* 50+ employees initially
* Hundreds of employees later
* Thousands of workplaces/sessions
* Multiple administrators

without redesigning the core data model.

## Maintainability

Code should be separated into:

* Authentication
* Users
* Devices
* Workplaces
* Sessions
* Reports
* Administration
* Audit

## Usability

The employee's primary workflow should require very few actions:

```text
Open
→ Start Work
→ Confirm
```

and:

```text
Open
→ Finish Work
```

## Time

All server/database timestamps should be stored in UTC.

Reports convert UTC timestamps into the configured local timezone.

## Accessibility

The application should use readable text, sufficient touch targets, clear status indicators, and understandable error messages.

---

# 8. Database ERD

The exact implementation depends on the selected backend/database technology, but the logical model should be:

```text
┌─────────────────────┐
│       USERS         │
├─────────────────────┤
│ id PK               │
│ name                │
│ username            │
│ password_hash       │
│ role                │
│ status              │
│ created_at          │
│ updated_at          │
│ deleted_at          │
└──────────┬──────────┘
           │
     ┌───────────────────────┐
     │                       │
     │                       │
     ▼                       ▼
┌──────────────┐       ┌─────────────────┐
│   DEVICES    │       │  WORK_SESSIONS  │
├──────────────┤       ├─────────────────┤
│ id PK        │       │ id PK           │
│ user_id FK   │       │ user_id FK      │
│ device info  │       │ workplace_id FK │
│ platform     │       │ started_at      │
│ status       │       │ ended_at        │
│ registered   │       │ start_location  │
│ last_seen    │       │ end_location    │
└──────────────┘       │ verification    │
                       │ status          │
                       │ notes           │
                       │ created_at      │
                       └────────┬────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │   WORKPLACES    │
                       ├─────────────────┤
                       │ id PK           │
                       │ name            │
                       │ latitude        │
                       │ longitude       │
                       │ radius          │
                       │ status          │
                       │ created_by FK   │
                       │ created_at      │
                       └─────────────────┘


┌─────────────────────┐
│     AUDIT_LOGS      │
├─────────────────────┤
│ id PK               │
│ actor_user_id FK    │
│ action              │
│ entity_type         │
│ entity_id           │
│ old_value           │
│ new_value           │
│ reason              │
│ created_at          │
└─────────────────────┘
```

---

## 8.1 Important Database Rules

### Active session

An employee may have:

```text
0 or 1 active sessions
```

An active session is:

```text
ended_at IS NULL
```

### Multiple historical sessions

Allowed.

### Overlapping sessions

Not allowed.

### Soft deletion

Users are not physically deleted from the database.

### Historical integrity

Deleting/deactivating a workplace or user must not delete historical sessions.

---

# 9. Flutter Architecture

The mobile application should follow a layered architecture.

```text
Flutter Application
│
├── Presentation
│   ├── Login
│   ├── Dashboard
│   ├── Start Work
│   ├── End Work
│   ├── History
│   ├── Reports
│   └── Admin
│
├── State Management
│
├── Domain
│   ├── User
│   ├── Session
│   ├── Workplace
│   └── Report
│
├── Data
│   ├── API Client
│   ├── Authentication
│   ├── Location Service
│   └── Device Service
│
└── Local Storage
```

The exact state-management package can be selected during implementation.

---

## 9.1 Flutter Responsibilities

Flutter is responsible for:

* UI
* Navigation
* User interaction
* Requesting permissions
* Obtaining GPS coordinates
* Sending data to backend
* Displaying backend responses
* Local temporary state
* Securely storing authentication credentials/tokens

Flutter is NOT responsible for deciding:

* Whether the user is allowed to clock in
* Whether a location is valid
* Whether a session already exists
* Official timestamps
* Whether the user is an admin
* Whether an employee can modify a session

---

# 10. Backend Architecture

The backend is the authoritative layer.

```text
                Flutter App
                     │
                   HTTPS
                     │
                     ▼
             ┌───────────────┐
             │ API Layer     │
             └───────┬───────┘
                     │
        ┌────────────┼────────────┐
        ▼            ▼            ▼
 Authentication   Sessions     Admin
 Service          Service      Service
        │            │            │
        └────────────┼────────────┘
                     ▼
              Business Logic
                     │
        ┌────────────┼────────────┐
        ▼            ▼            ▼
     Location      Reports      Audit
     Service       Service      Service
                     │
                     ▼
                  Database
```

---

## 10.1 Backend Responsibilities

The backend must:

* Authenticate users
* Authorize requests
* Validate device authorization
* Validate GPS information
* Determine workplace
* Create sessions
* End sessions
* Prevent overlapping sessions
* Generate official timestamps
* Process corrections
* Manage users
* Manage workplaces
* Generate reports
* Record audit logs

---

# 11. Authentication / Device Architecture

## 11.1 Authentication

Recommended V1:

```text
Username
+
Password
```

The backend should return a secure authentication token/session.

Passwords must be hashed using a modern password hashing algorithm.

---

## 11.2 Device Registration

Logical model:

```text
USER
  │
  └──< DEVICE
```

Device record may contain:

```text
device_id
user_id
platform
application_version
registered_at
last_seen_at
status
```

Device identification should use a platform-appropriate mechanism.

The system should **not rely solely on an immutable hardware identifier**, because modern mobile operating systems intentionally restrict access to certain hardware identifiers.

---

## 11.3 New Device

```text
Login
 ↓
New device detected
 ↓
Verification
 ↓
Device authorized
```

The exact verification method can be selected during implementation.

Possible V1 approaches:

* Admin approval
* Existing-account verification
* Secure verification code

---

## 11.4 Device Replacement

```text
Old device
     ↓
REVOKED

New device
     ↓
ACTIVE
```

Historical sessions are unaffected.

---

# 12. GPS / Workplace Algorithm

## 12.1 Workplace Structure

Each workplace contains:

```text
name
latitude
longitude
radius
status
```

Example:

```text
Event Hall A

Latitude:
31.xxxxx

Longitude:
35.xxxxx

Allowed Radius:
100 meters
```

---

## 12.2 Workplace Creation

Admin physically goes to the workplace.

```text
Admin
 ↓
Add Workplace
 ↓
GPS location captured
 ↓
Accuracy checked
 ↓
Admin enters name
 ↓
System calculates/sets default radius
 ↓
Admin confirms
 ↓
Workplace created
```

The radius should remain configurable.

---

## 12.3 Start Location Algorithm

Employee sends:

```text
latitude
longitude
GPS accuracy
```

Backend:

```text
1. Authenticate user
2. Verify account is active
3. Verify device
4. Check for active session
5. Validate GPS accuracy
6. Retrieve active workplaces
7. Calculate distance from employee coordinates
8. Find valid workplace(s)
9. Select closest valid workplace
10. Create session
11. Record UTC server timestamp
```

---

## 12.4 Distance Calculation

Conceptually:

```text
Employee coordinates
        ↓
Distance calculation
        ↓
distance <= workplace.radius
        ↓
VALID
```

A geographic distance calculation such as the Haversine formula can be used.

The backend-not Flutter-performs the final calculation.

---

## 12.5 No Workplace Found

```text
No valid workplace detected.
```

The employee may:

```text
Try Again
```

or:

```text
Enter Location Manually
```

Manual locations must be explicitly marked:

```text
verification_status = MANUAL / UNVERIFIED
```

---

## 12.6 GPS Accuracy

The backend should consider the reported GPS accuracy.

Example rule:

```text
GPS accuracy acceptable
    ↓
Continue

GPS accuracy too poor
    ↓
Request retry
```

The exact threshold must be tested in real company locations before production.

---

# 13. Session State Machine

The core session lifecycle:

```text
                ┌─────────────┐
                │   NO SESSION│
                └──────┬──────┘
                       │
                   Start Work
                       │
                       ▼
              ┌─────────────────┐
              │     ACTIVE      │
              └────────┬────────┘
                       │
             ┌─────────┴─────────┐
             │                   │
        Employee End         Admin End
             │                   │
             └─────────┬─────────┘
                       ▼
              ┌─────────────────┐
              │    COMPLETED    │
              └─────────────────┘
```

Manual correction:

```text
NO SESSION
     │
     │ Forgot Start
     ▼
PENDING/MANUAL CORRECTION
     │
     ▼
COMPLETED / ACTIVE
```

Depending on the final business process, employee-submitted corrections may require immediate acceptance or administrator approval.

---

## 13.1 Session States

Recommended logical states:

```text
ACTIVE
COMPLETED
CORRECTION_PENDING
CANCELLED
```

A session should not simply disappear when something goes wrong.

---

# 14. Reporting Architecture

Reports should be generated from the database rather than stored as permanent files.

```text
Database
   ↓
Report Query
   ↓
Filter:
Employee
Date range
Timezone
   ↓
Calculate durations
   ↓
Generate report
   ↓
PDF / Excel / CSV
```

---

## 14.1 Employee Report

Employee selects:

```text
August 2026
```

System returns:

```text
Date       Workplace       Start      End       Duration
---------------------------------------------------------
Aug 01     Main Office     08:00      16:00     8h
Aug 02     Event Hall A    07:55      15:30     7h35m
Aug 03     Location B      23:00      03:00     4h
```

---

## 14.2 Admin Report

Admin selects:

```text
Employee:
Tala

Month:
August 2026
```

Then:

```text
[View]
[Download]
```

---

## 14.3 Report Timezone

Database:

```text
UTC
```

Report:

```text
UTC → configured local timezone
```

This should be handled by the backend report service.

---

## 14.4 Recommended Export Formats

V1:

* Excel (`.xlsx`)
* PDF
* CSV

The company can decide which formats are actually required before implementation.

---

# 15. Audit System

Because administrators can modify attendance records, auditing is essential.

Every sensitive operation should generate an audit event.

Examples:

```text
ADMIN_ENDED_SESSION
ADMIN_EDITED_SESSION
ADMIN_CREATED_USER
ADMIN_DEACTIVATED_USER
ADMIN_REACTIVATED_USER
ADMIN_GRANTED_ADMIN
ADMIN_REMOVED_ADMIN
ADMIN_CREATED_WORKPLACE
ADMIN_DEACTIVATED_WORKPLACE
DEVICE_REGISTERED
DEVICE_REVOKED
MANUAL_LOCATION_USED
SESSION_CORRECTION_SUBMITTED
```

---

## 15.1 Example Audit Entry

```text
Actor:
Admin Ahmad

Action:
ADMIN_EDITED_SESSION

Employee:
Tala

Date:
August 12

Old End:
16:00

New End:
18:00

Reason:
Approved overtime

Timestamp:
2026-08-12T16:05:00Z
```

---

## 15.2 Important Principle

Attendance data should never be silently changed.

Every administrative modification should answer:

```text
WHO changed it?
WHAT changed?
WHEN?
WHY?
```

---

# 16. Security Requirements

## 16.1 Transport Security

All communication must use:

```text
HTTPS
```

No production authentication or attendance API should use unencrypted HTTP.

---

## 16.2 Password Security

Never store:

```text
password = "123456"
```

Store only a secure password hash.

---

## 16.3 Authorization

Every protected backend endpoint must verify:

```text
Authentication
+
Authorization
```

For example:

```text
GET /my-sessions
```

must return only the authenticated user's sessions.

An employee must never be able to modify:

```text
/user/27/session/123
```

simply by changing an ID in the request.

---

## 16.4 Server-Side Validation

Never trust:

* User ID from the frontend
* Role from the frontend
* Workplace ID from the frontend
* Timestamp from the frontend
* Duration from the frontend
* Location validation from the frontend

The backend derives or validates these values.

---

## 16.5 GPS Security

GPS is treated as a verification signal, not absolute identity proof.

The backend validates:

* Coordinates
* Accuracy
* Workplace
* Distance
* Session state
* Account
* Device

---

## 16.6 Location Data Minimization

The system should avoid storing precise GPS coordinates permanently unless required.

Preferred:

```text
GPS received
     ↓
Validate
     ↓
Determine workplace
     ↓
Store workplace + verification status
```

rather than storing every exact coordinate indefinitely.

---

## 16.7 Audit Protection

Audit records should not be editable by normal administrators.

If audit deletion is ever required, it should be restricted to a controlled administrative/database process.

---

## 16.8 Account Deactivation

Employee deactivation must not delete historical work data.

---

## 16.9 Backups

Production attendance data must have automated backups.

Backup restoration should be tested periodically.

---

# 17. Deployment Architecture

The production system should be owned by the company rather than being dependent on the freelancer's personal accounts.

Logical architecture:

```text
                 Internet
                    │
          ┌─────────┴─────────┐
          │                   │
     Google Play          Apple App Store
          │                   │
          └─────────┬─────────┘
                    ▼
             Flutter App
                    │
                  HTTPS
                    │
                    ▼
             Backend / API
                    │
          ┌─────────┴─────────┐
          ▼                   ▼
      Database             Storage
          │
          ▼
       Backups
```

---

## 17.1 Company-Owned Accounts

Production ownership should ideally belong to the company:

* Apple Developer account
* Google Play Developer account
* Backend/cloud account
* Database account
* Domain
* Email/service accounts
* Analytics account if required

The freelancer/developer receives appropriate access.

---

## 17.2 Environments

At minimum:

```text
Development
     ↓
Staging/Test
     ↓
Production
```

Developer/test users should not accidentally generate production attendance data.

---

## 17.3 CI/CD

Future implementation may use:

```text
Git
 ↓
CI/CD
 ↓
Testing
 ↓
Build
 ↓
Deployment
```

The exact provider is TBD.

---

# 18. MVP vs Future Features

## 18.1 V1 MVP

### Authentication

* Username/password
* Login/logout
* Account activation/deactivation
* Device registration

### Employee

* Dashboard
* Start work
* End work
* GPS validation
* Automatic workplace detection
* Manual location fallback
* Multiple sessions/day
* Cross-midnight sessions
* Work history
* Report download

### Admin

* Dashboard
* Active employees
* Current workplace
* Start time
* Employee management
* Workplace management
* Session editing
* Session ending
* Admin management
* Reports

### System

* UTC timestamps
* PostgreSQL/relational database or equivalent
* Audit logs
* Soft deletion
* HTTPS
* Backups

---

## 18.2 Future Features

Potential future features:

### Advanced Attendance

* Break management
* Overtime calculation
* Late arrival detection
* Early departure detection
* Scheduled shifts
* Automatic reminders

### Advanced Location

* Continuous location verification
* Geofencing
* Route/location history
* Location anomaly detection
* Better temporary event management

### Identity

* Biometric authentication
* Stronger employee identity verification
* QR/NFC workplace verification
* Device risk detection

### Administration

* Employee groups
* Supervisors
* Different admin permission levels
* Approval workflows
* Payroll integration

### Reporting

* Company-wide monthly report
* Overtime reports
* Attendance statistics
* Payroll exports
* Automated monthly reports
* Google Sheets integration

### Notifications

* Forgot to clock out
* Long active session
* Shift reminders
* Admin alerts

### Offline

* Offline clock-in
* Offline clock-out
* Secure synchronization
* Conflict resolution

---

# 19. Development Milestones

## Milestone 0 - Requirements & Approval

Deliverables:

* Requirements document
* Business rules
* User flows
* Final feature list
* Client approval

No production development should begin until the core scope is approved.

---

## Milestone 1 - Architecture & UI/UX

Deliverables:

* Final technology stack
* Database ERD
* API specification
* Authentication design
* GPS architecture
* Employee UI prototype
* Admin UI prototype

---

## Milestone 2 - Backend Foundation

Implement:

* Project structure
* Database
* Authentication
* Users
* Roles
* Devices
* Basic API
* Security middleware

---

## Milestone 3 - Workplace System

Implement:

* Workplace creation
* GPS coordinates
* Radius
* Workplace activation/deactivation
* Distance calculation
* Workplace detection

Test at actual company locations.

---

## Milestone 4 - Employee Attendance

Implement:

* Start session
* End session
* Active session
* Multiple sessions
* Cross-midnight sessions
* Manual corrections
* GPS fallback

---

## Milestone 5 - Admin System

Implement:

* Admin dashboard
* Active employees
* Employee management
* Workplace management
* Session editing
* Admin session termination
* Admin management

---

## Milestone 6 - Reporting

Implement:

* Employee history
* Monthly filtering
* Admin reports
* Excel
* PDF
* CSV
* UTC → local timezone conversion

---

## Milestone 7 - Audit & Security

Implement:

* Audit logs
* Device revocation
* Permission checks
* Security testing
* Rate limiting
* Validation
* Backup configuration

---

## Milestone 8 - Testing

Test:

* Normal attendance
* Duplicate clock-in
* Duplicate clock-out
* Missing start
* Missing end
* Cross-midnight
* Multiple sessions
* GPS failure
* Poor GPS accuracy
* Unknown workplace
* Multiple nearby workplaces
* New phone
* Revoked device
* Inactive employee
* Admin modifications
* Long-running sessions
* Report calculations

---

## Milestone 9 - Production Deployment

Deliverables:

* Production backend
* Production database
* HTTPS
* Backups
* Monitoring
* Android build
* iOS build
* Google Play submission
* App Store submission

---

## Milestone 10 - Launch & Stabilization

After launch:

* Monitor errors
* Fix production bugs
* Verify reports
* Verify GPS behavior at real workplaces
* Collect employee feedback
* Document known limitations

---

# 20. Explicitly OUT of Scope for V1

The following should NOT automatically be included in the initial project price/scope unless specifically added to the contract.

## Payroll

The system records working hours.

It does not calculate or process salaries unless explicitly requested.

---

## Continuous Employee Tracking

V1 does not continuously track employees throughout their shift.

The system verifies location during relevant attendance actions.

---

## Biometric Identity Verification

No facial recognition, fingerprint-based attendance, or biometric identity verification in V1.

---

## Advanced Scheduling

No complete employee shift-planning system unless explicitly added.

---

## Automatic Overtime Rules

The system calculates duration but does not automatically determine payroll/overtime policies unless the company provides exact rules.

---

## Offline Attendance Synchronization

V1 assumes internet connectivity for clock-in/out.

---

## Google Sheets as the Primary Database

Google Sheets may be added later as an export/integration.

It should not be the source of truth for attendance data.

---

## Payroll/Accounting Integration

No integration with external payroll/accounting software in V1.

---

## Employee Location History

No continuous GPS history.

---

## Chat/Messaging

No employee/admin messaging system.

---

## Leave/Vacation Management

No vacation, sick leave, absence approval, or HR management unless added separately.

---

## Advanced Analytics

No complex BI/analytics dashboard in V1.

---

# Final Architecture Summary

The recommended logical architecture is:

```text
                    ┌──────────────────────┐
                    │      EMPLOYEE        │
                    │   Flutter App        │
                    └──────────┬───────────┘
                               │
                               │ HTTPS
                               ▼
                    ┌──────────────────────┐
                    │       BACKEND        │
                    │                      │
                    │ Authentication       │
                    │ Authorization        │
                    │ Device Management    │
                    │ Session Management   │
                    │ GPS Validation       │
                    │ Workplace Detection  │
                    │ Admin Management     │
                    │ Reports              │
                    │ Audit Logs           │
                    └──────────┬───────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │       DATABASE       │
                    │                      │
                    │ Users                │
                    │ Devices              │
                    │ Workplaces           │
                    │ Sessions             │
                    │ Audit Logs            │
                    └──────────┬───────────┘
                               │
                    ┌──────────┴───────────┐
                    ▼                      ▼
             Report Generator          Backups
                    │
             ┌──────┼──────┐
             ▼      ▼      ▼
           Excel   PDF    CSV
```

## Core Engineering Principles

1. **Backend is authoritative.**
2. **Database is the source of truth.**
3. **UTC is used for stored timestamps.**
4. **Reports convert timestamps to the configured local timezone.**
5. **Employees can have multiple sessions, but never overlapping active sessions.**
6. **Sessions may cross midnight.**
7. **GPS validates workplace proximity; it does not prove human identity.**
8. **Registered devices add an additional layer of identity protection.**
9. **Manual corrections are allowed but clearly identified.**
10. **Administrative modifications are audited.**
11. **Users and workplaces are soft-deactivated rather than physically deleted.**
12. **Precise GPS data should not be retained unnecessarily.**
13. **Production infrastructure should belong to the company.**
14. **V1 should remain focused on attendance, location verification, administration, and reporting.**
15. **New features outside the approved scope should be treated as separate change requests.**

---

# Technology Stack - To Be Finalized

The architecture intentionally does not lock the project to a specific backend provider yet.

The main candidates are:

### Option A

**Flutter + Firebase**

### Option B

**Flutter + Supabase/PostgreSQL**

### Option C

**Flutter + Custom Backend + PostgreSQL**

The final choice should be made after comparing:

* Development time
* Developer familiarity
* Authentication requirements
* GPS/business logic
* Reporting complexity
* Database requirements
* Realtime admin dashboard requirements
* Cost
* Backup strategy
* Long-term maintainability
* Vendor lock-in
* Deployment complexity

The logical architecture above should remain valid regardless of which of these implementations is selected.
