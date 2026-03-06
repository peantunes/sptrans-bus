# Due SP App Intents Strategy Report

Date: March 6, 2026
Scope: iOS app (`sp-trains-bus`), watch app/complications, widgets, Spotlight, Siri/Shortcuts, and intent donation strategy.

## 1. Executive Summary

Due SP already uses App Intents for widget configuration (iOS + watch rail widgets), but it still does not expose app actions as first-class App Shortcuts/Siri/Spotlight intents.

The biggest opportunity is to ship an `AppIntents` extension focused on daily commuter flows:

1. Arrivals at a stop
2. Nearby stops around current location
3. Trip planning between places
4. Rail status and disruption subscriptions
5. Favorite stop/line management

If implemented in phases, this can improve:

1. User retention (repeat shortcut usage)
2. Notification opt-in quality
3. Re-open rate from Spotlight and Siri

## 2. Current Baseline (What Exists Today)

1. iOS widget rail status configuration intent exists:
   - `due-sp-ios-widgets/RailStatusWidgetIntent.swift`
2. watch rail status configuration intent exists:
   - `due-sp-watch/WatchRailStatusWidgetIntent.swift`
3. Widgets and watch complications already deep-link into app routes:
   - `duesp://status`
   - `duesp://stop?...`
4. Core app features already map well to intents:
   - Nearby stops
   - Stop arrivals with pagination/time reference
   - Trip planning
   - Rail status and analytics
   - Rail disruption subscriptions
   - Favorites (stops/lines)

Gap:
1. No dedicated App Intents extension with user-facing app actions.
2. No Spotlight indexing of transit entities.
3. No donation of high-value actions.

## 3. Product Principles for App Intents

1. Prioritize "single-shot" commuter tasks (answer in one command).
2. Keep parameters minimal for voice use.
3. Use app entities (stop, rail line, saved place) for disambiguation.
4. Donate intents after successful in-app actions.
5. Use snippets only when there is clear value (status cards, compact arrivals).
6. For paid-only features, fail gracefully in intent result and offer an "Open app to unlock" path.

## 4. Recommended Intent Catalog

### 4.1 Transit Core Intents (High Priority)

1. `GetNextArrivalsIntent`
   - Input: stop (`StopEntity`), optional `limit`
   - Output: next arrivals summary
   - Surface: Siri, Shortcuts, Spotlight action, Action Button

2. `FindNearbyStopsIntent`
   - Input: optional radius/limit
   - Uses current location
   - Output: nearest stops with distance
   - Surface: Siri and Spotlight

3. `PlanTripIntent`
   - Input: origin (`SavedPlaceEntity` or current location), destination (`SavedPlaceEntity`/search), ranking priority
   - Output: best option summary and deep link to route details
   - Surface: Siri/Shortcuts

4. `OpenStopIntent`
   - Input: stop (`StopEntity`)
   - Action: open app directly on `StopDetailView`

5. `OpenMapAtStopIntent`
   - Input: stop (`StopEntity`)
   - Action: open map tab focused on stop

### 4.2 Rail Status and Alert Intents (High Priority)

1. `CheckRailStatusIntent`
   - Input: optional line (`RailLineEntity`)
   - Output: line/network current status, impact level

2. `SubscribeRailDisruptionIntent`
   - Input: one or more lines (`RailLineEntity`)
   - Behavior:
     - if notification permission missing: prompt/redirect
     - sync with backend subscriptions

3. `UnsubscribeRailDisruptionIntent`
   - Input: one or more lines

4. `OpenRailAnalyticsIntent` (paid-gated)
   - Input: period (7/14/30 days)
   - If locked: return clear unlock messaging + open app route

### 4.3 Favorites and Personalization Intents (Medium Priority)

1. `ToggleFavoriteStopIntent`
   - Input: stop
   - Output: favorited/unfavorited confirmation

2. `ToggleFavoriteRailLineIntent`
   - Input: line
   - Output: favorite state confirmation

3. `SetHomePlaceIntent`
   - Input: location/search result

4. `SetWorkPlaceIntent`
   - Input: location/search result

5. `OpenFavoritesIntent`
   - Action: open map/home focused on favorites

## 5. App Entities and Queries (Foundation for Spotlight + Intents)

Create these entities first in the App Intents extension:

1. `StopEntity`
   - id: `stopId`
   - display: stop name + code + routes
   - query: by ID, by string search

2. `RailLineEntity`
   - id: `source-lineNumber`
   - display: `METRO L1 Azul`, etc.
   - query: by id/string

3. `SavedPlaceEntity`
   - id: UUID
   - display: Home/Work/custom labels

For each entity:
1. Provide `EntityStringQuery` for robust natural-language matching.
2. Keep display strings localized (pt-BR and en).

## 6. Spotlight Strategy

### 6.1 What to Index

