# SPTrans Bus iOS App - Complete Developer Guide

## Quick Overview

**Project**: sp-trains-bus
**Language**: Swift 5+
**Framework**: SwiftUI
**Architecture**: Clean Architecture (4 layers)
**Pattern**: MVVM with Use Cases
**Size**: ~3,587 lines of Swift code across 69 files
**Target**: iOS 14+
**Build System**: Xcode 14+

---

## Architecture Overview

```
┌─────────────────────────────────┐
│   PRESENTATION LAYER            │
│   (ViewModels + SwiftUI Views)  │
├─────────────────────────────────┤
│   APPLICATION LAYER             │
│   (Use Cases / Interactors)     │
├─────────────────────────────────┤
│   DOMAIN LAYER                  │
│   (Entities + Protocols)        │
├─────────────────────────────────┤
│   INFRASTRUCTURE LAYER          │
│   (Network, DB, Services)       │
└─────────────────────────────────┘
```

---

## Directory Structure

```
sp-trains-bus/
├── App/
│   ├── sp_trains_busApp.swift                 # Entry point
│   └── AppDependencies.swift                  # DI container
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
├── Domain/
│   ├── Entities/
│   │   ├── Stop.swift
│   │   ├── Arrival.swift
│   │   ├── Route.swift
│   │   ├── Trip.swift
│   │   ├── TripStop.swift
│   │   ├── Location.swift
│   │   └── MetroLine.swift
│   └── Protocols/
│       ├── TransitRepositoryProtocol.swift
│       ├── LocationServiceProtocol.swift
│       └── StorageServiceProtocol.swift
│
├── Infrastructure/
│   ├── Network/
│   │   ├── APIClient.swift
│   │   ├── APIError.swift
│   │   ├── APIEndpoint.swift
│   │   └── DTOs/
│   │       ├── StopDTO.swift
│   │       ├── ArrivalDTO.swift
│   │       ├── RouteDTO.swift
│   │       ├── TripDTO.swift
│   │       └── LocationDTO.swift
│   ├── Repositories/
│   │   └── TransitAPIRepository.swift
│   ├── Services/
│   │   ├── CoreLocationService.swift
│   │   └── UserDefaultsStorageService.swift
│   └── Mappers/
│       └── DTOMappers.swift
│
├── Presentation/
│   ├── TabBar/
│   │   └── MainTabView.swift                 # Root navigation (5 tabs)
│   ├── Home/
│   │   ├── HomeView.swift
│   │   ├── HomeViewModel.swift
│   │   └── Components/
│   │       ├── GreetingHeader.swift
│   │       ├── QuickCommuteCard.swift
│   │       ├── WeatherSummaryCard.swift
│   │       ├── RailStatusSection.swift
│   │       ├── TravelFeaturesSection.swift
│   │       ├── HomeMapPreview.swift
│   │       ├── NearbyStopsSection.swift
│   │       ├── MiniMapView.swift
│   │       ├── FavoritesSection.swift
│   │       └── FavoriteStopCard.swift
│   ├── Search/
│   │   ├── SearchView.swift
│   │   ├── SearchViewModel.swift
│   │   └── Components/
│   │       └── SearchResultRow.swift
│   ├── Map/
│   │   ├── MapExplorerView.swift
│   │   ├── MapExplorerViewModel.swift
│   │   └── Components/
│   │       ├── TransitMapView.swift
│   │       ├── StopAnnotation.swift
│   │       ├── FilterChips.swift
│   │       ├── MapStopCarousel.swift
│   │       ├── FilterNoticeCard.swift
│   │       └── RouteOverlay.swift
│   ├── StopDetail/
│   │   ├── StopDetailView.swift
│   │   ├── StopDetailViewModel.swift
│   │   └── Components/
│   │       ├── NextBusCard.swift
│   │       ├── UpcomingBusList.swift
│   │       ├── JourneySection.swift
│   │       ├── JourneyMapView.swift
│   │       └── BusProgressIndicator.swift
│   ├── SystemStatus/
│   │   ├── SystemStatusView.swift
│   │   ├── SystemStatusViewModel.swift
│   │   └── Components/
│   │       ├── MetroLineCard.swift
│   │       └── OverallStatusCard.swift
│   └── Common/
│       ├── Components/
│       │   ├── LoadingView.swift
│       │   ├── ErrorView.swift
│       │   ├── GlassCard.swift
│       │   ├── CountdownTimer.swift
│       │   └── RouteBadge.swift
│       ├── Styles/
│       │   ├── AppColors.swift
│       │   └── AppFonts.swift
│       └── Extensions/
│           ├── View+Extensions.swift
│           ├── Color+Extensions.swift
│           ├── MKLocalSearchCompletion+Extensions.swift
│           └── MKCoordinateRegion+Extensions.swift
│
├── Resources/
│   └── Assets.xcassets/
│       ├── AppIcon.appiconset
│       ├── AccentColor.colorset
│       ├── PrimaryColor.colorset
│       ├── BackgroundColor.colorset
│       ├── TextColor.colorset
│       └── LightGray.colorset
│
├── Tests/
│   ├── ViewModelsTests.swift
│   ├── UseCasesTests.swift
│   ├── NetworkLayerTests.swift
│   ├── DomainLayerTests.swift
│   └── ServiceLayerTests.swift
│
└── sp-trains-bus.xcodeproj

```

