# 1. Our Development Strategy

I would build this in roughly **10 phases**:

```text
PHASE 0                                                     DONE
Requirements + Architecture                         
        ↓
PHASE 1                                                     DONE
Supabase + Database + Auth Foundation
        ↓
TEST                                                        DONE
        ↓
PHASE 2                                                     DONE
Flutter Foundation + Login
        ↓
TEST                                                        DONE
        ↓
PHASE 3                                                     DONE
Employee Start/End Session
        ↓
TEST                                                        DONE
        ↓
PHASE 4                                                     DONE
GPS + Workplace Detection
        ↓
TEST
        ↓
PHASE 5                                                     DONE
Employee History
        ↓
TEST
        ↓
PHASE 6                                                     currently here
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

### We finalize

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

### Test permissions VERY aggressively

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

### YOU decide

```text
Architecture
Database structure
Business rules
Security rules
UX decisions
Scope
What gets implemented
```

### Claude helps with

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
