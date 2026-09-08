 Now the final report.

  Ran 1 shell command

PROD Bootstrap — Final Report

Everything below is a static build/review. Nothing was executed against DEV or PROD.

A. Generated files

db_files/prod-bootstrap/ — 12 files, 2,722 lines total:

┌──────────────────────────────────┬───────┬──────────────────────────────────┐
│               File               │ Lines │             Purpose              │
├──────────────────────────────────┼───────┼──────────────────────────────────┤
│ 001_extensions.sql               │ 28    │ pgcrypto                         │
├──────────────────────────────────┼───────┼──────────────────────────────────┤
│ 002_types.sql                    │ 58    │ 9 enum types                     │
├──────────────────────────────────┼───────┼──────────────────────────────────┤
│ 003_tables.sql                   │ 457   │ 7 tables, final                  │
│                                  │       │ columns/constraints folded in    │
├──────────────────────────────────┼───────┼──────────────────────────────────┤
│ 004_indexes.sql                  │ 118   │ 19 indexes (final DEV-approved   │
│                                  │       │ set)                             │
├──────────────────────────────────┼───────┼──────────────────────────────────┤
│ 005_helper_functions.sql         │ 156   │ 6 helper/trigger functions       │
├──────────────────────────────────┼───────┼──────────────────────────────────┤
│ 006_triggers.sql                 │ 27    │ 4 triggers                       │
├──────────────────────────────────┼───────┼──────────────────────────────────┤
│ 007_rls_policies.sql             │ 285   │ RLS enable + 16 policies + table │
│                                  │       │  grants                          │
├──────────────────────────────────┼───────┼──────────────────────────────────┤
│ 008_session_functions.sql        │ 791   │ 10 session RPCs (final versions) │
├──────────────────────────────────┼───────┼──────────────────────────────────┤
│ 009_workplace_functions.sql      │ 39    │ 1 RPC (find_nearby_workplaces)   │
├──────────────────────────────────┼───────┼──────────────────────────────────┤
│ 010_admin_functions.sql          │ 472   │ 6 admin/super-admin RPCs         │
├──────────────────────────────────┼───────┼──────────────────────────────────┤
│ 011_issue_functions.sql          │ 145   │ 3 issue-report RPCs              │
├──────────────────────────────────┼───────┼──────────────────────────────────┤
│ 012_password_reset_functions.sql │ 146   │ 3 password-reset RPCs            │
└──────────────────────────────────┴───────┴──────────────────────────────────┘

B. Execution order

Run 001 → 012 in that exact numeric order. This deliberately differs from the illustrative order in your request (which put RLS at 005, helpers at 006) — I swapped them because policies call is_admin()/is_active_user(), which must exist first on an empty database.

C. What each file creates

- 001 — pgcrypto extension (needed by 3 password-hashing functions in 008/010).
- 002 — user_role, user_status, device_platform, device_status, workplace_type, workplace_status, verification_method, session_source, issue_status.
- 003 — profiles, devices, workplaces, work_sessions, audit_logs, issue_reports, password_reset_requests, each with every constraint from every historical file folded into one CREATE TABLE (no incremental ALTER TABLEs needed on a fresh DB), plus the 7 DEV-approved length checks.
- 004 — all 19 final indexes, including the 4 new partial indexes, excluding the dropped redundant one.
- 005 — _distance_meters, is_admin, is_super_admin, is_active_user, set_updated_at, handle_new_user.
- 006 — the 3 updated_at triggers + on_auth_user_created.
- 007 — RLS enabled on all 7 tables, all 16 policies (using the final narrowed profiles_update_admin), table-level grants/revokes.
- 008 — every work-session RPC, final versions only.
- 009 — find_nearby_workplaces.
- 010 — admin_set_employee_status, admin_create_employee, admin_reset_employee_password, super_admin_set_account_role, super_admin_set_admin_status, super_admin_reset_admin_password.
- 011 — report_issue, admin_list_open_issues, admin_resolve_issue.
- 012 — request_password_reset, admin_list_open_password_reset_requests, admin_resolve_password_reset_request.

D. Complete inventory

