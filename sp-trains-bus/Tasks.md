# SP Trains & Bus - iOS App Development Plan

## Project Overview

A modern iOS app for São Paulo public transit information, featuring real-time bus arrivals, metro/train status, and route planning. Built with SwiftUI following Hexagonal Architecture (Ports & Adapters) pattern.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        UI Layer                              │
│  (SwiftUI Views, ViewModels, UI Components)                 │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     Application Layer                        │
│  (Use Cases / Interactors)                                  │
│  - GetNearbyStopsUseCase                                    │
│  - GetArrivalsUseCase                                       │
│  - SearchStopsUseCase                                       │
│  - GetTripRouteUseCase                                      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      Domain Layer                            │
│  (Entities, Protocols/Ports)                                │
│  - Stop, Arrival, Route, Trip, Line                         │
│  - TransitRepositoryProtocol                                │
│  - LocationServiceProtocol                                  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   Infrastructure Layer                       │
│  (Adapters - External Services Implementation)              │
│  - APIClient (Network)                                      │
│  - TransitAPIRepository                                     │
│  - CoreLocationService                                      │
│  - UserDefaultsStorage                                      │
└─────────────────────────────────────────────────────────────┘
```

---

## Folder Structure

```
sp-trains-bus/
├── App/
│   ├── sp_trains_busApp.swift
│   └── AppDependencies.swift
│
├── Domain/
│   ├── Entities/
│   │   ├── Stop.swift
│   │   ├── Arrival.swift
│   │   ├── Route.swift
│   │   ├── Trip.swift
│   │   ├── TripStop.swift
│   │   ├── MetroLine.swift
│   │   └── Location.swift
│   │
│   └── Protocols/
│       ├── TransitRepositoryProtocol.swift
│       ├── LocationServiceProtocol.swift
│       └── StorageServiceProtocol.swift
│
├── Application/
│   └── UseCases/
│       ├── GetNearbyStopsUseCase.swift
│       ├── GetArrivalsUseCase.swift
│       ├── SearchStopsUseCase.swift
│       ├── GetTripRouteUseCase.swift
│       ├── GetRouteShapeUseCase.swift
│       └── GetMetroStatusUseCase.swift
│
├── Infrastructure/
│   ├── Network/
│   │   ├── APIClient.swift
│   │   ├── APIEndpoint.swift
│   │   ├── APIError.swift
│   │   └── DTOs/
│   │       ├── StopDTO.swift
│   │       ├── ArrivalDTO.swift
│   │       ├── TripDTO.swift
│   │       └── RouteDTO.swift
│   │
│   ├── Repositories/
│   │   └── TransitAPIRepository.swift
│   │
│   ├── Services/
│   │   ├── CoreLocationService.swift
│   │   └── UserDefaultsStorageService.swift
│   │
│   └── Mappers/
│       └── DTOMappers.swift
│
├── Presentation/
│   ├── Common/
│   │   ├── Components/
│   │   │   ├── GlassCard.swift
│   │   │   ├── RouteBadge.swift
│   │   │   ├── CountdownTimer.swift
│   │   │   ├── LoadingView.swift
│   │   │   └── ErrorView.swift
│   │   │
│   │   ├── Styles/
│   │   │   ├── AppColors.swift
│   │   │   ├── AppFonts.swift
│   │   │   └── GlassStyle.swift
│   │   │
│   │   └── Extensions/
│   │       ├── View+Extensions.swift
│   │       └── Color+Extensions.swift
│   │
│   ├── Home/
│   │   ├── HomeView.swift
│   │   ├── HomeViewModel.swift
│   │   ├── Components/
│   │   │   ├── GreetingHeader.swift
│   │   │   ├── QuickCommuteCard.swift
│   │   │   ├── MiniMapView.swift
│   │   │   └── FavoritesSection.swift
│   │   └── FavoriteStopCard.swift
│   │
│   ├── StopDetail/
│   │   ├── StopDetailView.swift
│   │   ├── StopDetailViewModel.swift
│   │   └── Components/
│   │       ├── NextBusCard.swift
│   │       ├── BusProgressIndicator.swift
│   │       └── UpcomingBusList.swift
│   │
│   ├── SystemStatus/
│   │   ├── SystemStatusView.swift
│   │   ├── SystemStatusViewModel.swift
│   │   └── Components/
│   │       ├── OverallStatusCard.swift
│   │       └── MetroLineCard.swift
│   │
│   ├── Map/
│   │   ├── MapExplorerView.swift
│   │   ├── MapExplorerViewModel.swift
│   │   └── Components/
│   │       ├── TransitMapView.swift
│   │       ├── FilterChips.swift
│   │       ├── StopAnnotation.swift
│   │       └── RouteOverlay.swift
│   │
│   ├── Search/
│   │   ├── SearchView.swift
│   │   ├── SearchViewModel.swift
│   │   └── Components/
│   │       └── SearchResultRow.swift
│   │
│   └── TabBar/
│       └── MainTabView.swift
│
└── Resources/
    ├── Assets.xcassets/
    └── Info.plist
