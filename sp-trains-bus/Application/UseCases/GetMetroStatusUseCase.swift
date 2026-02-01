import Foundation

class GetMetroStatusUseCase {
    func execute() -> [MetroLine] {
        return [
            MetroLine(line: "L1", name: "Azul", colorHex: "0455A1"),
            MetroLine(line: "L2", name: "Verde", colorHex: "007E5E"),
            MetroLine(line: "L3", name: "Vermelha", colorHex: "EE372F"),
            MetroLine(line: "L4", name: "Amarela", colorHex: "FFD700"),
            MetroLine(line: "L5", name: "Lilás", colorHex: "9B3894"),
            MetroLine(line: "L7", name: "Rubi", colorHex: "CA016B"),
            MetroLine(line: "L8", name: "Diamante", colorHex: "97A098"),
            MetroLine(line: "L9", name: "Esmeralda", colorHex: "01A9A7"),
            MetroLine(line: "L10", name: "Turquesa", colorHex: "008B8B"),
            MetroLine(line: "L11", name: "Coral", colorHex: "F04E23"),
            MetroLine(line: "L12", name: "Safira", colorHex: "083D8B"),
            MetroLine(line: "L13", name: "Jade", colorHex: "00B352")
        ]
    }
}
