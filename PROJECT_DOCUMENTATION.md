# SPTrans Bus - Project Documentation

## Overview
A comprehensive São Paulo public transit information system for bus arrivals, routes, and stops. Full-stack application with PHP backend REST API and iOS SwiftUI frontend.

---

## Project Structure

```
/sptrans-bus
├── /server (PHP backend)
│   ├── /api (REST API endpoints)
│   ├── /inc (Core backend classes)
│   ├── /data_import (GTFS data import scripts)
│   ├── /web (Web interface)
│   ├── docker-compose.yml
│   ├── Dockerfile
│   └── config.php
│
└── /sp-trains-bus (iOS app - ~3,587 lines Swift)
    ├── /App (Entry point)
    ├── /Application (Use cases layer)
    ├── /Domain (Business entities & protocols)
    ├── /Infrastructure (Network, repos, services)
    ├── /Presentation (UI layer)
    ├── /Resources (Assets)
    ├── /Tests
    └── sp-trains-bus.xcodeproj
```

---

## Technology Stack

### Backend
- **Language**: PHP 8.3
- **Server**: Apache with mod_rewrite
- **Database**: MySQL 8.0
- **Containerization**: Docker & Docker Compose
- **Data Format**: GTFS (General Transit Feed Specification)
- **Architecture**: RESTful API, Service-Oriented

### iOS Frontend
- **Language**: Swift
- **Framework**: SwiftUI
- **Architecture**: Clean Architecture (Presentation → Application → Domain → Infrastructure)
- **Pattern**: MVVM with Use Cases
- **Key Services**: CoreLocation, UserDefaults

---

## Backend - REST API Endpoints

**Base Structure**: `/server/api/`

1. **arrivals.php** - Get upcoming bus arrivals at a stop
2. **stop.php** - Get stop details
3. **route.php** - Get route information
4. **routes.php** - List all routes (paginated)
5. **trip.php** - Get trip/route details
6. **shape.php** - Get map shape points (GeoJSON support)
7. **search.php** - Search stops by name
8. **nearby.php** - Find stops near coordinates

### Core Backend Classes

**TransitService.class.php** - Main transit business logic
- 10+ service methods for transit operations
- Calendar-aware scheduling queries
- Frequency-based arrival calculations
- Stop search and nearby discovery

**Conexao.class.php** - Database abstraction layer
- Multi-database support: MySQL, Oracle, PostgreSQL, MSSQL
- Prepared statements for security
- Transaction support

---

## iOS App Architecture

### Presentation Layer
- **Views**: Home, Search, Map, StopDetail, SystemStatus
- **ViewModels**: Manage UI state and business logic
- **Framework**: SwiftUI

### Application Layer (Use Cases)
- GetNearbyStopsUseCase
- GetArrivalsUseCase
- SearchStopsUseCase
- GetTripRouteUseCase
- GetRouteShapeUseCase
- GetMetroStatusUseCase

### Domain Layer
**Core Business Entities**:
- Stop
- Route
- Trip
- Arrival
- Location

### Infrastructure Layer
- **Network**: APIClient + DTOs
- **Repositories**: TransitAPIRepository
- **Services**: CoreLocationService, UserDefaultsStorageService
- **Mappers**: DTO to Domain model conversions

### Entry Points
- `sp_trains_busApp.swift` - App entry point
- `AppDependencies.swift` - Dependency injection container
- `MainTabView.swift` - Main UI container with tab navigation

---

## Database Schema

### Core Tables
- **sp_stop** - Bus stop locations and information
- **sp_routes** - Bus route definitions
- **sp_trip** - Trip/run instances
- **sp_stop_times** - Schedule (when buses arrive at each stop)
- **sp_shapes** - Map coordinates for route visualization
- **sp_frequencies** - Service frequency information
- **sp_calendar** - Service calendar and day-of-week schedules
- **sp_fare_att** - Fare attributes
- **sp_fare_rules** - Fare rules and pricing

---

## Docker Setup

**Services**:
- **PHP**: Port 8080 (Apache with mod_rewrite)
- **MySQL**: Port 3306

**Configuration**:
- Database: `lolados_bus`
- User: `lolados_bus`
- Timezone: America/Sao_Paulo

**Files**:
- `docker-compose.yml` - Service definitions
- `Dockerfile` - PHP/Apache image build

---

## Data Import Process

**Location**: `/server/data_import/`

**Tools**:
- `import_gtfs.php` - PHP-based GTFS importer
- `import_gtfs.py` - Python-based GTFS importer (requires mysql-connector-python)

**Process**:
1. Parse GTFS feed files (CSV format)
2. Import into respective database tables
3. Maps GTFS stops, trips, routes, shapes, frequencies, and calendar data

---

## Key Features

1. **Real-time Bus Arrivals** - Predictions based on frequency/schedule data
2. **Stop Search** - Find stops by name or location
3. **Nearby Stops** - Geolocation-based discovery
4. **Route Information** - Complete route details with all stops in sequence
5. **Trip Details** - Specific trip information with timestamps
6. **Shape Visualization** - GeoJSON support for map rendering
7. **Fare Information** - Fare lookups based on routes/stops
8. **Calendar-aware Scheduling** - Considers day-of-week operations
9. **Frequency-based Calculations** - Mathematical offsets for arrivals
10. **Favorites/Bookmarks** - User preferences storage

---

## Security Considerations

- **SQL Injection Protection**: Prepared statements used throughout backend
- **Input Validation**: API endpoints validate input parameters
- **Database Abstraction**: Connection class provides security layer
- **Multi-database Support**: Flexibility without sacrificing security

---

## Development Workflow

### Configuration Entry Point
- `/server/config.php` - Central configuration management

### Asset Management (iOS)
- Custom color palette: PrimaryColor, AccentColor, TextColor, BackgroundColor
- Asset catalog in Xcode project

### Testing
- iOS project includes test suite (`/Tests` directory)

---

## Data Flow

```
iOS App
  ↓
REST API (/server/api/)
  ↓
TransitService (Business Logic)
  ↓
MySQL Database (8.0)
  ↓
[GTFS Data imported via PHP/Python importers]
```

---

## Notable Architecture Decisions

1. **Clean Architecture (iOS)**: Layered approach for testability and maintainability
2. **MVVM Pattern**: ViewModel manages state and use cases
3. **Use Cases**: Application layer isolates business logic
4. **Service-Oriented Backend**: Stateless API design for scalability
5. **Database Abstraction**: Multi-database support via connection class
6. **Calendar-aware Queries**: Domain knowledge embedded in SQL logic
7. **GTFS Standard**: Industry-standard transit data format

---

## Recent Commits
- c55bdbc - removing txt files
- 53e94d1 - git ignore update
- 4239190 - fixing model
- 921d8f2 - small fixes
- 48d3ca7 - improvements

---

## Quick Reference

| Component | Technology | Location |
|-----------|-----------|----------|
| API Server | PHP 8.3 + Apache | `/server/api/` |
| Database | MySQL 8.0 | Docker service |
| Core Logic | TransitService | `/server/inc/TransitService.class.php` |
| iOS App | Swift + SwiftUI | `/sp-trains-bus/` |
| Config | PHP config | `/server/config.php` |
| Data Import | PHP/Python | `/server/data_import/` |

---

## Getting Started

1. **Backend**: Run `docker-compose up` in `/server`
2. **iOS**: Open `sp-trains-bus.xcodeproj` in Xcode
3. **API**: Access endpoints at `http://localhost:8080/api/`
4. **Database**: Connect to `localhost:3306` (MySQL)

---

**Last Updated**: 2026-02-03
**Project Status**: Active Development (based on recent commits)
