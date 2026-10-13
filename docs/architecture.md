# Us Two — Architecture Overview

## 1. System Architecture

Us Two is designed as a secure private application for exactly two consenting partners.

```
┌────────────────────────────────────────────────────────┐
│               Flutter Mobile Application               │
│  (Material 3 Romantic System, Riverpod, GoRouter, Dio) │
└───────────────────────────┬────────────────────────────┘
                            │
               HTTPS REST / WSS Socket.IO
                            │
┌───────────────────────────▼────────────────────────────┐
│          Node.js TypeScript Modular Monolith           │
│  (Express, Zod, Argon2id, JWT, Socket.IO, Helmet, CORS)│
└─────────────┬───────────────────────────┬──────────────┘
              │                           │
              ▼                           ▼
┌───────────────────────────┐ ┌───────────────────────────┐
│     MySQL 8.4 (Prisma)    │ │   Private Media Storage   │
│  (Couples, Chat, Letters, │ │ (Cloudflare R2 / AWS S3 / │
│   Countdowns, Moods, Loc) │ │  Local Fallback Driver)   │
└───────────────────────────┘ └───────────────────────────┘
```

## 2. Backend Architecture Pattern

Each module follows the strict pipeline:

```
HTTP Request
  ──> Rate Limiter
  ──> Auth / Membership Middleware
  ──> Zod Schema Validation
  ──> Controller
  ──> Service
  ──> Prisma ORM / MySQL
```

### Module Boundaries

- **Auth**: Registration, Argon2id hashing, access token issuing, rotating refresh token family with replay detection.
- **Users**: Profile management, active user verification, safe account deletion.
- **Couples**: Couple space creation, 6-character hashed invitation codes, atomic 2-member limit enforcement.
- **Memories**: Shared timeline, multi-photo attachments, chronological sorting.
- **Media**: Storage abstraction supporting Cloudflare R2, AWS S3, and local streaming driver.
- **Chat**: Realtime Socket.IO chat, room authorization scoped to couple, message persistence in MySQL.
- **Countdowns**: Special dates, anniversaries, calendar-aware annual recurrence calculation.
- **Letters**: Private letters with backend-enforced sealed time capsule unlocking.
- **Moods**: Partner daily mood check-in and emotional history.
- **Locations**: Strict opt-in location sharing with server-side consent verification and latest-only retention.
- **Notifications**: Device token management and privacy-preserving notifications.
