import SwiftUI

extension View {
    @ViewBuilder
    func hidden(_ shouldHide: Bool) -> some View {
        if shouldHide {
            self.hidden()
        } else {
            self
        }
    }

    func onAppear(perform action: (() -> Void)? = nil) -> some View {
        self.onAppear {
            action?()
        }
    }
}
