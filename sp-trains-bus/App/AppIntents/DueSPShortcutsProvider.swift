import AppIntents

struct DueSPShortcutsProvider: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor {
        .blue
    }

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetNextArrivalsIntent(),
            phrases: [
                "Check arrivals at \(\.$stop) in \(.applicationName)",
                "When is the next bus at \(\.$stop) in \(.applicationName)",
                "Ver proximas chegadas em \(\.$stop) no \(.applicationName)",
                "Quando passa o proximo onibus em \(\.$stop) no \(.applicationName)"
            ],
            shortTitle: "intent.shortcut.arrivals.title",
            systemImageName: "bus"
        )

        AppShortcut(
            intent: CheckRailStatusIntent(),
            phrases: [
                "Check rail status in \(.applicationName)",
                "How are Metro and CPTM now in \(.applicationName)",
                "CPTM status in \(.applicationName)",
                "Metro status in \(.applicationName)",
                "Metrô status in \(.applicationName)",
                "Ver status ferroviario no \(.applicationName)",
                "Como esta Metro e CPTM agora no \(.applicationName)",
                "Status da CPTM no \(.applicationName)",
                "Status do Metro no \(.applicationName)",
                "Status do Metrô no \(.applicationName)"
            ],
            shortTitle: "intent.shortcut.rail.title",
            systemImageName: "tram.fill.tunnel"
        )

        AppShortcut(
            intent: OpenStopIntent(),
            phrases: [
                "Open stop \(\.$stop) in \(.applicationName)",
                "Show stop \(\.$stop) in \(.applicationName)",
                "Abrir parada \(\.$stop) no \(.applicationName)",
                "Mostrar parada \(\.$stop) no \(.applicationName)"
            ],
            shortTitle: "intent.shortcut.open_stop.title",
            systemImageName: "mappin.and.ellipse"
        )
    }
}