```

---

## Development Tasks

### Phase 1: Foundation & Architecture Setup
> Priority: Critical | Estimated: 2-3 days

- [ ] **1.1** Create folder structure following hexagonal architecture
- [ ] **1.2** Define Domain entities (Stop, Arrival, Route, Trip, MetroLine, Location)
- [ ] **1.3** Create Domain protocols (TransitRepositoryProtocol, LocationServiceProtocol, StorageServiceProtocol)
- [ ] **1.4** Setup dependency injection container (AppDependencies)
- [ ] **1.5** Configure Info.plist for location permissions and network security

### Phase 2: Infrastructure Layer - Network
> Priority: Critical | Estimated: 2-3 days

- [ ] **2.1** Implement APIClient with async/await
  - Base URL configuration
  - Request building
  - Response parsing
  - Error handling
- [ ] **2.2** Define APIEndpoint enum with all endpoints
  - nearby(lat, lon, limit)
  - arrivals(stopId, limit)
  - search(query)
  - trip(tripId)
  - shape(shapeId)
  - stop(stopId)
  - routes()
- [ ] **2.3** Create DTO models matching API responses
- [ ] **2.4** Implement DTOMappers to convert DTOs to Domain entities
- [ ] **2.5** Implement TransitAPIRepository conforming to TransitRepositoryProtocol
- [ ] **2.6** Add unit tests for network layer

### Phase 3: Infrastructure Layer - Services
> Priority: Critical | Estimated: 1-2 days

- [ ] **3.1** Implement CoreLocationService
  - Request location permissions
  - Get current location
  - Monitor location updates
  - Handle authorization status changes
- [ ] **3.2** Implement UserDefaultsStorageService
  - Save/load favorite stops
  - Save/load home/work locations
  - Save/load user preferences
- [ ] **3.3** Add unit tests for services

### Phase 4: Application Layer - Use Cases
> Priority: High | Estimated: 1-2 days

- [ ] **4.1** Implement GetNearbyStopsUseCase
- [ ] **4.2** Implement GetArrivalsUseCase
- [ ] **4.3** Implement SearchStopsUseCase
- [ ] **4.4** Implement GetTripRouteUseCase
- [ ] **4.5** Implement GetRouteShapeUseCase
- [ ] **4.6** Implement GetMetroStatusUseCase (mock data initially)

### Phase 5: UI Foundation & Design System
> Priority: High | Estimated: 2-3 days

- [ ] **5.1** Define color palette (AppColors)
  - Primary, secondary, accent colors
  - Metro line colors (L1-Azul, L2-Verde, etc.)
  - Status colors (normal, warning, alert)
- [ ] **5.2** Define typography (AppFonts)
- [ ] **5.3** Create GlassCard component (glassmorphism effect)
- [ ] **5.4** Create RouteBadge component (colored bus/metro badges)
- [ ] **5.5** Create CountdownTimer component (animated countdown)
- [ ] **5.6** Create LoadingView and ErrorView components
- [ ] **5.7** Create common View extensions

### Phase 6: Home Screen
> Priority: High | Estimated: 2-3 days

- [ ] **6.1** Implement HomeViewModel
  - Load user's current location
  - Load nearby stops
  - Load favorite stops
  - Time-based greeting logic
- [ ] **6.2** Create GreetingHeader component
  - Dynamic greeting (Good Morning/Afternoon/Evening)
  - User name display
- [ ] **6.3** Create QuickCommuteCard component
  - To Work / To Home buttons
  - ETA display
- [ ] **6.4** Create MiniMapView component
  - Show user location
  - Show nearby stops
- [ ] **6.5** Create FavoritesSection with FavoriteStopCard
  - Horizontal scrolling list
  - Next arrival preview
- [ ] **6.6** Assemble HomeView with all components

### Phase 7: Stop Detail Screen
> Priority: High | Estimated: 2-3 days

- [ ] **7.1** Implement StopDetailViewModel
  - Load stop information
  - Load arrivals with auto-refresh
  - Timer countdown logic
- [ ] **7.2** Create NextBusCard component
  - Large countdown display
  - Route badge
  - Destination headsign
- [ ] **7.3** Create BusProgressIndicator component
  - Visual progress toward arrival
- [ ] **7.4** Create UpcomingBusList component
  - List of next buses
  - Color-coded by route
  - Tap to see trip details
- [ ] **7.5** Assemble StopDetailView
- [ ] **7.6** Add pull-to-refresh functionality

### Phase 8: System Status Screen (Metro/Train)
> Priority: Medium | Estimated: 1-2 days

- [ ] **8.1** Implement SystemStatusViewModel
  - Load metro line statuses
  - Overall system health calculation
- [ ] **8.2** Create OverallStatusCard component
  - Status indicator (Normal/Alert)
  - Animated pulse effect
- [ ] **8.3** Create MetroLineCard component
  - Line color and name
  - Current status
  - Status description
- [ ] **8.4** Assemble SystemStatusView
  - Grid layout for metro lines

### Phase 9: Map Explorer Screen
> Priority: Medium | Estimated: 3-4 days

- [ ] **9.1** Implement MapExplorerViewModel
  - Handle map region changes
  - Load stops in visible region
  - Filter by transport type
  - Route shape loading
- [ ] **9.2** Create TransitMapView using MapKit
  - Custom map style
  - User location display
- [ ] **9.3** Create StopAnnotation component
  - Custom marker design
  - Callout with stop info
- [ ] **9.4** Create FilterChips component
  - Bus / Metro / Train filters
  - Selected state styling
- [ ] **9.5** Create RouteOverlay for displaying trip shapes
- [ ] **9.6** Assemble MapExplorerView
- [ ] **9.7** Add "Plan Route" functionality (future enhancement)

### Phase 10: Search Screen
> Priority: Medium | Estimated: 1-2 days

- [ ] **10.1** Implement SearchViewModel
  - Debounced search
  - Recent searches
  - Search results
- [ ] **10.2** Create SearchResultRow component
  - Stop name and description
  - Distance (if available)
  - Route badges
- [ ] **10.3** Assemble SearchView
  - Search bar
  - Recent searches section
  - Results list

### Phase 11: Navigation & Tab Bar
> Priority: High | Estimated: 1 day

- [ ] **11.1** Create MainTabView with 5 tabs
  - Home (house icon)
  - Nearby (location icon)
  - Search (magnifying glass)
  - Status (signal icon)
  - Map (map icon)
- [ ] **11.2** Implement navigation between screens
- [ ] **11.3** Handle deep linking (future)

### Phase 12: Polish & Enhancements
> Priority: Low | Estimated: 2-3 days

- [ ] **12.1** Add haptic feedback for interactions
- [ ] **12.2** Add animations and transitions
- [ ] **12.3** Implement dark mode support
- [ ] **12.4** Add skeleton loading states
- [ ] **12.5** Implement offline mode / caching
- [ ] **12.6** Add accessibility support (VoiceOver, Dynamic Type)
- [ ] **12.7** Localization (Portuguese/English)

### Phase 13: Testing & Quality
> Priority: High | Estimated: 2-3 days

- [ ] **13.1** Unit tests for Domain layer
- [ ] **13.2** Unit tests for Use Cases
- [ ] **13.3** Unit tests for ViewModels
- [ ] **13.4** UI tests for critical flows
- [ ] **13.5** Performance testing

---

## API Endpoints Reference

Base URL: `http://[SERVER_IP]:8080/api`