---

## Layer-by-Layer Guide

### 1. PRESENTATION LAYER

**Location**: `/Presentation`
**Responsibility**: Display data and handle user interactions

#### MainTabView (Root)
Five-tab navigation structure:
1. **Home** - Nearby stops and favorites
2. **Nearby** - Placeholder for expansion
3. **Status** - Metro line status
4. **Map** - Interactive map explorer
5. **Search** - Place search with nearby stops

#### HomeView & HomeViewModel
```swift
Published Properties:
- nearbyStops: [Stop]
- favoriteStops: [Stop]
- isLoading: Bool
- errorMessage: String?
- userLocation: Location?

Responsibilities:
- Load nearby stops via GetNearbyStopsUseCase
- Manage favorite stops via storage service
- Handle location permissions
- Generate time-based greetings
- Fallback to São Paulo default location
```

#### SearchView & SearchViewModel
```swift
Published Properties:
- searchText: String
- searchSuggestions: [MKLocalSearchCompletion]
- nearbyStops: [Stop]
- selectedPlaceName: String?
- isSearchingLocation: Bool
- isLoadingStops: Bool
- errorMessage: String?

Features:
- Apple Maps local search with suggestions
- Places-first search that loads nearby stops (Sao Paulo metro only)
- Search results list with distance hints
- Sheet navigation to StopDetailView
```

#### MapExplorerView & MapExplorerViewModel
```swift
Published Properties:
- region: MKCoordinateRegion
- stops: [Stop]
- isLoading: Bool
- showRefreshButton: Bool
- errorMessage: String?
- searchQuery: String
- searchSuggestions: [MKLocalSearchCompletion]
- isSearchingLocation: Bool
- searchErrorMessage: String?

Features:
- MapKit integration
- Stop annotations display
- Searchable map with local suggestions (Sao Paulo metro only)
- Region change detection (>500m threshold)
- Manual refresh capability
- Center on user location button
- 500ms debounce on region changes
```

#### StopDetailView & StopDetailViewModel
```swift
Published Properties:
- stop: Stop
- arrivals: [Arrival]
- isLoading: Bool
- isFavorite: Bool
- errorMessage: String?
- selectedArrival: Arrival?
- journeyStops: [Stop]
- journeyShape: [Location]
- isLoadingJourney: Bool
- journeyErrorMessage: String?

Features:
- Real-time arrival countdown
- Auto-refresh every 30 seconds
- Pull-to-refresh support
- Favorite/unfavorite toggle
- Wait time status color coding
- Empty state handling
- Journey preview when a route is selected (map shape + stop timeline)
```

#### SystemStatusView & SystemStatusViewModel
```swift
Published Properties:
- metroLines: [MetroLine]
- overallStatus: String
- isLoading: Bool
- errorMessage: String?

Data:
- Hardcoded 12 São Paulo metro lines (L1-L5, L7-L13)
- Lines include: colors, names, status
- 1-second mock API delay
```

#### Common Components
- **LoadingView** - Loading spinner overlay
- **ErrorView** - Error message display with retry
- **GlassCard** - Glassmorphism card component
- **CountdownTimer** - Countdown display for arrivals
- **RouteBadge** - Route number/name badge
- **View+Extensions** - Custom SwiftUI modifier extensions

