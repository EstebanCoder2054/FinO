# API Contract

Base URL is environment-specific and configured in iOS build settings.

## Authentication

For the hackathon MVP, production currently runs with backend auth disabled.
The iOS app does not send an auth token yet.

When auth is enabled again, all application data endpoints should require:

```http
Authorization: Bearer <supabase-access-token>
Content-Type: application/json
```

The backend verifies the token and derives the authenticated user. The client must not send `user_id` as an authorization boundary.

## POST /api/expenses

Creates an expense from natural language input.

### Request

```json
{
  "input": "Me gasté un millón de pesos en el mercado."
}
```

Validation:

- `input` is required
- must be a string
- trimmed length must be between 1 and 500 characters
- malformed JSON returns `400`

Optional header:

```http
Idempotency-Key: client-generated-request-id
```

### Success Response

```json
{
  "success": true,
  "expense": {
    "id": "uuid",
    "amount": "1000000",
    "currency": "COP",
    "category": "groceries",
    "description": "mercado",
    "merchant": null,
    "source": "ios_voice",
    "createdAt": "2026-09-12T12:00:00.000Z"
  }
}
```

`amount` is serialized as a string to preserve exact decimal values across platforms.

### Clarification Response

If the input lacks required financial information:

```json
{
  "success": false,
  "code": "needs_clarification",
  "message": "Necesito el monto exacto para guardar este gasto."
}
```

### Categories

```text
groceries
restaurants
transportation
shopping
entertainment
utilities
health
subscriptions
travel
other
```

### Error Shape

```json
{
  "success": false,
  "code": "bad_request",
  "message": "Invalid request."
}
```

Common statuses:

- `400`: invalid body or unsupported input
- `401`: missing or invalid authentication
- `403`: authenticated but not allowed
- `404`: resource not found
- `409`: duplicate idempotency key or conflict
- `429`: rate limited
- `500`: unexpected backend failure
- `502` or `503`: upstream OpenAI/Supabase failure

## GET /api/expenses

Returns the latest saved expenses for the MVP user.

### Success Response

```json
{
  "success": true,
  "expenses": [
    {
      "id": "uuid",
      "amount": "27000",
      "currency": "COP",
      "category": "transportation",
      "description": "taxi",
      "merchant": null,
      "source": "ios_voice",
      "createdAt": "2026-09-12T19:31:25.207839+00:00"
    }
  ]
}
```