| Endpoint | Method | Parameters | Description |
|----------|--------|------------|-------------|
| `/nearby.php` | GET | lat, lon, limit, include_arrivals | Get nearby stops |
| `/arrivals.php` | GET | stop_id, time, date, limit | Get arrivals at stop |
| `/search.php` | GET | q, limit | Search stops by name |
| `/stop.php` | GET | stop_id, include_arrivals | Get stop details |
| `/trip.php` | GET | trip_id | Get trip route details |
| `/route.php` | GET | route_id | Get route information |
| `/shape.php` | GET | shape_id, format | Get shape points |
| `/routes.php` | GET | limit, offset | Get all routes |

---

## Metro Lines Reference (São Paulo)

| Line | Name | Color (Hex) |
|------|------|-------------|
| L1 | Azul | #0455A1 |
| L2 | Verde | #007E5E |
| L3 | Vermelha | #EE372F |
| L4 | Amarela | #FFD700 |
| L5 | Lilás | #9B3894 |
| L7 | Rubi | #CA016B |
| L8 | Diamante | #97A098 |
| L9 | Esmeralda | #01A9A7 |
| L10 | Turquesa | #008B8B |
| L11 | Coral | #F04E23 |
| L12 | Safira | #083D8B |
| L13 | Jade | #00B352 |

---

## Notes

- **Glassmorphism**: Use `.ultraThinMaterial` and `.blur()` modifiers for the glass effect
- **Auto-refresh**: Arrivals should refresh every 30 seconds
- **Location**: Request "When In Use" permission, upgrade to "Always" for commute features
- **Offline**: Cache recent stops and favorites for offline viewing
- **Performance**: Use lazy loading for lists, optimize map annotations

---

## Progress Tracking

| Phase | Status | Started | Completed |
|-------|--------|---------|-----------|
| Phase 1 | Not Started | - | - |
| Phase 2 | Not Started | - | - |
| Phase 3 | Not Started | - | - |
| Phase 4 | Not Started | - | - |
| Phase 5 | Not Started | - | - |
| Phase 6 | Not Started | - | - |
| Phase 7 | Not Started | - | - |
| Phase 8 | Not Started | - | - |
| Phase 9 | Not Started | - | - |
| Phase 10 | Not Started | - | - |
| Phase 11 | Not Started | - | - |
| Phase 12 | Not Started | - | - |
| Phase 13 | Not Started | - | - |
