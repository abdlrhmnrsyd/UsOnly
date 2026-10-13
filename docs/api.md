# API Documentation

All endpoints return a uniform JSON format:

```json
{
  "success": true,
  "data": { ... }
}
```

Or on error:

```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human readable message",
    "details": [ ... ]
  }
}
```

Interactive Swagger documentation is available at `http://localhost:3000/docs`.

## Endpoint Summary

### Authentication

- `POST /api/v1/auth/register`: Register account
- `POST /api/v1/auth/login`: Authenticate and obtain tokens
- `POST /api/v1/auth/refresh`: Rotate refresh token
- `POST /api/v1/auth/logout`: Revoke current refresh token
- `POST /api/v1/auth/logout-all`: Revoke all sessions

### Couple Space

- `POST /api/v1/couples`: Create couple space
- `GET /api/v1/couples/me`: Get couple status and partner profile
- `POST /api/v1/couples/invitations`: Generate 6-char pairing code
- `POST /api/v1/couples/join`: Join space with pairing code
- `POST /api/v1/couples/leave`: Leave couple space

### Shared Memories

- `GET /api/v1/memories`: Get timeline
- `POST /api/v1/memories`: Create memory
- `DELETE /api/v1/memories/:id`: Delete memory and media

### Realtime Chat

- `GET /api/v1/conversations/current`: Get couple conversation
- `GET /api/v1/conversations/:id/messages`: Paginated messages
- `POST /api/v1/conversations/:id/messages`: Send message

### Countdowns & Dates

- `GET /api/v1/countdowns`: List countdowns
- `POST /api/v1/countdowns`: Add countdown
- `DELETE /api/v1/countdowns/:id`: Delete countdown

### Private Letters

- `GET /api/v1/letters`: List letters (locked letters conceal body)
- `POST /api/v1/letters`: Compose letter / time capsule
- `GET /api/v1/letters/:id`: Read letter

### Mood Check-ins

- `GET /api/v1/moods`: List history
- `POST /api/v1/moods`: Record daily mood

### Location Sharing

- `GET /api/v1/locations/consent`: Get consent status
- `PUT /api/v1/locations/consent`: Toggle sharing consent
- `POST /api/v1/locations/update`: Update device location
- `GET /api/v1/locations/latest`: Get partner's latest coordinates
- `POST /api/v1/locations/stop-sharing`: Instantly stop sharing
