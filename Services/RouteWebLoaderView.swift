import SwiftUI
import WebKit

struct RouteWebLoaderView: UIViewRepresentable {
    let urlString: String
    let onJSONExtracted: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onJSONExtracted: onJSONExtracted)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "jsonHandler")
        config.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        if let url = URL(string: urlString) {
            var request = URLRequest(url: url)
            // Use a desktop-like UA to improve parity
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
            webView.load(request)
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let onJSONExtracted: (String) -> Void
        init(onJSONExtracted: @escaping (String) -> Void) {
            self.onJSONExtracted = onJSONExtracted
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // JavaScript to search for a large JSON object within <script> tags
            let js = """
            (function() {
              try {
                const scripts = Array.from(document.scripts);
                for (const s of scripts) {
                  const t = s.textContent || '';
                  if (!t) continue;
                  // Heuristic: look for a top-level JSON object and limit size to avoid huge posts
                  const start = t.indexOf('{');
                  const end = t.lastIndexOf('}');
                  if (start !== -1 && end !== -1 && end > start) {
                    const candidate = t.slice(start, end + 1);
                    // Basic sanity check: must contain common route keys
                    if (/distance|elevation|route|segments/.test(candidate)) {
                      // Post back to native
                      window.webkit.messageHandlers.jsonHandler.postMessage(candidate);
                      return 'posted';
                    }
                  }
                }
                return 'no_json_found';
              } catch (e) {
                return 'js_error:' + e.toString();
              }
            })();
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "jsonHandler" else { return }
            if let jsonText = message.body as? String {
                onJSONExtracted(jsonText)
            }
        }
    }
}

#Preview {
    RouteWebLoaderView(urlString: "https://www.strava.com/routes/123", onJSONExtracted: { _ in })
}
