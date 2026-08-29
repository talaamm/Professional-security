# 1. Our Development Strategy

I would build this in roughly **10 phases**:

```text
PHASE 0                                                     DONE
Requirements + Architecture                         
        ↓
PHASE 1                                                     DONE
Supabase + Database + Auth Foundation
        ↓
TEST                                                     currently
        ↓
PHASE 2
Flutter Foundation + Login
        ↓
TEST
        ↓
PHASE 3
Employee Start/End Session
        ↓
TEST
        ↓
PHASE 4
GPS + Workplace Detection
        ↓
TEST
        ↓
PHASE 5
Employee History + Corrections
        ↓
TEST
        ↓
PHASE 6
Admin Dashboard
        ↓
TEST
        ↓
PHASE 7
Admin Session/User/Workplace Management
        ↓
TEST
        ↓
PHASE 8
Reports + Downloads
        ↓
TEST
        ↓
PHASE 9
Security + Audit + Hardening
        ↓
TEST
        ↓
PHASE 10
Production Deployment
```

**The important part:** after every phase, we stop adding features and test what we just built.

That makes this much safer than:

> "Claude, build the entire app."

---

# 2. PHASE 0 — Requirements & Architecture

We've basically started this already.

### We finalize:

* Actors
* Permissions
* Employee flow
* Admin flow
* Session rules
* GPS rules
* Device rules
* Reports
* Audit requirements
* Edge cases
* Out-of-scope features

### Deliverable

A `/docs` folder:

```text
docs/
├── requirements.md
├── architecture.md
├── database.md
├── authentication.md
├── gps.md
├── sessions.md
├── reporting.md
├── security.md
└── decisions.md
```

### Test

No coding yet.

We manually walk through scenarios:

> Employee starts at 08:00.

> Employee starts twice.

> Employee works 23:00 → 03:00.

> Employee forgets to clock out.

> Admin ends session.

> Employee changes phone.

If the requirements survive those scenarios, move on.

---

# 3. PHASE 1 — Supabase Foundation

**Yes, this should happen before serious Flutter development.**

Create the Supabase project and establish:

```text
Supabase
│
├── PostgreSQL
├── Authentication
├── Row Level Security
├── Storage
├── Realtime
└── Edge Functions
```

But we don't need to use every Supabase feature immediately.

Initially:

### Use

* PostgreSQL
* Supabase Auth
* RLS

Later:

* Realtime
* Edge Functions
* Storage

---

# 4. The Database ERD

I'd slightly refine our previous ERD for Supabase.

The most important architectural decision:

## Don't make your own password system.

Use **Supabase Auth** for authentication.

Then maintain your own application-level `profiles` table.

So:

```text
Supabase Auth
     │
     │ auth.users.id
     ▼
profiles
```

---

## Complete V1 ERD

```text
                           ┌──────────────────────┐
                           │   auth.users         │
                           │  (SUPABASE AUTH)     │
                           ├──────────────────────┤
                           │ id PK                │
                           │ email                │
                           │ encrypted_password   │
                           │ created_at           │
                           └──────────┬───────────┘
                                      │
                                      │ 1
                                      │
                                      │
                                      ▼
                           ┌──────────────────────┐
                           │      PROFILES        │
                           ├──────────────────────┤
                           │ id PK/FK             │
                           │ employee_number      │
                           │ full_name            │
                           │ role                 │
                           │ status               │
                           │ created_at           │
                           │ updated_at           │
                           │ deactivated_at       │
                           └───────┬──────┬────────┘
                                   │      │
                         1         │      │        1
                                   │      │
                       ┌───────────┘      └─────────────┐
                       │                                │
                       ▼                                ▼
             ┌──────────────────┐             ┌──────────────────┐
             │     DEVICES      │             │  WORK_SESSIONS   │
             ├──────────────────┤             ├──────────────────┤
             │ id PK            │             │ id PK            │
             │ user_id FK       │             │ user_id FK       │
             │ device_identifier│             │ workplace_id FK  │
             │ platform         │             │ started_at       │
             │ app_version      │             │ ended_at         │
             │ status           │             │ start_latitude   │
             │ registered_at    │             │ start_longitude  │
             │ last_seen_at     │             │ start_accuracy   │
             └──────────────────┘             │ end_latitude     │
                                              │ end_longitude    │
                                              │ end_accuracy     │
                                              │ start_verif.     │
                                              │ end_verif.       │
                                              │ notes            │
                                              │ source           │
                                              │ created_at       │
                                              │ updated_at       │
                                              └────────┬─────────┘
                                                       │
                                                       │ N
                                                       │
                                                       │
                                                       │ 1
                                                       ▼
                                            ┌──────────────────┐
                                            │    WORKPLACES    │
                                            ├──────────────────┤
                                            │ id PK            │
                                            │ name             │
                                            │ latitude         │
                                            │ longitude        │
                                            │ radius_meters    │
                                            │ type             │
                                            │ status           │
                                            │ created_by FK    │
                                            │ created_at       │
                                            │ updated_at       │
                                            └──────────────────┘


                           ┌──────────────────────┐
                           │     AUDIT_LOGS       │
                           ├──────────────────────┤
                           │ id PK                │
                           │ actor_user_id FK     │
                           │ action               │
                           │ entity_type          │
                           │ entity_id            │
                           │ old_data             │
                           │ new_data             │
                           │ reason               │
                           │ created_at           │
                           └──────────────────────┘
```

