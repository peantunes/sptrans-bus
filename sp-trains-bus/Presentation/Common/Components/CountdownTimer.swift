import SwiftUI
import Combine

struct CountdownTimer: View {
    @State private var remainingTime: Int
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(seconds: Int) {
        _remainingTime = State(initialValue: seconds)
    }

    var body: some View {
        Text(timeString(from: remainingTime))
            .onReceive(timer) { _ in
                if remainingTime > 0 {
                    remainingTime -= 1
                }
            }
    }

    private func timeString(from seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

#Preview {
    CountdownTimer(seconds: 120)
}
