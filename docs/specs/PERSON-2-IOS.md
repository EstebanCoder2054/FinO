# PERSON 2 - Native iOS System Experience

## Responsibility

Own the system-level expense entry experience: WidgetKit Control, App Intent, voice capture, Speech framework, and the path from system surface to backend request.

## Primary Files

- `ios/FinanceAgentWidget/`
- `ios/FinanceAgent/Features/Voice/`
- shared iOS networking models needed by the voice flow

## Dependencies

- API contract in `docs/API.md`
- Backend base URL and auth token provider
- Apple platform requirements for WidgetKit Controls and App Intents

## Tasks

1. Create the Xcode project foundation.
2. Add WidgetKit extension.
3. Implement Add Expense Control.
4. Implement App Intent entry point.
5. Implement microphone and speech recognition permissions.
6. Implement voice state machine: idle, requesting permission, listening, transcribing, submitting, success, failure.
7. Connect transcribed text to `POST /api/expenses`.
8. Test on a real iPhone where system surfaces are available.

## Acceptance Criteria

The user can initiate expense capture from a supported iOS system surface and reach:

```text
voice -> text -> backend
```

without using a traditional chat UI.

## Integration Points

- PERSON 1 provides API and auth validation behavior.
- PERSON 3 provides session/auth state and native confirmation/history UI.

## Do Not Modify Without Coordination

- backend API contract
- Supabase application tables
- native dashboard IA outside the voice/system flow
