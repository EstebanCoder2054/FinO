# PERSON 3 - Native iOS Product UI / Auth / QA

## Responsibility

Own the native SwiftUI product shell, authentication UI, session handling, expense history, totals, confirmations, integration QA, and demo readiness.

## Primary Files

- `ios/FinanceAgent/`
- `docs/TEAM.md`
- manual QA checklists and demo notes

## Dependencies

- API contract in `docs/API.md`
- Supabase Auth configuration
- Voice/control integration from PERSON 2
- Expense persistence from PERSON 1

## Tasks

1. Build native app shell and navigation.
2. Implement sign in, sign up if needed, and sign out.
3. Store sensitive auth material securely.
4. Build home screen with total spending, recent expenses, and simple category summary.
5. Build expense list and confirmation UI.
6. Integrate API client and authenticated requests.
7. Cover loading, empty, and error states.
8. Verify accessibility basics.
9. Maintain manual E2E demo checklist.

## Acceptance Criteria

A user can:

```text
authenticate -> see app -> record expense -> see confirmation -> see expense in history
```

## Integration Points

- PERSON 1 backend endpoints and error model.
- PERSON 2 voice/control entry point.

## Do Not Modify Without Coordination

- backend persistence logic
- WidgetKit/App Intent implementation details
- API request/response shape