#### Styling
- **AppColors.swift** - All colors (brand, metro lines, semantic)
- **AppFonts.swift** - Font size definitions
- **Assets.xcassets** - Color sets and icons

---

### 2. APPLICATION LAYER (Use Cases)

**Location**: `/Application/UseCases`
**Responsibility**: Business logic and orchestration

#### GetNearbyStopsUseCase
```swift
func execute(limit: Int = 10, location: Location?) async throws -> [Stop]

Error:
- LocationError.locationUnavailable

Dependencies:
- TransitRepositoryProtocol
- LocationServiceProtocol
```
Fetches nearby bus stops using provided location or device location.

#### GetArrivalsUseCase
```swift
func execute(stopId: Int, limit: Int = 10) async throws -> [Arrival]

Dependencies:
- TransitRepositoryProtocol
```
Fetches upcoming bus arrivals for a specific stop.

#### SearchStopsUseCase
```swift
func execute(query: String, limit: Int = 10) async throws -> [Stop]

Dependencies:
- TransitRepositoryProtocol
```
Searches for bus stops by name or query string.

#### GetTripRouteUseCase
```swift
func execute(tripId: String) async throws -> TripStop
```
Retrieves trip details with all stops (used for the Journey preview).

#### GetRouteShapeUseCase
```swift
func execute(shapeId: String) async throws -> [Location]

Dependencies:
- TransitRepositoryProtocol
```
Fetches GPS coordinates representing a route's shape for map visualization.

#### GetMetroStatusUseCase
```swift
func execute() -> [MetroLine]

Dependencies: None (returns hardcoded metro lines)
```
Returns status of all 12 São Paulo metro lines.

---

### 3. DOMAIN LAYER

**Location**: `/Domain`
**Responsibility**: Core business entities and protocols (framework-independent)

#### Core Entities

**Stop**
```swift
struct Stop: Codable, Identifiable {
    let stopId: Int
    let stopName: String
    let location: Location
    let stopSequence: Int
    let stopCode: String
    let wheelchairBoarding: Int  // 0=unknown, 1=yes, 2=no
}
```

**Arrival**
```swift
struct Arrival: Identifiable {
    let id: UUID
    let tripId: String
    let routeId: String
    let routeShortName: String
    let routeLongName: String
    let headsign: String                    // Direction/destination
    let arrivalTime: String                 // HH:MM:SS format
    let departureTime: String               // HH:MM:SS format
    let stopId: Int
    let stopSequence: Int
    let routeType: Int
    let routeColor: String                  // HEX color
    let routeTextColor: String              // HEX color
    let frequency: Int?                     // Minutes (if frequency-based service)
    let waitTime: Int                       // Minutes until arrival

    // Computed properties:
    var waitTimeStatus: WaitTimeStatus      // arriving, soon, scheduled
    var formattedWaitTime: String           // "Now", "1 min", "5 min"
}

enum WaitTimeStatus {
    case arriving                           // 0-3 minutes
    case soon                               // 4-10 minutes
    case scheduled                          // 10+ minutes
}
```

**Route**
```swift
struct Route {
    let routeId: String
    let agencyId: Int
    let routeShortName: String              // "101", "202", etc.
    let routeLongName: String               // Full route name
    let routeDesc: String
    let routeType: Int                      // 3=bus
    let routeColor: String                  // HEX color
    let routeTextColor: String              // HEX color
}
```

**Trip**
```swift
struct Trip {
    let routeId: String
    let serviceId: String                   // Calendar service ID
    let tripId: String
    let tripHeadsign: String                // Destination
    let directionId: Int                    // 0 or 1
    let shapeId: String                     // For map visualization
}
```

**TripStop**
```swift
struct TripStop {
    let trip: Trip
    let stops: [Stop]                       // All stops in sequence
}
```

**Location**
```swift
struct Location: Codable {
    let latitude: Double
    let longitude: Double

    // Convenience:
    static let saoPaulo = Location(latitude: -23.5505, longitude: -46.6333)
    func toCLLocationCoordinate2D() -> CLLocationCoordinate2D
}
```

