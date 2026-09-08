## Phase 1.5 — Test the Supabase database

### 1. First: check that the tables exist

In Supabase:

we see:

```text
profiles
devices
workplaces
work_sessions
audit_logs
```

And under `profiles`, we have approximately:

| Column           | Type        | Important       |
| ---------------- | ----------- | --------------- |
| `employee_id`    | text        | PK              |
| `auth_user_id`   | uuid        | FK → auth.users |
| `full_name`      | text        |                 |
| `role`           | user_role   |                 |
| `status`         | user_status |                 |
| `created_at`     | timestamptz |                 |
| `updated_at`     | timestamptz |                 |
| `deactivated_at` | timestamptz |                 |

those exist, good!

---

# 2. Test the basic database constraints

```sql
insert into public.workplaces (
    name,
    latitude,
    longitude,
    radius_meters,
    type,
    status,
    created_by
)
values (
    'Test Workplace',
    31.7683,
    35.2137,
    100,
    'permanent',
    'active',
    'TEST'
);
```

failed. correct,
Because:

```txt
created_by
    ↓
profiles.employee_id

and TEST doesn't exist.

That's our foreign key working correctly.
```

 error:

```txt
Failed to run sql query: ERROR:  23503: insert or update on table "workplaces" violates foreign key constraint "workplaces_created_by_fkey"
DETAIL:  Key (created_by)=(TEST) is not present in table "profiles".
```

---

# 3. Create your first real test user

Now let's test the authentication side.

Go to: **Supabase → Authentication → Users**

Created a user manually.

```text
Email:
halabinoor18@gmail.com

Password:
password123
```

FAILED

