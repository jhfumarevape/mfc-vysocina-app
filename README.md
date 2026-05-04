# MFC Vysočina — týmová aplikace

Sociální/komunitní aplikace pro tým MFC Vysočina.

## Komponenty

| Složka | Popis | Technologie |
|---|---|---|
| `mfc-app/` | Backend API | Python · FastAPI · SQLAlchemy · SQLite · JWT · WebSocket |
| `mfc_app/` | Mobilní aplikace | Flutter (Dart) — Android · iOS · Web |
| `admin_ui/` | Webový admin panel | Vanilla HTML + JS (servováno backendem) |

## Funkce

- 👥 Uživatelé + dynamické role s permission systémem (admin / captain / member + vlastní)
- 📰 Příspěvky (feed) + pinování
- 📅 Události (tréninky, turnaje, srazy) + RSVP
- 💬 Skupiny + real-time chat (WebSocket)
- 🖼 Upload obrázků
- 🔐 Admin panel pro správu uživatelů, rolí a oprávnění (`/admin/`)

## Backend — spuštění (server)

```bash
cd mfc-app
python -m venv venv
./venv/bin/pip install -r requirements.txt
./venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 5002
```

Admin panel: `http://<server>:5002/admin/`

## Mobilní app — build

```bash
cd mfc_app
flutter pub get
flutter build apk --release          # Android APK
flutter build web --release          # Web verze
flutter run -d chrome                # Dev v prohlížeči
```

URL backendu se nastaví v `mfc_app/lib/core/config.dart`.

## Permissions

Definovány v `mfc-app/app/permissions.py`. Lze je přidělovat rolím přes admin panel.