**MetroLine**
```swift
struct MetroLine {
    let line: String                        // "L1", "L2"
    let name: String                        // "Azul", "Verde"
    let colorHex: String                    // "0455A1"
}

// Color reference:
// L1 Azul: #0455A1
// L2 Verde: #007E5E
// L3 Vermelha: #EE372F
// L4 Amarela: #FFD700
// L5 Lilás: #9B3894
// L7 Rubi: #CA016B
// L8 Diamante: #97A098
// L9 Esmeralda: #01A9A7
// L10 Turquesa: #008B8B
// L11 Coral: #F04E23
// L12 Safira: #083D8B
// L13 Jade: #00B352
```

#### Protocols

**TransitRepositoryProtocol**
```swift
func getNearbyStops(location: Location, limit: Int) async throws -> [Stop]
func getArrivals(stopId: Int, limit: Int) async throws -> [Arrival]
func searchStops(query: String, limit: Int) async throws -> [Stop]
func getShape(shapeId: String) async throws -> [Location]
func getAllRoutes(limit: Int, offset: Int) async throws -> [Route]
func getTrip(tripId: String) async throws -> TripStop
func getRoute(routeId: String) async throws -> Route
```

**LocationServiceProtocol**
```swift
func requestLocationPermission()
func getCurrentLocation() -> Location?
func startUpdatingLocation()
func stopUpdatingLocation()
```

**StorageServiceProtocol**
```swift
func saveFavorite(stop: Stop)
func removeFavorite(stop: Stop)
func isFavorite(stopId: Int) -> Bool
func getFavoriteStops() -> [Stop]
func saveHome(location: Location)
func getHomeLocation() -> Location?
func saveWork(location: Location)
func getWorkLocation() -> Location?
```

---

### 4. INFRASTRUCTURE LAYER

**Location**: `/Infrastructure`
**Responsibility**: Network requests, database access, external services

#### Network Layer

**APIClient**
```swift
func request<T: Decodable>(endpoint: APIEndpoint) async throws -> T

Features:
- Generic typing for any response type
- Automatic JSON decoding
- HTTP status validation (200-299)
- Error handling with APIError
- Uses URLSession
```

**APIError**
```swift
enum APIError: Error {
    case invalidURL
    case invalidResponse
    case requestFailed(Error)
    case decodingFailed(Error)
}
```

**APIEndpoint**
```swift
Base URL: https://sptrans.lolados.app/api

Available endpoints:
- GET /nearby.php?lat={lat}&lon={lon}&limit={limit}
- GET /arrivals.php?stop_id={stopId}&limit={limit}
- GET /search.php?q={query}
- GET /trip.php?trip_id={tripId}
- GET /shape.php?shape_id={shapeId}
- GET /stop.php?stop_id={stopId}
- GET /routes.php?limit={limit}&offset={offset}

Response format: JSON with decoded models
```

**Data Transfer Objects (DTOs)**

Located in `/Infrastructure/Network/DTOs/`:
- **StopDTO** - Maps to Stop entity
- **ArrivalDTO** - Maps to Arrival entity
- **RouteDTO** - Maps to Route entity
- **TripDTO** - Maps to Trip and TripStop entities
- **LocationDTO** - Maps to Location entity

All DTOs are Codable for JSON decoding.

#### Repositories

**TransitAPIRepository** (implements TransitRepositoryProtocol)
```swift
Methods:
- getNearbyStops(location:limit:)     // ✓ Implemented
- getArrivals(stopId:limit:)          // ✓ Implemented
- searchStops(query:limit:)           // ✓ Implemented
- getShape(shapeId:)                  // ✓ Implemented
- getAllRoutes(limit:offset:)         // ✓ Implemented
- getTrip(tripId:)                    // ✓ Implemented
- getRoute(routeId:)                  // ✗ Not implemented (fatalError)

Dependencies:
- APIClient - for HTTP requests
```

#### Services

**CoreLocationService** (implements LocationServiceProtocol)
```swift
Features:
- Uses CLLocationManager
- Requests when-in-use authorization
- Accuracy: .reduced (500 meters)
- Caches current location
- Auto-updates on location changes

Methods:
- requestLocationPermission()
- getCurrentLocation() -> Location?
- startUpdatingLocation()
- stopUpdatingLocation()
```