it needs an email, we will just use: and turn off email confirmation. [chat on gemini](https://share.gemini.google/zWYm59sKsJBP)

```dart
Future<void> loginWithEmployeeId(String employeeId, String password) async {
  // Append internal dummy domain behind the scenes
  final dummyEmail = '$employeeId@internal.app';

  final response = await supabase.auth.signInWithPassword(
    email: dummyEmail,
    password: password,
  );
}
```

worked with query:

```sql
-- Creates an auth user with the exact metadata required by your trigger
insert into auth.users (
  id,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_user_meta_data,
  aud,
  role
)
values (
  gen_random_uuid(),
  'test@company.com',
  crypt('password123', gen_salt('bf')),
  now(),
  '{"employee_id": "EMP-9999", "full_name": "Test User"}'::jsonb,
  'authenticated',
  'authenticated'
);
```

worked ! got:

```txt
Test User
test@company.com

User UID
357ba98a-77c2-4fda-8655-c51df27e520e


Created at
-

Updated at
-

Invited at
-

Confirmation sent at
-

Confirmed at
29 Aug, 2026 15:21


Last signed in
-

SSO

Provider Information
The user has the following providers

Reset password
Send a password recovery email to the user

Send password recovery
Send magic link

Send a passwordless magic link to the user

Send magic link
Danger zone

Be wary of the following features as they cannot be undone.

Remove MFA factors
Removes all MFA factors associated with the user

Remove MFA factors
Ban user
Revoke access to the project for a set duration

Ban user
Delete user
User will no longer have access to the project
```

---

# 4. make sure the user exists

```sql
select *
from public.profiles;
```

i got:

```text
employee_id | auth_user_id | full_name      | role     | status | created at | updated_at | deactivated_at
----------------------------------------------------------------
EMP-9999     | 8e9f...      | Test User  | employee | active | created at | updated_at | NULL
```

🎉

That's our first complete user.

---

# 5. Create a test admin

Do the same thing with another Auth user.

```sql
-- Creates an auth user with the exact metadata required by your trigger
insert into auth.users (
  id,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_user_meta_data,
  aud,
  role
)
values (
  gen_random_uuid(),
  'admin@professional-security.com',
  crypt('password123', gen_salt('bf')),
  now(),
  '{"employee_id": "123456789", "full_name": "Test admin"}'::jsonb,
  'authenticated',
  'authenticated'
);

update public.profiles
set role = 'admin'
where employee_id = '125678';
```

And one super admin: -done

This gives us three test identities:

---

# 6. Now test workplaces

Since `ADMIN001` exists:

```sql
insert into public.workplaces (
    name,
    latitude,
    longitude,
    radius_meters,
    type,
    status,
    created_by
)
values (
    'Test Workplace',
    31.7683,
    35.2137,
    100,
    'permanent',
    'active',
    '125678' --the admin
);
```

Then:

```sql
select *
from public.workplaces;
```

PERFECTLY ADDED!

---

# 7. Test the employee → workplace → session relationship

Now manually create a test session:

```sql
insert into public.work_sessions (
    employee_id,
    workplace_id,
    started_at,
    start_latitude,
    start_longitude,
    start_accuracy,
    start_verification,
    source
)
select
    '12345678',
    '71fa90d3-0980-4f2f-8a72-7a6fb207d38c',
    now(),
    31.7683,
    35.2137,
    10,
    'verified',
    'employee'
from public.workplaces
where name = 'Test Workplace'
limit 1;
```

Then:

```sql
select *
from public.work_sessions;
```

PERFECT!

And **`ended_at = NULL` means currently working.**

---

# 8. Now test the most important constraint

Try creating another active session for `TEST001`:

```sql
insert into public.work_sessions (
    employee_id,
    workplace_id,
    started_at,
    start_verification,
    source
)
select
    'TEST001',
    id,
    now(),
    'verified',
    'employee'
from public.workplaces
where name = 'Test Workplace'
limit 1;
```

It should **FAIL**. and it faile with error: "Failed to run sql query: ERROR:  23505: duplicate key value violates unique constraint "work_sessions_one_active_per_employee"
DETAIL:  Key (employee_id)=(12345678) already exists."

You'll get a duplicate/unique constraint error because:

```text
TEST001
   │
   └── already has ended_at = NULL
```

This is exactly what we want.

The database is protecting us even if the Flutter application has a bug.

---

# TO BE TESTED LATER

---
---
---
---
---
---
---
---
---
---
---
---
---
---
---
---
---
---
---
---
---
---
---
---
---
---
---
---

# 9. End the session

Now:

```sql
update public.work_sessions
set
    ended_at = now(),
    end_latitude = 31.7683,
    end_longitude = 35.2137,
    end_accuracy = 10,
    end_verification = 'verified'
where employee_id = 'TEST001'
  and ended_at is null;
```

Then:

```sql
select
    employee_id,
    started_at,
    ended_at
from public.work_sessions;
```

You should have:

```text
TEST001 | 08:00 | 16:00
```

Now you can create another session.

This verifies:

```text
multiple sessions per day
        ✅

only one active session at a time
        ✅
```

---

# 10. Test crossing midnight

This is another important one because you specifically wanted it.

```sql
insert into public.work_sessions (
    employee_id,
    workplace_id,
    started_at,
    ended_at,
    start_verification,
    end_verification,
    source
)
select
    'TEST001',
    id,
    '2026-09-03 23:00:00+00',
    '2026-09-04 03:00:00+00',
    'verified',
    'verified',
    'employee'
from public.workplaces
where name = 'Test Workplace'
limit 1;
```

Then:

```sql
select
    employee_id,
    started_at,
    ended_at,
    ended_at - started_at as duration
from public.work_sessions
where employee_id = 'TEST001';
```

You should get:

```text
4:00:00
```

Perfect.

---

# 11. Test soft deletion

Don't actually delete the employee.

Instead:

```sql
update public.profiles
set
    status = 'inactive',
    deactivated_at = now()
where employee_id = 'TEST001';
```

Then:

```sql
select
    employee_id,
    full_name,
    status,
    deactivated_at
from public.profiles
where employee_id = 'TEST001';
```

You should see:

```text
TEST001
Test Employee
inactive
2026-...
```

But their:

```text
work_sessions
devices
audit_logs
```

still exist.

That's exactly what we want.

---

# 12. Test the authentication relationship

This one is particularly important.

Go to:

**Authentication → Users**

You should have:

```text
Auth User
    ↓
UUID
    ↓
profiles.auth_user_id
    ↓
TEST001
```

That's the bridge between Supabase Auth and your application.

---

# 13. Test RLS

This is where we need to be careful.

Our intended security model is:

### Employee

```text
Can see:
    own profile
    own devices
    own sessions
    active workplaces

Cannot see:
    other employees
    other employees' sessions
    audit logs
```

### Admin

```text
Can see:
    all employees
    all sessions
    all workplaces
    devices
    audit logs
```

### Super Admin

```text
Everything an admin can do
+
manage administrators
```

**Do not skip this test.**

A time-tracking application contains employee attendance data, so we don't want a Flutter bug accidentally exposing everyone's records.

---

# 14. One important thing before Claude

There's actually one piece I would add **before we start building login**:

## Secure database functions

Right now we intentionally didn't give normal users:

```text
INSERT work_sessions
UPDATE work_sessions
```

That's good.

But eventually Flutter needs a way to say:

```text
START WORK
```

without getting direct permission to manipulate the table.

So we'll create something like:

```text
start_work_session()
end_work_session()
```

The function can then check:

```text
Who are you?
       ↓
Are you active?
       ↓
Is your device authorized?
       ↓
Are you already working?
       ↓
Where are you?
       ↓
Which workplace?
       ↓
Is GPS acceptable?
       ↓
Create session
       ↓
SERVER TIME
```

**That's the next backend task after testing the raw schema.**

---

# Then we move to Phase 2 🚀

Once these database tests pass, I would start Claude with:

### Phase 2 — Authentication

Only build:

```text
Splash Screen
      ↓
Check Supabase Auth
      ↓
 ┌────┴────┐
 ↓         ↓
Logged     Not logged
in         in
 ↓         ↓
Home       Login
           ↓
        Register
```

And the first Flutter/Supabase milestone would be:

### Employee

* Login
* Register
* Stay logged in
* Logout
* Fetch own profile
* Display employee name
* Display employee ID
* Display role
* Handle inactive account

### Admin

* Login
* Detect admin role
* Open admin dashboard

**No GPS. No clock-in. No reports yet.**

Get authentication working perfectly first.

---

## Your development roadmap from here

I'd structure your Claude development exactly like this:

```text
PHASE 1
Database
✅ Schema
✅ Tables
✅ Relationships
✅ Constraints
✅ RLS

        ↓

PHASE 1.5
Database Testing       ← YOU ARE HERE
⬜ Test users
⬜ Test roles
⬜ Test workplaces
⬜ Test sessions
⬜ Test midnight sessions
⬜ Test multiple sessions
⬜ Test active-session constraint
⬜ Test soft deletion
⬜ Test RLS

        ↓

PHASE 2
Authentication
⬜ Flutter project
⬜ Supabase connection
⬜ Splash
⬜ Login
⬜ Registration
⬜ Persistent login
⬜ Logout
⬜ Profile loading
⬜ Role routing

        ↓

PHASE 3
Employee Home
⬜ Current status
⬜ Start Work
⬜ End Work
⬜ Current workplace
⬜ Current duration

        ↓

PHASE 4
GPS
⬜ Location permission
⬜ GPS acquisition
⬜ Workplace detection
⬜ Radius calculation
⬜ Manual location fallback

        ↓

PHASE 5
Admin Dashboard
⬜ Active employees
⬜ Who is working
⬜ Where
⬜ Since when
⬜ Employee management

        ↓

PHASE 6
Corrections
⬜ Forgot start
⬜ Forgot end
⬜ Manual corrections
⬜ Admin ending session
⬜ Audit logs

        ↓

PHASE 7
Reports
⬜ Monthly hours
⬜ Employee reports
⬜ CSV/Excel/PDF
⬜ Historical reports

        ↓

PHASE 8
Hardening
⬜ Security testing
⬜ Edge cases
⬜ Device handling
⬜ Error handling
⬜ Performance
⬜ Production preparation

        ↓

PHASE 9
App Store / Play Store
⬜ iOS
⬜ Android
⬜ Production Supabase
⬜ Monitoring
⬜ Release
```

### And one very important rule for working with Claude

Don't give Claude:

> "Build my employee attendance app."

Give it **one phase at a time**.

For example:

> "We have an existing Flutter project connected to this Supabase project. Implement Phase 2 authentication only. Do not implement GPS, attendance, reports, or admin features yet..."

That dramatically reduces the chance of Claude creating a giant tangled codebase.

**So for right now: run the database tests above. If they all pass, we're ready to design the secure Auth functions and then give Claude the Phase 2 prompt.**