- Tables (7): profiles, devices, workplaces, work_sessions, audit_logs, issue_reports, password_reset_requests
- Types (9): user_role, user_status, device_platform, device_status, workplace_type, workplace_status, verification_method, session_source, issue_status
- Indexes (19): listed in full in 004_indexes.sql — 3 profiles, 3 devices, 2 workplaces, 6 work_sessions, 3 audit_logs, 1 issue_reports, 1 password_reset_requests
- Functions (29): 6 helpers/triggers + 23 client-facing RPCs
- Triggers (4): profiles_set_updated_at, workplaces_set_updated_at, work_sessions_set_updated_at, on_auth_user_created
- RLS policies (16): across all 7 tables, RLS enabled on every one
- Extensions (1): pgcrypto
- Views: none exist in the source, none created

E. Flutter RPC coverage

Grepped every .rpc('...') call in lib/services/*.dart — 23 RPCs called, 23 covered, exact match, nothing extra or missing:

┌─────────────────────────────────────────┬────────────────┐
│                   RPC                   │ Bootstrap file │
├─────────────────────────────────────────┼────────────────┤
│ start_work_session                      │ 008            │
├─────────────────────────────────────────┼────────────────┤
│ end_work_session                        │ 008            │
├─────────────────────────────────────────┼────────────────┤
│ end_work_session_for_logout             │ 008            │
├─────────────────────────────────────────┼────────────────┤
│ admin_active_sessions                   │ 008            │
├─────────────────────────────────────────┼────────────────┤
│ admin_unverified_sessions               │ 008            │
├─────────────────────────────────────────┼────────────────┤
│ admin_verify_session                    │ 008            │
├─────────────────────────────────────────┼────────────────┤
│ admin_end_work_session                  │ 008            │
├─────────────────────────────────────────┼────────────────┤
│ admin_edit_work_session                 │ 008            │
├─────────────────────────────────────────┼────────────────┤
│ admin_delete_work_session               │ 008            │
├─────────────────────────────────────────┼────────────────┤
│ list_my_sessions_for_month              │ 008            │
├─────────────────────────────────────────┼────────────────┤
│ find_nearby_workplaces                  │ 009            │
├─────────────────────────────────────────┼────────────────┤
│ admin_set_employee_status               │ 010            │
├─────────────────────────────────────────┼────────────────┤
│ admin_create_employee                   │ 010            │
├─────────────────────────────────────────┼────────────────┤
│ admin_reset_employee_password           │ 010            │
├─────────────────────────────────────────┼────────────────┤
│ super_admin_set_account_role            │ 010            │
├─────────────────────────────────────────┼────────────────┤
│ super_admin_set_admin_status            │ 010            │
├─────────────────────────────────────────┼────────────────┤
│ super_admin_reset_admin_password        │ 010            │
├─────────────────────────────────────────┼────────────────┤
│ report_issue                            │ 011            │
├─────────────────────────────────────────┼────────────────┤
│ admin_list_open_issues                  │ 011            │
├─────────────────────────────────────────┼────────────────┤
│ admin_resolve_issue                     │ 011            │
├─────────────────────────────────────────┼────────────────┤
│ request_password_reset                  │ 012            │
├─────────────────────────────────────────┼────────────────┤
│ admin_list_open_password_reset_requests │ 012            │
├─────────────────────────────────────────┼────────────────┤
│ admin_resolve_password_reset_request    │ 012            │
└─────────────────────────────────────────┴────────────────┘

F. Historical files/sections intentionally excluded

- fix-employee-id-format.sql — entirely excluded. It re-adds profiles_employee_id_format as NOT VALID, a retrofit for DEV's pre-existing non-conforming rows. The bootstrap's 003_tables.sql already declares the identical constraint at CREATE TABLE time, which is automatically valid on an empty table — this file would be pure redundant noise on a fresh database.
- phase7-issue-reports.sql's CREATE TYPE issue_status / CREATE TABLE issue_reports / RLS policies / grants — excluded as exact duplicates of db-schema-V2.sql's own addendum section. Only its 3 functions were carried into 011_issue_functions.sql.
- Every superseded intermediate function version — not created at all (going straight to final state): phase3's no-arg start_work_session()/end_work_session(); phase4's non-role-aware start_work_session/end_work_session; phase6's end_work_session (pre-role-aware); phase6's original admin_unverified_sessions (pre-ended_by); phase6-fix-history-verified-by.sql's list_my_sessions_for_month (had the ambiguous-column bug, fixed by fix-list-my-sessions-ambiguous-column.sql); the original (unnarrowed) profiles_update_admin policy from db-schema-V2.sql, superseded by phase7-role-management.sql's version.
- db_tables_exp.md, testing_db_v1.md — pure documentation/manual test scripts, contain zero additional executable schema and explicitly include sample test-user data that must never reach PROD.
- All incremental ALTER TABLE ADD COLUMN/ADD CONSTRAINT statements (verified_by, ended_by, end_manual_location_name, the verified_by/ended_by FKs) — folded directly into the relevant CREATE TABLE in 003_tables.sql since a fresh install has no "before" state to alter from.

G. Dependency/migration risks

1. No other duplicate-object conflicts found beyond the two already known (issue_reports, fix-employee-id-format.sql) — confirmed by grepping every file for CREATE TABLE/CREATE TYPE/DROP TABLE/TRUNCATE across all 16 source files.
2. 6 functions have no explicit GRANT EXECUTE (is_admin, is_super_admin, is_active_user, _distance_meters, set_updated_at, handle_new_user) — this exactly matches every source file (none of them grant these either). They work because Postgres grants EXECUTE to PUBLIC by default on new functions, and none of these are ever called directly via .rpc() from Flutter (they're only called internally by RLS policies, other functions, or the trigger mechanism). This is inherited DEV behavior, not something introduced here — flagging it because it's a silent dependency on Postgres' default privilege behavior rather than an explicit grant.
3. pgcrypto's installed schema is assumed to be extensions (Supabase's platform default when no schema is specified), matching the search_path = public, extensions in admin_create_employee, admin_reset_employee_password, and super_admin_reset_admin_password. This has always been implicit, never explicitly verified against a schema name in any source file — if the empty PROD project's platform default ever differs, those 3 password functions would fail with a "function crypt() does not exist" error, easily fixed by adjusting the extension's schema.
4. admin_create_employee's instance_id fallback: it looks up an existing auth.users row's instance_id first, falling back to the all-zero UUID if none exists yet. On a truly empty PROD project, this fallback path is what fires for the very first employee ever created — matches Supabase's own default instance_id convention, so no actual risk, just worth knowing this code path will be exercised on PROD in a way it never is on DEV (where rows already exist).
5. The very first admin/super_admin account isn't created by any SQL file here — every admin-creation path in the schema (admin_create_employee) only ever produces role = 'employee' accounts. Bootstrapping PROD's first super_admin requires a manual step outside this SQL (creating a user via the Supabase Dashboard/Auth admin API, then manually setting that profile's role to super_admin) — not a defect, just a manual step to plan for, since no RPC can grant the first admin role by design (there's no bootstrap/seed function, and none should be added without your sign-off since that would be new logic).

H. Confirmations

- DEV was not modified — no connection, query, or statement was run against the DEV project in this task; only the SQL files in db_files/ were read.
- PROD was not modified — no connection was made to the PROD project at all.
- No data included — grepped every file for stray INSERT INTO statements outside of function bodies (which insert application data at runtime, not seed data); none found.
- No credentials included — grepped every file for the DEV Supabase URL, project ref, publishable key, and generic credential-shaped strings; none found.

I. Verdict

READY FOR MANUAL PROD EXECUTION, with two things to plan for before/after running it:
1. After running 001–012, manually create the first super_admin account (Supabase Dashboard → Authentication → Add User, then set that profile's role to super_admin directly in the table editor, since no RPC exists to do this and none should be invented here).
2. If step 010/012's password functions ever fail with a missing-crypt()-function error, it means PROD's pgcrypto installed into a schema other than extensions — check via \dx or the Database → Extensions page and adjust the affected functions' search_path accordingly.

No files have been committed or pushed.

✻ Crunched for 9m 11s · done 8:54 PM
