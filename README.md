# Due SP

Due SP is a transit project for Sao Paulo with:
- a PHP/MySQL backend API (`/server`)
- a SwiftUI iOS app (`/sp-trains-bus`)
- a watchOS companion app + watch complications (inside `/sp-trains-bus`)
- an iOS WidgetKit extension for Home Screen and Lock Screen widgets (inside `/sp-trains-bus`)

## Repository Structure

```text
due-sp/
├── server/          # PHP API, import scripts, docker setup
├── sp-trains-bus/   # iOS app + watchOS app/complications
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

## Apple Watch Companion

Watch targets (in the same Xcode project):
- `due-sp-watch Watch App` (folder: `/Users/pedroantunes/Code/Projects/Published/due-sp/sp-trains-bus/due-sp-watch Watch App`)
- `due-sp-watchExtension` (folder: `/Users/pedroantunes/Code/Projects/Published/due-sp/sp-trains-bus/due-sp-watch`)

Implemented watch features:
- Favorite rail lines shown first (with status)
- Top 4 nearby stops
- Stop detail screen with next arrivals
- Open-on-iPhone deep links (`duesp://status`, `duesp://stop?...`)
- Complications/widgets for rail status, next arrival, and nearby stops

Shared data flow:
- Watch app and watch complication extension fetch live from API endpoints (`metro_cptm.php`, `nearby.php`, `arrivals.php`)
- Shared API implementation lives in `/Users/pedroantunes/Code/Projects/Published/due-sp/sp-trains-bus/SharedTransitAPI`
- Preferred pinned stop key for widgets: `widget_preferred_stop_id_v1`

## iOS Widgets

iOS widget target (in the same Xcode project):
- `due-sp-ios-widgetsExtension` (folder: `/Users/pedroantunes/Code/Projects/Published/due-sp/sp-trains-bus/due-sp-ios-widgets`)

Implemented iOS widgets:
- Rail status (live from API)
- Next arrival for preferred stop
- Nearby stops and ETAs
- Deep links into app routes (`duesp://status`, `duesp://stop?...`)
- Rail status layout: up to 1 line on `systemSmall`, up to 3 lines on `systemMedium`
- Rail status layout optimized to use space with denser rows and clearer line/status hierarchy

Data source:
- iOS widgets fetch live data from API endpoints (`metro_cptm.php`, `nearby.php`, `arrivals.php`)
- iOS widgets share the same API implementation used by watch targets (`/SharedTransitAPI`)
- App group storage is only used for preferred stop pinning (`widget_preferred_stop_id_v1`)

Supported families:
- Home Screen: `systemSmall`, `systemMedium`, `systemLarge`
- Lock Screen: `accessoryInline`, `accessoryCircular`, `accessoryRectangular`

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