---

# 5. Why These Tables?

## `auth.users`

This is Supabase's authentication table.

**We don't touch passwords ourselves.**

Supabase handles:

```text
password hashing
authentication
sessions
tokens
```

---

# 6. `profiles`

This contains information about the actual company employee.

Example:

```text
id:
UUID

employee_number:
EMP-1023

full_name:
Tala Abu Alamm

role:
EMPLOYEE

status:
ACTIVE
```

Role:

```text
EMPLOYEE
ADMIN
```

Status:

```text
ACTIVE
INACTIVE
```

Don't delete the row when someone leaves.

Instead:

```text
status = INACTIVE
deactivated_at = timestamp
```

---

# 7. `devices`

This is important for the anti-sharing idea we discussed.

Example:

```text
device
────────────────────
user_id
platform = ios
status = ACTIVE
registered_at
last_seen_at
```

Potential device states:

```text
ACTIVE
REVOKED
```

A user can eventually have multiple historical devices, but ideally only the currently authorized device(s) can perform attendance actions.

---

# 8. `workplaces`

Example:

```text
Event Hall A

latitude:
31.xxxxx

longitude:
35.xxxxx

radius:
100m

type:
TEMPORARY

status:
ACTIVE
```

Types could be:

```text
PERMANENT
TEMPORARY
```

Status:

```text
ACTIVE
INACTIVE
```

This allows:

> "This event ended, so deactivate the workplace."

without destroying its historical records.

---

# 9. `work_sessions`

This is the **heart of the entire system.**

Example:

```text
id:
UUID

user_id:
Tala

workplace_id:
Event Hall A

started_at:
2026-09-03 20:00 UTC

ended_at:
2026-09-04 00:00 UTC
```

Notice:

**No `date` column is necessary for the session itself.**

The date can be derived from timestamps.

This is important because:

```text
23:00 → 03:00
```

crosses midnight.

---

# 10. Location Data

For the start:

```text
start_latitude
start_longitude
start_accuracy
```

For the end:

```text
end_latitude
end_longitude
end_accuracy
```

However, remember our privacy decision:

We don't necessarily want to retain precise GPS coordinates forever.

We can later decide to:

* Store them temporarily
* Store rounded coordinates
* Or store only verification results

For V1, I'd initially keep the fields because they make debugging/testing significantly easier, then establish a retention policy before production.

---

# 11. Verification Fields

For example:

```text
start_verification = VERIFIED
```

Possible values:

```text
VERIFIED
MANUAL
UNKNOWN
```

Similarly:

```text
end_verification
```

This allows reports to distinguish:

```text
08:00 → 16:00
✓ Verified
```

from:

```text
06:00 → 15:00
⚠ Manual correction
```

---

# 12. `source`

I'd add this because it makes the system much easier to reason about.

Possible values:

```text
EMPLOYEE
ADMIN
SYSTEM
```

Example:

Normal clock-in:

```text
source = EMPLOYEE
```

Admin ends forgotten session:

```text
source = ADMIN
```

Future automatic process:

```text
source = SYSTEM
```

---

# 13. `audit_logs`

This is separate from sessions.

Suppose an admin changes:

```text
16:00
```

to:

```text
18:00
```

The session becomes:

```text
ended_at = 18:00
```

But audit log says:

```text
Admin Ahmad
changed session #123

16:00 → 18:00

Reason:
Approved overtime

2026-09-03 18:12 UTC
```

This is extremely important for a company handling employee hours.

---

# 14. One Database Constraint We Absolutely Need

An employee cannot have two active sessions.

Conceptually:

```text
Tala
Session A → ACTIVE
Session B → ACTIVE ❌
```

We need a **database-level constraint/index**, not merely:

```text
if (activeSession) ...
```

