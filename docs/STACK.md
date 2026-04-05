# Technology Stack Decisions — Dukaan Dost

## Mobile
- Flutter (Android-first): single codebase, own rendering engine (fast on low-end devices), future iOS at near-zero cost
- Drift / SQLite: typed ORM, works fully offline, append-only event log pattern
- url_launcher: WhatsApp deep link integration via `wa.me/` scheme

## Backend
- Django REST Framework: fast to build, mature ORM, strong Pakistan dev talent pool
- PostgreSQL: ACID compliance mandatory for financial event log
- Redis: sync queue, OTP code caching with TTL

## Auth
- Phone number + OTP only — no email, no social login
- Local Pakistani SMS gateway (Infobip / Avanza / TeleCom): lower cost, better delivery than Twilio
- Session token returned on OTP verify — stored in Flutter secure storage

## Notifications
- WhatsApp deep links (MVP): zero infrastructure cost, users already live there
- FCM (fallback): for payment due reminders when app is backgrounded

## Key Architectural Decision
Offline-first with append-only event log. Every user action writes to local SQLite instantly — the network is never on the critical path. The event log is replayed to compute balances — no mutable balance fields. This eliminates sync conflicts, provides a free audit trail, and directly enables dispute resolution.
