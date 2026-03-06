import AppIntents

enum WatchRailWidgetLineOption: String, CaseIterable, AppEnum {
    case metro1 = "metro-1"
    case metro2 = "metro-2"
    case metro3 = "metro-3"
    case metro4 = "metro-4"
    case metro5 = "metro-5"
    case metro15 = "metro-15"
    case cptm7 = "cptm-7"
    case cptm8 = "cptm-8"
    case cptm9 = "cptm-9"
    case cptm10 = "cptm-10"
    case cptm11 = "cptm-11"
    case cptm12 = "cptm-12"
    case cptm13 = "cptm-13"

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Rail Line")
    }

    static var caseDisplayRepresentations: [WatchRailWidgetLineOption: DisplayRepresentation] {
        [
            .metro1: DisplayRepresentation(title: "Metro L1 Azul"),
            .metro2: DisplayRepresentation(title: "Metro L2 Verde"),
            .metro3: DisplayRepresentation(title: "Metro L3 Vermelha"),
            .metro4: DisplayRepresentation(title: "Metro L4 Amarela"),
            .metro5: DisplayRepresentation(title: "Metro L5 Lilas"),
            .metro15: DisplayRepresentation(title: "Metro L15 Prata"),
            .cptm7: DisplayRepresentation(title: "CPTM L7 Rubi"),
            .cptm8: DisplayRepresentation(title: "CPTM L8 Diamante"),
            .cptm9: DisplayRepresentation(title: "CPTM L9 Esmeralda"),
            .cptm10: DisplayRepresentation(title: "CPTM L10 Turquesa"),
            .cptm11: DisplayRepresentation(title: "CPTM L11 Coral"),
            .cptm12: DisplayRepresentation(title: "CPTM L12 Safira"),
            .cptm13: DisplayRepresentation(title: "CPTM L13 Jade")
        ]
    }
}

struct WatchRailStatusWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Watch Rail Focus"
    static var description = IntentDescription("Optionally pick one line to pin in the rail status complication.")

    @Parameter(title: "Selected line")
    var selectedLine: WatchRailWidgetLineOption?
}

extension WatchRailStatusWidgetIntent {
    var selectedLineKey: String? {
        selectedLine?.rawValue
    }
}