in Flutter.

This protects against:

* Double taps
* Network retries
* Two phones
* Race conditions
* Bugs
* Malicious requests

This is exactly the kind of thing Claude can help implement later—but we should design it first.

---

# 15. Another Important Rule

The client must **never send the official start time**.

Flutter can say:

```text
"I want to start working."

Here are my GPS coordinates:
31.xxxxx
35.xxxxx
```

Backend says:

```text
server time = 08:03:21 UTC

GPS valid = YES

Workplace = Event Hall A

Create session.
```

Same for ending.

This prevents someone from saying:

> "Actually I started 3 hours ago."

through a modified API request.

Manual corrections are a completely separate controlled workflow.

---

# 16. PHASE 1 Testing

Before touching the Flutter attendance UI, test Supabase itself.

Create test users:

```text
employee1
employee2
admin1
admin2
```

Then test:

### Authentication

* Employee can login.
* Invalid password fails.
* Inactive user cannot access protected application data.

### RLS

Employee 1:

```text
Can see Employee 1's sessions ✓
```

Employee 1:

```text
Can see Employee 2's sessions ❌
```

Employee:

```text
Can modify own role ❌
```

Employee:

```text
Can create admin ❌
```

Admin:

```text
Can view employee sessions ✓
```

Admin:

```text
Can modify sessions ✓
```

This testing is **more important than making the first beautiful Flutter screen**.

---

# 17. PHASE 2 — Flutter Foundation

Now create the Flutter project.

Structure:

```text
lib/
│
├── core/
│   ├── theme/
│   ├── constants/
│   ├── routing/
│   └── errors/
│
├── features/
│   ├── auth/
│   ├── home/
│   ├── sessions/
│   ├── history/
│   ├── reports/
│   ├── profile/
│   └── admin/
│
├── services/
│
└── main.dart
```

Connect:

```text
Flutter
   ↓
Supabase
   ↓
Auth
```

Implement:

* Splash
* Login
* Logout
* Auth state
* Employee/admin routing

### Test

Test:

```text
Employee login → Employee UI
Admin login → Admin UI
Logout → Login
Inactive account → blocked
```

**No GPS yet.**

---

# 18. PHASE 3 — Start / End Session

Now implement the core functionality without complicated GPS initially.

Employee:

```text
Home
 ↓
START WORK
 ↓
Backend
 ↓
Create session
 ↓
Working
```

Then:

```text
FINISH WORK
 ↓
Backend
 ↓
End session
```

### Test heavily

Test:

* Start
* End
* Double start
* End without active session
* Multiple sessions
* Cross-midnight
* App restart while working
* Logout while working
* Network interruption
* Rapid button presses

Only when this is stable do we add GPS.

---

# 19. PHASE 4 — GPS + Workplaces

Now implement:

```text
Admin
 ↓
Add workplace
 ↓
Capture current location
 ↓
Set radius
```

Then:

```text
Employee
 ↓
Start
 ↓
GPS
 ↓
Backend distance calculation
 ↓
Workplace detected
 ↓
Session
```

### Test physically

This phase should be tested **at the actual company's workplaces**.

Test:

* Inside radius
* Outside radius
* Boundary
* Poor accuracy
* GPS disabled
* Multiple nearby workplaces
* Temporary workplace
* Unknown location
* Manual fallback

This is one of the phases where real-world testing matters enormously.

---

# 20. PHASE 5 — History + Corrections

Add:

```text
History
```

and:

```text
Forgot to start
Forgot to end
```

Implement:

* Manual correction
* Notes
* Manual/verified status
* Employee history
* Session details

### Test

Example:

```text
Employee forgot start.

Actual:
06:00

Submitted:
08:30

Note:
Forgot to clock in.
```

Make sure the system **doesn't pretend this was a normal 06:00 automatic clock-in**.

---

# 21. PHASE 6 — Admin Dashboard

Now build:

```text
Admin
 ↓
Dashboard
```

Show:

```text
17 ACTIVE EMPLOYEES

Tala
Event Hall A
Since 08:03

Ahmad
Location B
Since 07:52

Sara
Event Hall C
Since 09:10
```

This is where Supabase Realtime becomes useful.

### Test

Employee starts:

```text
Employee phone
      ↓
Supabase
      ↓
Admin dashboard updates
```

No manual refresh ideally.

---

# 22. PHASE 7 — Admin Management

Implement:

### Employees

* Create
* Edit
* Deactivate
* Reactivate
* Device management

### Sessions

* View
* Edit
* End

### Workplaces

* Create
* Edit
* Activate/deactivate

### Admins