**UserDefaultsStorageService** (implements StorageServiceProtocol)
```swift
Storage keys:
- "favoriteStops" - [Stop] array
- "homeLocation" - Location object
- "workLocation" - Location object

Methods:
- saveFavorite(stop:)
- removeFavorite(stop:)
- isFavorite(stopId:) -> Bool
- getFavoriteStops() -> [Stop]
- saveHome(location:)
- getHomeLocation() -> Location?
- saveWork(location:)
- getWorkLocation() -> Location?
```

#### Mappers

**DTOMappers** (extension methods)
```swift
StopDTO.toDomain() -> Stop
NearbyStopDTO.toDomain() -> Stop
ArrivalDTO.toDomain(stopId: Int) -> Arrival
TripDTO.toDomain() -> Trip
TripDTO.toTripStop() -> TripStop
RouteDTO.toDomain() -> Route
LocationDTO.toDomain() -> Location
```

---

### 5. APP ENTRY POINT & DEPENDENCY INJECTION

**sp_trains_busApp.swift**
- Initializes AppDependencies
- Creates @StateObject for MainTabView
- Sets up SceneDelegate and WindowGroup

**AppDependencies.swift**
```swift
Single source of truth for all dependencies:

@MainActor
class AppDependencies: ObservableObject {
    // Infrastructure
    let apiClient: APIClient
    let locationService: CoreLocationService
    let storageService: UserDefaultsStorageService

    // Data Access
    let transitRepository: TransitAPIRepository

    // Use Cases
    let getNearbyStopsUseCase: GetNearbyStopsUseCase
    let getArrivalsUseCase: GetArrivalsUseCase
    let searchStopsUseCase: SearchStopsUseCase
    let getTripRouteUseCase: GetTripRouteUseCase
    let getRouteShapeUseCase: GetRouteShapeUseCase
    let getMetroStatusUseCase: GetMetroStatusUseCase

    // ViewModels
    let homeViewModel: HomeViewModel
    let searchViewModel: SearchViewModel
    let stopDetailViewModel: StopDetailViewModel
    let mapExplorerViewModel: MapExplorerViewModel
    let systemStatusViewModel: SystemStatusViewModel
}
```

All instances are created once at app launch and shared throughout the app.

---

## Key Patterns & Best Practices

### 1. Async/Await
All network requests and heavy operations use `async/await`:
```swift
try await useCase.execute()
```

### 2. MVVM with @Published
ViewModels publish state changes:
```swift
@Published var stops: [Stop] = []
@Published var isLoading = false
@Published var errorMessage: String?
```

### 3. Protocol-Oriented Programming
Services are accessed through protocols for testability:
```swift
class MyViewModel {
    init(repository: TransitRepositoryProtocol) {
        self.repository = repository
    }
}
```

### 4. DTO to Domain Mapping
Network responses converted to domain models:
```swift
let stopDTO: StopDTO = try JSONDecoder().decode(...)
let stop: Stop = stopDTO.toDomain()
```

### 5. Error Handling
Proper error propagation and user feedback:
```swift
if let error = viewModel.errorMessage {
    ErrorView(message: error)
}
```

### 6. State Management
- Loading, Error, and Data states handled in ViewModels
- UI reacts to @Published properties
- No direct API calls from Views

### 7. Debouncing
Search and map region changes are debounced to reduce API calls:
```swift
// SearchViewModel: 300ms debounce on search text (MapKit suggestions)
// MapExplorerViewModel: 500ms debounce on region changes
```

---

## Testing

**Location**: `/Tests`

### Test Files

1. **ViewModelsTests.swift**
   - HomeViewModel loading and error handling
   - StopDetailViewModel arrivals
   - SystemStatusViewModel metro status
   - MapExplorerViewModel stops
   - SearchViewModel initial state

2. **UseCasesTests.swift**
   - All 6 use cases with success and error scenarios
   - Location unavailable error handling
   - Mock repository and location service

3. **NetworkLayerTests.swift**
   - APIClient success and error handling
   - All 7 API endpoints
   - JSON decoding validation
   - Mock URLSession

4. **DomainLayerTests.swift**
   - Entity creation and validation
   - Computed properties

5. **ServiceLayerTests.swift**
   - CoreLocationService behavior
   - UserDefaultsStorageService persistence

### Running Tests
```bash
Xcode: ⌘U
Command Line: xcodebuild test
```

---

## Common Tasks

