# Due SP (sp-trains-bus)

iOS app for Sao Paulo transit, including bus arrivals, rail status, maps, widgets, and watch support.

## Backend API

The backend is no longer part of this repository. It lives in the `Lolados-server` project (`apps/sptrans.lolados.app`) and is served at:

```
https://sptrans.lolados.app/api/
```

Endpoints (all under `/api/`, parameters via query string unless noted):

| Endpoint | Purpose | Parameters |
| --- | --- | --- |
| `search.php` | Search stops/routes | `q`, `limit` |
| `nearby.php` | Stops near a location | `lat`, `lon`, `limit`, `include_arrivals` |
| `stop.php` | Stop details | `stop_id`, `include_arrivals` |
| `arrivals.php` | Next arrivals at a stop | `stop_id`, `direction`, `date`, `time`, `cursor_date`, `cursor_time`, `limit` |
| `routes.php` | List routes | `limit`, `offset` |
| `route.php` | Route details | `route_id` |
| `trip.php` | Trip details | `trip_id` |
| `shape.php` | Route/trip shape | `shape_id`, `format` |
| `plan.php` | Trip planner | `origin_lat`, `origin_lon`, `dest_lat`, `dest_lon`, `origin_limit`, `destination_limit`, `direct_limit`, `transfer_limit`, `max_transfers`, `max_alternatives`, `ranking_priority` |
| `metro_cptm.php` | Metro/CPTM rail status | `refresh`, `installation_id` |
| `rail_status_report.php` | Rail status analytics (premium) | `period_days`, `source`, `line_number` |
| `rail_alert_subscriptions.php` | Rail disruption notification subscriptions (GET/POST) | `installation_id` |

Rail status sources and push (APNs) setup are documented in the server repo (`docs/sptrans-server-setup.md`).

## Premium Access

Premium features are gated by StoreKit subscriptions:

1. `app.lolados.data.weekly`
2. `app.lolados.data.yearly`

Both unlock the same premium features:

1. Rail disruption notifications
2. Rail status analytics
3. Custom date/time plus previous/next arrivals in stop detail

Tip products remain available as optional support and do not unlock any feature.

## App Intents (Siri + Shortcuts)

The app currently exposes these intents:

1. `GetNextArrivalsIntent`
   - Purpose: Get next arrivals for a selected stop.
   - Parameters: `Stop`, optional `Limit` (1...20).
2. `CheckRailStatusIntent`
   - Purpose: Check Metro/CPTM network status, or a specific line.
   - Parameters: optional `Rail Line`.
3. `OpenStopIntent`
   - Purpose: Open a stop directly inside the app.
   - Parameters: `Stop`.

### Siri phrases

You can use these phrases (or close variations):

1. "Check arrivals at <stop> in Due SP"
2. "When is the next bus at <stop> in Due SP"
3. "Check rail status in Due SP"
4. "How are Metro and CPTM now in Due SP"
5. "Open stop <stop> in Due SP"
6. "Show stop <stop> in Due SP"

## How to access via Siri

1. Launch Due SP at least once after install/update (registers App Shortcuts metadata).
2. Open iOS `Shortcuts` app.
3. Tap `+`, then `Add Action`, search for `Due SP`.
4. Pick one of the actions above and configure parameters (for example, stop and limit).
5. (Optional) Rename the shortcut to your preferred voice phrase.
6. Invoke with `Hey Siri, <your phrase>`.

## Notes

1. Stop-based intents require selecting a valid stop entity.
2. Rail status intent works with or without line selection.
3. More intents are planned in `AppIntents_Future_Implementations_Report.md`.
