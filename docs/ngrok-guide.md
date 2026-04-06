# ngrok — Temporary Backend Sharing Guide

> Use ngrok to expose your local Django server to a tester's phone **without deploying to a hosting provider**.
> This is for **ad-hoc, short-lived testing only** — not for sustained tester access.

---

## 1. Install ngrok

Download from [https://ngrok.com/download](https://ngrok.com/download) and sign up for a free account.

On Windows, extract `ngrok.exe` and optionally add it to your PATH, or run it directly:
```powershell
.\ngrok.exe authtoken YOUR_AUTH_TOKEN   # one-time setup
```

---

## 2. Start your Django server

```powershell
cd backend
.venv\Scripts\activate
python manage.py runserver 0.0.0.0:8000
```

---

## 3. Start ngrok in a second terminal

```powershell
.\ngrok.exe http 8000
```

ngrok will display something like:
```
Forwarding  https://abc123.ngrok-free.app -> http://localhost:8000
```

Copy the `https://...` URL.

---

## 4. Fix the ALLOWED_HOSTS blocker

Django will reject requests from the ngrok subdomain with a `400 DisallowedHost` error unless you add it.

**Option A — Add the specific subdomain (recommended):**

Edit `backend/config/settings/development.py`:
```python
ALLOWED_HOSTS = ["*"]   # already set to wildcard in development.py — no change needed
```

Since `development.py` already uses `ALLOWED_HOSTS = ["*"]`, you're covered automatically for local dev.

**Option B — If you see a DisallowedHost 400 error:**

Check that `DJANGO_SETTINGS_MODULE=config.settings.development` is set in your `.env`.

---

## 5. Build the APK with the ngrok URL

```powershell
cd mobile
C:\flutter\bin\flutter.bat build apk --debug --dart-define=API_BASE_URL=https://abc123.ngrok-free.app
```

Send `build\app\outputs\flutter-apk\app-debug.apk` to your tester.

---

## 6. Important limitations

| Limitation | Details |
|---|---|
| **URL changes on restart** | Free ngrok generates a new subdomain every time you run it. Rebuild the APK with the new URL each time. |
| **Tunnel goes down when laptop sleeps** | Keep your machine awake during tester sessions. |
| **Free tier bandwidth** | 1 GB/month — sufficient for functional testing, not load testing. |
| **Not for production** | Never use ngrok as a permanent backend for real users. Use Render or Railway instead (see `docs/distribution.md`). |

---

## 7. Paid ngrok (optional)

A paid ngrok account (`$10/month`) gives you a **stable subdomain** that never changes:
```
https://dukaan-dost.ngrok.app -> http://localhost:8000
```

This lets you build one APK that works permanently against your local machine, without rebuilding on every ngrok restart.
