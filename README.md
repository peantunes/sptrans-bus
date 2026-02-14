# Due SP

Due SP is a transit project for Sao Paulo with:
- a PHP/MySQL backend API (`/server`)
- a SwiftUI iOS app (`/sp-trains-bus`)

## Repository Structure

```text
due-sp/
├── server/          # PHP API, import scripts, docker setup
├── sp-trains-bus/   # iOS app (SwiftUI, Clean Architecture)
└── PROJECT_DOCUMENTATION.md
```

## Backend (Server)

Location: `/Users/pedroantunes/Code/Projects/Published/due-sp/server`

### Requirements
- Docker
- Docker Compose

### Run locally

```bash
cd /Users/pedroantunes/Code/Projects/Published/due-sp/server
docker compose up --build
```

API base URL:
- `http://localhost:8080/api`

Important endpoint examples:
- `GET /api/arrivals.php`
- `GET /api/search.php`
- `GET /api/nearby.php`
- `GET /api/metro_cptm.php`

More details:
- `/Users/pedroantunes/Code/Projects/Published/due-sp/server/api/README.md`

## iOS App

Location: `/Users/pedroantunes/Code/Projects/Published/due-sp/sp-trains-bus`

### Open project

```bash
open /Users/pedroantunes/Code/Projects/Published/due-sp/sp-trains-bus/sp-trains-bus.xcodeproj
```

### Notes
- The app currently points to production API in:
  - `/Users/pedroantunes/Code/Projects/Published/due-sp/sp-trains-bus/Infrastructure/Network/APIEndpoint.swift`
- If you want local API usage, change `baseURL` there.

More iOS architecture details:
- `/Users/pedroantunes/Code/Projects/Published/due-sp/sp-trains-bus/iOS_PROJECT_GUIDE.md`

## Localization Workflow

Localization files:
- `/Users/pedroantunes/Code/Projects/Published/due-sp/sp-trains-bus/Resources/en.lproj/Localizable.strings`
- `/Users/pedroantunes/Code/Projects/Published/due-sp/sp-trains-bus/Resources/pt-BR.lproj/Localizable.strings`

Audit script:
- `/Users/pedroantunes/Code/Projects/Published/due-sp/sp-trains-bus/Scripts/localization_audit.sh`

Examples:

```bash
cd /Users/pedroantunes/Code/Projects/Published/due-sp/sp-trains-bus

# Full Presentation layer
./Scripts/localization_audit.sh .

# Specific area
./Scripts/localization_audit.sh . ./Presentation/Map
./Scripts/localization_audit.sh . ./Presentation/StopDetail
```

## Additional Documentation

- `/Users/pedroantunes/Code/Projects/Published/due-sp/PROJECT_DOCUMENTATION.md`
- `/Users/pedroantunes/Code/Projects/Published/due-sp/sp-trains-bus/AGENTS.md`
