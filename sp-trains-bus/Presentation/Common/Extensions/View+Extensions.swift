import SwiftUI
import UIKit

extension View {
    @ViewBuilder
    func hidden(_ shouldHide: Bool) -> some View {
        if shouldHide {
            self.hidden()
        } else {
            self
        }
    }

    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

//    func onAppear(perform action: (() -> Void)? = nil) -> some View {
//        self.onAppear {
//            action?()
//        }
//    }
}
