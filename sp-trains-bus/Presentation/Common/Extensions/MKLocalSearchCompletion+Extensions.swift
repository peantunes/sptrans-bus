import MapKit

extension MKLocalSearchCompletion {
    var stableIdentifier: String {
        "\(title)|\(subtitle)"
    }
}
