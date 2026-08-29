# CLAUDE.md — Project Instructions

## 1. Project Overview

This is a full-stack work/project tracking application.

The application features are listed in [Project Plan](./project_plan.md)

The application should be built incrementally. Do not implement future features unless explicitly requested. we will be working in phases, you can see what each phase has and what phase are we in from the file [Project Phases](./project-phases.md)

---

# 2. Core Development Rule

## DO NOT OVERENGINEER

Keep the implementation:

* Simple
* Clean
* Readable
* Maintainable
* Beginner-friendly
* Appropriate for the current project size

Do NOT introduce:

* Unnecessary frameworks
* Unnecessary libraries
* Complex design patterns
* Microservices
* Unnecessary abstractions
* Premature optimization
* Extra database tables
* Extra API endpoints
* Features that were not requested

Prefer a simple solution that works correctly.

---

# 3. Before Writing Code

Before making changes:

1. Inspect the existing project structure.
2. Read the relevant existing files.
3. Understand how the current implementation works.
4. Reuse existing code when appropriate.
5. Identify the smallest set of files that need to change.

DO NOT blindly rewrite existing files.

DO NOT create duplicate implementations of something that already exists.

---

# 4. Token / Context Efficiency

The developer is using Claude Code on a limited plan.

Therefore, optimize for token efficiency.

### Rules

* Do not repeatedly read the same files unless necessary.
* Do not print entire large files when only a small section is relevant.
* Do not explain obvious code unnecessarily.
* Do not generate large amounts of documentation unless requested.
* Do not refactor unrelated code.
* Do not rewrite working code just to make it "cleaner."
* Do not add comments that simply restate what the code does.
* Keep responses concise.
* Prefer targeted file inspection over reading the entire repository.
* Make focused changes instead of broad rewrites.

When a task can be solved by changing 1–3 files, do not modify 10 files.

---

# 5. Change Scope

When the user asks for a specific feature or bug fix:

### Only change what is necessary

For example:

If the user says:

> Fix the login bug.

* Do NOT: Redesign the login page
* Do NOT: Rewrite authentication
* Do NOT: Refactor unrelated backend code
* Do NOT: Change the database schema
* Do NOT: Add new authentication providers

unless they are actually required.

---

# 6. Ask Before Major Changes

Before making a major architectural change, explain briefly what needs to change and why.

Ask for confirmation if the change would:

* Replace the current framework
* Replace the database
* Change the database schema significantly
* Delete existing functionality
* Introduce a major dependency
* Require a large rewrite

For normal implementation work, do not unnecessarily ask for confirmation.

---

# 7. Project Architecture

Use a clear separation between:

Frontend
→ UI, forms, interactions

Backend
→ Business logic, authentication, validation, API/routes

Database
→ Persistent data

Keep responsibilities separated.

Do not put database logic directly inside frontend code.

Do not put large amounts of business logic inside HTML/templates.

---

# 8. Database Rules

The database schema is already established.

Before modifying the database:

1. Inspect the current schema at [db schema](./db_files/db-schema-V2.sql).
2. Understand existing relationships.
3. Preserve existing data compatibility.
4. Only add/change tables or columns when necessary.

Never casually rename or delete:

* tables
* columns
* primary keys
* foreign keys

If a schema change is necessary, explain it first.

Avoid duplicate data when a relationship can be represented properly.

---

# 9. Authentication

Authentication must be implemented securely.

Never:

* Store plain-text passwords
* Return passwords in API responses
* Log passwords
* Hard-code secrets
* Put secrets directly into frontend code

Use environment variables for secrets and sensitive configuration.

Validate user input on the server.

Never trust frontend validation alone.

we are also using supabase .auth tables so almost everything is already done there, and we just need to connect it to our UI.

---

# 10. Security

Always consider basic security when implementing features.

Protect against:

* SQL injection
* XSS
* Authentication bypass
* Unauthorized access
* Invalid user input
* Exposing sensitive information

Use parameterized SQL queries.

Never construct SQL queries by directly concatenating user input.

Users must only be able to access data they are authorized to access.

---

# 11. Error Handling

Handle errors explicitly.

Do not silently ignore errors.

Errors should:

* Be meaningful
* Be logged appropriately on the backend
* Return safe messages to the frontend
* Avoid exposing sensitive internal information

Do not show stack traces or database internals to normal users.

---

# 12. Validation

Validate input on the backend even if the frontend already validates it.

Check:

* Data types
* Length limits
* Valid IDs
* Authorization
* Allowed status values

Reject invalid input cleanly.

---

# 13. Frontend

Keep the UI:

* Clean
* Responsive
* Simple
* Consistent

Reuse existing styles/components where possible.

Do not introduce a UI framework unless explicitly requested.

Do not redesign existing pages unless the user asks for a redesign.

some pages are already designed as images in the folder [UI Design](./UI_design/)

Avoid unnecessary animations or visual effects.

Prioritize usability over decoration.

it should be a simple to use app, the app users are aged between 35 - 55.

---

# 14. Backend API

Keep endpoints predictable and REST-like where appropriate.

Use appropriate HTTP methods:

GET
→ Retrieve data

POST
→ Create data

PUT/PATCH
→ Update data

DELETE
→ Delete data

Use appropriate HTTP status codes.

Return consistent response structures.

Do not create duplicate endpoints for the same operation.

---

# 15. Code Quality

Write code that another developer can understand quickly.

Prefer:

* Small functions
* Clear names
* Simple control flow
* Minimal duplication
* Explicit error handling

Avoid:

* Giant functions
* Deeply nested logic
* Clever one-liners
* Unnecessary abstractions
* Dead code
* Unused variables
* Unused dependencies

---

# 16. Dependencies

Before adding a dependency:

1. Check whether the functionality can be implemented with the existing stack.
2. Prefer existing dependencies.
3. If a new dependency is genuinely useful, explain why briefly.

Do not install libraries for trivial functionality.

Keep dependencies minimal.

---

# 17. Testing

After implementing a feature:

1. Run the relevant tests.
2. If there are no tests, perform an appropriate manual verification.
3. Check for compilation/build errors.
4. Check for obvious runtime errors.

Do not claim something works without verifying it.

When fixing a bug, reproduce or inspect the cause before changing code whenever possible.

---

# 18. Git Safety

Do not run destructive Git commands unless explicitly requested.

Never automatically run:

* `git reset --hard`
* `git clean -fd`
* destructive branch operations
* commands that discard uncommitted work

Do not overwrite user changes.

Before making large changes, inspect the current Git state when useful.

---

# 19. File Management

Keep the project organized.

Do not create unnecessary files.

Use the existing project structure.

Before creating a new file, check whether an existing file already serves the same purpose.

Avoid duplicate:

* handlers
* services
* components
* utilities
* database functions

---

# 20. Environment Variables

Never commit secrets.

Use `.env` or the project's existing configuration mechanism.

Typical sensitive values include:

* Database credentials
* API keys
* Authentication secrets
* Tokens
* Private keys

If `.env` is used, ensure it is included in `.gitignore`, if its not there and its required for database or so, create a one with meaningful secret names, and ask the user to fill them out with their real values.

---

# 21. When Debugging

Follow this process:

1. Identify the exact error.
2. Locate the relevant code.
3. Determine the root cause.
4. Make the smallest reasonable fix.
5. Run the relevant test/build.
6. Verify the result.

Do not randomly change multiple files hoping the problem disappears.

Do not rewrite an entire subsystem to fix a localized bug.

---

# 22. When the User Gives an Error

If the user provides an error message:

* Treat the error as the primary source of truth.
* Inspect the relevant code.
* Explain the root cause briefly.
* Fix the root cause.
* Verify the fix.

Do not immediately propose a completely different architecture.

---

# 23. Working Style

The user prefers to build the application step-by-step.

Work in phases.

Do not jump ahead.

If the current task is:

> Build registration

Do not also build:

* admin dashboards
* notifications
* homepage

unless explicitly requested.

Finish the requested feature cleanly before moving to the next feature.

---

# 24. Communication Style

Keep responses concise and practical.

When making changes, report:

### What changed

Short summary.

### Files changed

List only relevant files.

### Verification

Mention what was tested/run.

### Next step

Only suggest the immediate logical next step.

Avoid long explanations unless the user asks for them.

---

# 25. Important Rule: Do Not Guess

If existing project code contradicts these instructions:

→ Existing working project code takes priority unless it creates a security or correctness problem.

If something is genuinely ambiguous and could lead to a significant implementation difference:

→ Ask the user.

Do not invent requirements.

---

# 26. Definition of Done

A feature is considered complete only when:

* The requested functionality is implemented.
* Existing functionalities still works.
* Relevant validation exists.
* Errors are handled.
* Security basics are respected.
* The project builds/runs successfully.
* Relevant tests or manual verification have been performed.
* No unnecessary files or dependencies were introduced.

---

# 27. Final Rule

BUILD LESS, BUT BUILD IT WELL.

Do not optimize for the amount of code written.

Optimize for:

Correctness
→ Simplicity
→ Maintainability
→ Security
→ Verification

Only implement what is needed for the current task.