* Grant admin
* Remove admin

Every sensitive modification:

```text
Action
 ↓
Database
 ↓
Audit log
```

### Test permissions VERY aggressively.

---

# 23. PHASE 8 — Reports

Only now build reporting.

Employee:

```text
Reports
 ↓
August 2026
 ↓
Download
```

Admin:

```text
Reports
 ↓
Tala
 ↓
August 2026
 ↓
Excel/PDF/CSV
```

The report generator queries PostgreSQL.

Not Google Sheets.

---

# 24. PHASE 9 — Security & Hardening

This is where you stop thinking:

> "Does it work?"

and start asking:

> **"Can someone abuse it?"**

Test:

* RLS
* Authentication
* Authorization
* Token handling
* Device revocation
* API manipulation
* Changing user IDs
* Changing timestamps
* Changing workplace IDs
* Creating overlapping sessions
* Giving yourself admin privileges
* Accessing another employee's report
* Accessing inactive users
* Modifying audit logs

Then:

```text
Security review
 ↓
Fix
 ↓
Retest
```

---

# 25. PHASE 10 — Production

Only after all that:

```text
Development
      ↓
Staging
      ↓
Production
```

Configure:

* Production Supabase
* Database backups
* Monitoring
* App signing
* Apple Developer
* Google Play
* Production environment variables
* Privacy policy
* Terms if required
* App Store metadata
* Production testing

---

# 26. What Claude Should Do vs What YOU Should Do

This is important since you're trying to save money.

You don't need an expensive AI plan if you use it intelligently.

### YOU decide:

```text
Architecture
Database structure
Business rules
Security rules
UX decisions
Scope
What gets implemented
```

### Claude helps with:

```text
Flutter widgets
Boilerplate
Supabase migrations
CRUD
Models
Repositories
API calls
Tests
Refactoring
Debugging
Documentation
```

And for each phase:

```text
YOU
 ↓
Define exact task
 ↓
Claude
 ↓
Implement
 ↓
YOU
 ↓
Test
 ↓
Fix
 ↓
Next phase
```

---

# 27. The First Claude Prompt Should NOT Be "Build the App"

When we're ready, your first Claude task should be something more like:

> Read the project's requirements and architecture documents. We are currently implementing Phase 1 only. Do not create Flutter UI or implement attendance functionality yet. We are setting up Supabase database and authentication foundations. First inspect the repository and tell me what needs to be created. Do not modify files until I approve the plan.

That keeps Claude from going wild. 😂

Then we can progressively give it:

```text
Phase 1
 ↓
Database
 ↓
Test

Phase 2
 ↓
Auth
 ↓
Test

Phase 3
 ↓
Sessions
 ↓
Test
```

---

# 28. One Thing I Would Change From Our Earlier Architecture

I would **not start with Edge Functions everywhere**.

For V1:

```text
Flutter
   ↓
Supabase
   ↓
PostgreSQL
```

Use Supabase Edge Functions when we actually need server-side operations that shouldn't be exposed directly.

For example, workplace detection could eventually become:

```text
Flutter
 ↓
Edge Function
 ↓
Validate GPS
 ↓
PostgreSQL
 ↓
Create session
```

This gives us a cleaner security boundary for important attendance operations.

We can decide exactly which operations belong in Edge Functions when we design the API layer.

---

# 29. And One More Thing: Google Sheets

Your original idea was actually reasonable from a **business perspective** because companies love spreadsheets.

I'd make it:

```text
             PostgreSQL
            SOURCE OF TRUTH
                  │
        ┌─────────┼─────────┐
        ▼         ▼         ▼
      PDF       Excel      CSV
                            │
                            ▼
                     Google Sheets
                     (optional)
```

So if the company says:

> "We want a Google Sheet."

No problem.

Generate/export the data.

But **never make Google Sheets the attendance database**.

---

# 30. Our Immediate Next Step

I would **not touch Claude yet**.

I'd do this in order:

### Step A

Create the Supabase project.

### Step B

Create the database schema from the ERD above.

### Step C

Set up Supabase Auth.

### Step D

Create the RLS policies.

### Step E

Create test users:

```text
Admin
Employee A
Employee B
```

### Step F

Test the database/security manually.

### Step G

Create the Flutter project.

### Step H

Connect Flutter → Supabase.

### Step I

Only then bring Claude Code into the project.

And **before writing the SQL**, I'd make one more artifact: the **actual PostgreSQL schema specification**—every table, every column, exact data types, enums, foreign keys, indexes, constraints, triggers, and RLS rules. That becomes our single source of truth while you and Claude implement Phase 1.