### Add a New View
1. Create `YourView.swift` in `/Presentation/{Screen}/`
2. Create `YourViewModel.swift` in same directory
3. Add @Published properties for state
4. Declare use case in `__init__`
5. Implement data loading in `onAppear` or `init`
6. Add to `MainTabView` if needed

### Add a New API Endpoint
1. Create DTO in `/Infrastructure/Network/DTOs/`
2. Add case to `APIEndpoint` enum
3. Implement DTO-to-domain mapper
4. Add method to `TransitAPIRepository`
5. Create use case if needed
6. Use in ViewModel

### Add Local Storage
1. Implement methods in `UserDefaultsStorageService`
2. Add Codable conformance to domain entities
3. Use storage service in ViewModels

### Modify Domain Model
1. Update entity in `/Domain/Entities/`
2. Update DTO in `/Infrastructure/Network/DTOs/`
3. Update mapper in `/Infrastructure/Mappers/`
4. Update ViewModel/View if needed

---

## Color Reference

### System Colors
- **Primary**: App brand color
- **Accent**: Secondary highlight color
- **Background**: Page/card backgrounds
- **Text**: Text and foreground elements
- **Light Gray**: Subtle backgrounds

### Metro Line Colors
All 12 São Paulo metro lines with hex colors defined in `AppColors.swift`.

---

## Debugging Tips

1. **Location Permission Issues**
   - Check Info.plist for NSLocationWhenInUseUsageDescription
   - Test on device (simulator has limited location)

2. **API Errors**
   - Enable URLSession logging for network debugging
   - Check API endpoint URLs in APIEndpoint.swift
   - Verify base URL: https://sptrans.lolados.app/api

3. **ViewModel State Not Updating**
   - Ensure properties are @Published
   - Check that async operations are on @MainActor
   - Verify observers are properly retained

4. **Map Not Showing Stops**
   - Verify location service returns valid coordinates
   - Check stop annotations are created properly
   - Ensure MapKit permissions are granted

5. **Storage Issues**
   - UserDefaults key names must match exactly
   - Ensure domain models are Codable
   - Check for key collisions

---

## Performance Considerations

1. **Network Requests**
   - Debounced search (500ms) and map region changes
   - Limited results with `limit` parameter
   - Nearby stops limited to 10 by default

2. **Location Updates**
   - Accuracy set to .reduced (500m) to save battery
   - Manual permission request for user control
   - Caching of current location

3. **UI Rendering**
   - Use `.lazy` for large lists
   - Separate components for reusability
   - Avoid unnecessary redraws

4. **Memory**
   - Singleton dependencies (AppDependencies)
   - Proper cleanup in deinit if needed
   - Circular reference prevention with weak self

---

## File Size Statistics

- **Total Swift Files**: 69
- **Lines of Code**: ~3,587
- **Test Coverage**: 5 comprehensive test suites
- **ViewModels**: 5
- **Use Cases**: 6
- **Domain Entities**: 7
- **UI Views & Components**: 20+
- **API Endpoints**: 7

---

## Quick Command Reference

| Command | Purpose |
|---------|---------|
| ⌘B | Build project |
| ⌘R | Run on simulator |
| ⌘U | Run tests |
| ⌘K | Clear build folder |
| ⌘⇧K | Clean build folder |
| ⌘⌥0 | Hide/show utility pane |
| ⌘⌥1 | Show file inspector |
| ⌘⌥2 | Show quick help |

---

## External Dependencies

**Core Frameworks** (no external packages):
- SwiftUI
- Combine
- MapKit
- CoreLocation
- Foundation

All networking, storage, and location services built from scratch using native iOS frameworks.

---

## Next Steps / TODOs

- [ ] Implement GetRouteUseCase (currently fatalError)
- [ ] Complete "Nearby" tab (currently placeholder)
- [ ] Add offline data caching
- [ ] Implement favorites sync to backend
- [ ] Add real-time arrivals via WebSocket
- [ ] Expand metro status with live updates
- [ ] Add accessibility support (VoiceOver)
- [ ] Implement app shortcuts/Siri integration
- [ ] Add widget support (Lock Screen/Home Screen)

---

**Last Updated**: 2026-02-03
**Architecture**: Clean Architecture + MVVM
**Status**: Production Ready (with TODOs)
