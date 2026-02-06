# Local Data Plan (SwiftData + GTFS)

## Goal
- Keep GTFS data locally so the app can run without the API.
- Let users store multiple personal places (`home`, `work`, `study`, `custom`).
- Check weekly for a new GTFS archive and update the local database.

## Architecture Changes
- Add SwiftData container with models for:
  - Favorite stops
  - User places
  - GTFS feed metadata (version/check timestamps/etag)
- Keep `StorageServiceProtocol` as the app boundary and extend it for multi-place CRUD.
- Add `GTFSFeedServiceProtocol` for weekly refresh policy and feed metadata state.
- Use `SwiftDataStorageService` in dependencies (replacing runtime `UserDefaults` storage).

## GTFS Import/Update Flow
1. User enables `Use Local Data` and confirms an import source.
2. App downloads GTFS zip into app storage (`Application Support`).
3. Import pipeline parses GTFS files and writes into SwiftData entities.
4. On successful import, app stores feed metadata (`versionIdentifier`, `downloadedAt`, `lastCheckedAt`).
5. App checks weekly:
   - If no metadata, check immediately.
   - If `lastCheckedAt + 7 days <= now`, check remote metadata.
6. If remote feed changed, prompt user and run background download/import.

## Current Execution Status
- [x] SwiftData model container added.
- [x] SwiftData storage service implemented for favorites + user places.
- [x] Multi-place storage API added to domain protocol.
- [x] GTFS feed metadata service added with weekly policy.
- [x] App dependency wiring switched to SwiftData services.
- [x] GTFS importer implementation for extracted GTFS `.txt` files.
- [x] Local transit repository queries (nearby/search/arrivals/trip/shape from local DB).
- [x] Source selector repository (`local` vs `api`) with automatic fallback.
- [x] Use cases for GTFS import and weekly-check policy.
- [ ] Zip extraction support in-app (current importer expects extracted folder).
- [ ] UI for managing saved places and local-data mode.
- [ ] Background weekly sync job integration.

## Next Implementation Steps
1. Add zip extraction implementation before import (import service currently reads extracted folder).
2. Hook importer + local mode into UI settings:
   - Import CTA
   - Last import/feed version
   - Local/API toggle
3. Add screens/components:
   - Import status + last update date
   - Place management (add/edit/delete with category chips)
