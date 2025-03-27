import SwiftUI
@preconcurrency import WebKit

struct MusicBrainzLoginView: View {
    @Binding var isPresented: Bool
    let onLoginSuccess: (String) -> Void
    @State private var webView: WKWebView?
    
    var body: some View {
        NavigationView {
            WebView(webView: $webView, onLoginSuccess: onLoginSuccess)
                .navigationTitle("Login to MusicBrainz")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            print("MusicBrainzLoginView: Cancel button tapped")
                            isPresented = false
                        }
                    }
                }
                .onAppear {
                    print("MusicBrainzLoginView: View appeared")
                    loadLoginPage()
                }
        }
    }
    
    private func loadLoginPage() {
        print("MusicBrainzLoginView: Loading login page")
        guard let url = URL(string: "https://musicbrainz.org/login") else { return }
        let request = URLRequest(url: url)
        webView?.load(request)
    }
}

struct WebView: UIViewRepresentable {
    @Binding var webView: WKWebView?
    let onLoginSuccess: (String) -> Void
    
    func makeUIView(context: Context) -> WKWebView {
        print("WebView: Creating web view")
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        self.webView = webView
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        private var hasCheckedForSession = false
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url {
                print("WebView: Navigation to \(url.path)")
            }
            decisionHandler(.allow)
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let url = webView.url {
                print("WebView: Page finished loading: \(url.path)")
                
                // Check for session cookie after page has loaded
                if !hasCheckedForSession {
                    print("WebView: Checking for session cookie")
                    hasCheckedForSession = true
                    
                    // Get the session cookie
                    webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                        print("WebView: Found \(cookies.count) cookies")
                        for cookie in cookies {
                            print("WebView: Cookie - Name: \(cookie.name), Value: \(cookie.value), Domain: \(cookie.domain), Path: \(cookie.path)")
                        }
                        
                        if let sessionCookie = cookies.first(where: { $0.name == "musicbrainz_server_session" }) {
                            print("WebView: Found session cookie")
                            DispatchQueue.main.async {
                                // Store the session cookie
                                MusicBrainzClient.shared.setSession(sessionCookie.value)
                                print("WebView: Stored session cookie")
                                // Call the success callback
                                self.parent.onLoginSuccess(sessionCookie.value)
                                print("WebView: Called success callback")
                            }
                        } else {
                            print("WebView: No session cookie found")
                            // If we're on the homepage or user profile and no session cookie is found, we need to log in
                            if url.path == "/" || url.path.hasPrefix("/user/") {
                                print("WebView: On homepage or user profile with no session, redirecting to login")
                                webView.load(URLRequest(url: URL(string: "https://musicbrainz.org/login")!))
                            }
                        }
                    }
                }
            }
        }
    }
}