1. Favorite stops
2. Recently opened stops
3. Favorite rail lines
4. Saved places (Home/Work)
5. Recent trip origins/destinations

### 6.2 How to Index

Use Core Spotlight for immediate practicality, then optionally migrate to modern indexed entity APIs.

1. Create a lightweight `SpotlightIndexer` service.
2. Update index on:
   - favorite add/remove
   - stop detail open
   - rail line favorite toggle
   - saved place create/update/remove
3. Remove stale entries on delete/unfavorite.

### 6.3 Spotlight Actions

Each result should open directly into the correct app state:

1. Stop -> map tab + stop detail
2. Rail line -> status tab + highlighted line
3. Saved place -> search/map prefilled

## 7. Intent Donation Plan (Critical)

Donate intents after successful user actions to increase shortcut suggestions.

### 7.1 Donation Triggers

1. `GetNextArrivalsIntent` after user opens a stop and arrivals load successfully.
2. `OpenStopIntent` after repeated opens of same stop (frequency threshold).
3. `PlanTripIntent` after successful plan in Search.
4. `CheckRailStatusIntent` after opening Status tab and interacting with lines.
5. `SubscribeRailDisruptionIntent` after saving alert subscriptions.

### 7.2 Donation Rules

1. Do not donate on failed actions.
2. Debounce repeated donations (same entity within short interval).
3. Prefer donations for favorites and frequently repeated destinations.

## 8. SwiftUI in Intents: Where It Is Worth It

Use SwiftUI snippet/result views only for quick-glance outputs where text alone is weak.

Best candidates:

1. Arrivals snippet
   - top 3 arrivals, color-coded wait times

2. Rail status snippet
   - line badge, impact severity, last update

3. Nearby stops snippet
   - top stops with distance + first ETA

4. Trip summary snippet
   - departure, arrival, transfer count, first leg

Guideline:
1. Keep snippet under ~2-3 information rows.
2. Avoid heavy charts inside snippets; open app for full analytics.

## 9. Permission and Access Design

1. Location-dependent intents:
   - if location unavailable, return actionable message and fallback behavior.

2. Notification subscription intents:
   - if denied, return "Open Settings" guidance.

3. Paid-gated intents:
   - allow intent invocation but return unlock path with clear explanation.

4. Network failures:
   - return short retry-safe responses; avoid long failure dialogs.

## 10. Suggested Extension Structure

Create new target/folder:

`sp-trains-bus/AppIntents/`

Recommended files:

1. `DueSPShortcutsProvider.swift`
2. `Entities/StopEntity.swift`
3. `Entities/RailLineEntity.swift`
4. `Entities/SavedPlaceEntity.swift`
5. `Queries/StopEntityQuery.swift`
6. `Queries/RailLineEntityQuery.swift`
7. `Intents/GetNextArrivalsIntent.swift`
8. `Intents/FindNearbyStopsIntent.swift`
9. `Intents/PlanTripIntent.swift`
10. `Intents/CheckRailStatusIntent.swift`
11. `Intents/SubscribeRailDisruptionIntent.swift`
12. `Donation/IntentDonationService.swift`
13. `Spotlight/SpotlightIndexer.swift`

## 11. Implementation Phases

### Phase 1 (Fast Value, 1 sprint)

1. New App Intents extension target
2. `StopEntity` + `RailLineEntity`
3. `GetNextArrivalsIntent`
4. `CheckRailStatusIntent`
5. Basic donations for stop open + status check

### Phase 2 (Engagement)

1. `FindNearbyStopsIntent`
2. `OpenStopIntent`
3. `SubscribeRailDisruptionIntent` / `UnsubscribeRailDisruptionIntent`
4. Settings fallback behavior for denied notifications

### Phase 3 (Power User)

1. `PlanTripIntent`
2. `SavedPlaceEntity`
3. Spotlight indexing for favorites/recent items
4. Additional donation logic and ranking

### Phase 4 (UX polish)

1. Snippet views for arrivals and rail status
2. Better localization and natural language parameter tuning
3. Expanded result snippets for watch/lock screen contexts

## 12. KPIs to Track

1. Shortcut runs per day/week
2. Donation conversion after intent-triggered flows
3. Notification subscription completion rate from intents
4. Spotlight open-to-action success rate
5. Retention delta for users with at least one donated shortcut

## 13. Recommended First 5 Intents to Build

1. `GetNextArrivalsIntent`
2. `CheckRailStatusIntent`
3. `OpenStopIntent`
4. `FindNearbyStopsIntent`
5. `SubscribeRailDisruptionIntent`

These 5 cover daily utility, retention, and disruption-awareness with the highest product impact.

---

If you want, next step I can convert this report into an implementation checklist with exact file skeletons and protocol signatures for each intent/entity (ready to paste into the new `AppIntents` target).
