#!/bin/bash
set -euo pipefail
# The Xcode project currently has no test target. Run the planner's real domain,
# API and detail view model in an isolated macOS Swift package without editing it.
planner_root="$(cd "$(dirname "$0")/.." && pwd)"
planner_package="$(mktemp -d "${TMPDIR:-/tmp}/duesp-planner-tests.XXXXXX")"
trap 'rm -rf "$planner_package"' EXIT
mkdir -p "$planner_package/Sources/sp_trains_bus" "$planner_package/Tests/PlannerTests"
cat > "$planner_package/Package.swift" <<'PACKAGE'
// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "JourneyPlannerChecks", platforms: [.macOS(.v14)], targets: [
    .target(name: "sp_trains_bus"),
    .testTarget(name: "PlannerTests", dependencies: ["sp_trains_bus"], resources: [.copy("Fixtures")])
])
PACKAGE
for planner_source in \
    Domain/Entities/{Location,Stop,Trip,TripStop,Route,Arrival,ArrivalsPageDirection,TripPlan,JourneyConditions}.swift \
    Domain/Protocols/{TransitRepositoryProtocol,LocationServiceProtocol}.swift \
    Application/UseCases/{PlanTripUseCase,GetTripRouteUseCase,GetRouteShapeUseCase}.swift \
    Infrastructure/Network/{APIClient,APIEndpoint,APIError}.swift \
    Infrastructure/Network/DTOs/{PlanDTO,StopDTO,TripDTO,RouteDTO,ArrivalDTO,LocationDTO,RailAlertSubscriptionDTO,RailStatusDTO}.swift \
    Infrastructure/Mappers/DTOMappers.swift \
    Infrastructure/Repositories/TransitAPIRepository.swift \
    Infrastructure/Services/JourneyConditionsStore.swift \
    Infrastructure/Analytics/AnalyticsServiceProtocol.swift \
    Presentation/Common/Extensions/MKCoordinateRegion+Extensions.swift \
    Presentation/Common/Styles/LineColor.swift \
    Presentation/Search/{TripPlanDetailViewModel,SearchViewModel}.swift; do
    cp "$planner_root/$planner_source" "$planner_package/Sources/sp_trains_bus/"
done
# Only UIKit's palette is substituted; all routing, decoding and map assembly
# use the production files above. The full iOS build validates the actual UI.
cat > "$planner_package/Sources/sp_trains_bus/TestPalette.swift" <<'PALETTE'
struct AppColors {
    struct PaletteColor { let hexString: String }
    static let darkGray = PaletteColor(hexString: "666666")
    static let accent = PaletteColor(hexString: "007AFF")
}
PALETTE
cp "$planner_root/Tests/JourneyPlannerTests.swift" "$planner_package/Tests/PlannerTests/"
cp -R "$planner_root/Tests/Fixtures" "$planner_package/Tests/PlannerTests/"
swift test --package-path "$planner_package"
