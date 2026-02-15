import SwiftUI
import WebKit

struct SettingsWebView: View {
    let title: String
    let url: URL
    let analyticsService: AnalyticsServiceProtocol
    let analyticsSource: String

    var body: some View {
        WebView(url: url)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                analyticsService.trackScreen(name: "SettingsWebView", className: "SettingsWebView")
                analyticsService.trackEvent(
                    name: "settings_webview_opened",
                    properties: [
                        "source": analyticsSource,
                        "url": url.absoluteString
                    ]
                )
            }
    }
}

private struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard webView.url != url else { return }
        webView.load(URLRequest(url: url))
    }
}

#Preview {
    NavigationStack {
        SettingsWebView(
            title: "Website",
            url: URL(string: "https://sptrans.lolados.app")!,
            analyticsService: NoOpAnalyticsService(),
            analyticsSource: "website"
        )
    }
}
