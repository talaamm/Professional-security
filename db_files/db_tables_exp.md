
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
