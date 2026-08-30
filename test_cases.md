13. Testing

After implementation run:

flutter analyze
relevant Flutter tests
any backend/database tests that can be run locally

Then manually test:

Start

Employee not working
→ Start Work
→ GPS permission
→ recognized workplace
→ session created
→ Working screen

End

Working
→ End Work
→ GPS verification
→ session ended
→ Home shows not working

Recovery

Start session
→ close app
→ reopen app
→ Working state restored

Duplicate start

Already working
→ press Start Work
→ must not create another session

GPS failure

GPS unavailable
→ manual location flow
→ session records manual verification

Midnight

Start a session late at night
→ end after midnight
→ verify timestamps and duration are correct

Security

Verify the Flutter client cannot simply modify another employee's session or choose another employee's employee_id.