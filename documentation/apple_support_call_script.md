# Apple Developer Support Call — Prep Sheet

Use this when you call. Section 1 is what they'll ask to verify you. Section 2 is what
to say, in order. Section 3 is the fallback if the first agent can't help.

---

## 1. Identification details (have these ready before dialing)

| Item | Value |
| --- | --- |
| App Name | Professional Security |
| App Apple ID | 6810784116 |
| Bundle ID | com.halabi.professionalsecurity |
| Current Version / Build | 1.1.2 (build 11) |
| Build referenced in Apple's warning email | 1.1.2, Build 4 |
| Developer Program membership type | Paid, $100/year |
| Account Holder | Noor (also Admin) |
| Apple ID email used to log into developer account | ___ (fill in) |
| Team ID | ___ (App Store Connect → Membership Details, or Xcode → Account) |
| D-U-N-S / Legal Entity name (if Organization account) | we dont have its Individual |
| Account type | Individual / Organization — Individual |
| Prior support ticket/case numbers | ___ (fill in — list every case number from the 4+ tickets you sent) |
| Date issue started | ~10 days before today |
| Date Tax + Bank info was completed and agreements turned Active | September 23rd, 2026 |

Have Noor on the call, or on standby to be conferenced in — Apple will very likely only
discuss account/contract details with the Account Holder, not a delegate.

---

## 2. What to say (read roughly in this order)

**Opening — state the category clearly so you get routed correctly:**

> "This is an Agreements, Tax, and Banking / Contracts issue blocking TestFlight
> distribution, not a technical/API bug. My previous tickets seem to have been routed
> as general technical support and never answered — I'd like this escalated to the
> Contracts/Account team."

**The problem, in one paragraph:**

> "Our app 'Professional Security', App Apple ID 6810784116, bundle ID
> com.halabi.professionalsecurity, cannot be distributed via TestFlight. Every call to
> the App Store Connect API to submit a build for testing returns error 422: 'Beta
> contract is missing for the app.' On the App Store Connect website, trying to save
> Test Information or add an External Testing group fails with 'There was an error
> processing your request. Please try again later.' On the tester's iPhone, TestFlight
> shows 'The requested app is not available or doesn't exist.'"

**Why it should already be resolved (this is the key point — say it explicitly):**

> "The root cause we identified was that our Paid Apps Agreement was stuck in
> 'Pending User Info' because our U.S. Tax Questionnaire and bank account details were
> incomplete. I am the Account Holder. I personally completed both the Tax
> Questionnaire and the bank information, and both the Free Apps Agreement and the
> Paid Apps Agreement now show as fully Active and green in Agreements, Tax, and
> Banking. This has been the case for [X days/hours] now. I have not seen any separate
> banner or prompt asking me to re-accept anything else — no pending Program License
> Agreement notice, nothing. Despite that, the backend still returns the same 422
> 'Beta contract is missing' error, as if the contract state has not synced."

**Evidence it's not a code/build problem (pre-empt the usual first troubleshooting questions):**

> "This is not a build or code issue. Our CI pipeline builds and validates the IPA
> successfully every time — we've confirmed this by disabling the automatic TestFlight
> submission step and letting the build complete on its own, which it does with no
> errors. We've also incremented build numbers, reset export compliance settings, and
> deleted and recreated our tester groups — testers show as 'Accepted' but the app
> still shows 'No Builds Available' next to their names, even though builds are marked
> 'Testing' and green in App Store Connect. So the block is specifically at the
> account/contract level, not the binary."

**The ask — be explicit about what you want them to do:**

> "I need someone from the Contracts or Account Support team to manually check why
> the Beta/TestFlight contract status hasn't synced with our now-Active agreements,
> and force a resync on our account. Can you escalate this to that team now, or give
> me a case number I can reference so it doesn't go unanswered like the previous
> tickets?"

**Before hanging up:**

- Get a **case/ticket number** for this call specifically.
- Ask for an **estimated response time**.
- Ask if there's a **direct escalation path** (e.g., Apple Developer Program "Priority
  Support" if your account has it, or a callback from a specialist) rather than the
  general queue.
- Confirm the best way to follow up (phone vs. reply on the same ticket thread) so you
  don't restart from zero again.

---

## 3. If the first agent can't help

Front-line phone support often can only read account status, not act on contract sync
issues. If they say "everything looks fine on our end" and try to close the call:

> "I understand the dashboard shows Active, but the TestFlight backend is clearly not
> reading that same status — that's exactly the discrepancy I need investigated. Can
> you escalate to a Developer Program Account Specialist or the Contracts team rather
> than closing this as resolved?"

If they still won't escalate, ask explicitly for a **supervisor** or to have the case
marked for **Contracts team review**, and reference the prior ticket numbers to show
this has been unresolved for 10+ days with no reply.
