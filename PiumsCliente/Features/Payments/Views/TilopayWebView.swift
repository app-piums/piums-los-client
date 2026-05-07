// TilopayWebView.swift — WKWebView que intercepta el redirect de retorno de Tilopay
import SwiftUI
import WebKit

// MARK: - Callback params

struct TilopayCallbackParams {
    let bookingId: String
    let responseCode: String
    let orderNumber: String
    let amount: String
    let auth: String?
    let currency: String?
    let orderHash: String?

    var isApproved: Bool { responseCode == "00" }
}

// MARK: - WKWebView wrapper

struct TilopayWebView: UIViewRepresentable {
    let url: URL
    let onCallback: (TilopayCallbackParams) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCallback: onCallback)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    // MARK: - Coordinator / nav delegate

    class Coordinator: NSObject, WKNavigationDelegate {
        let onCallback: (TilopayCallbackParams) -> Void

        init(onCallback: @escaping (TilopayCallbackParams) -> Void) {
            self.onCallback = onCallback
        }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = action.request.url,
                  let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
            else { decisionHandler(.allow); return }

            // Detecta la URL de retorno configurada en el backend:
            // host contiene "piums" y el path contiene /booking/confirmation/:bookingId
            let isReturnUrl = (comps.host?.contains("piums") ?? false)
                           && comps.path.contains("/booking/confirmation/")

            guard isReturnUrl else { decisionHandler(.allow); return }

            let params = comps.queryItems?.reduce(into: [String: String]()) { acc, item in
                if let v = item.value { acc[item.name] = v }
            } ?? [:]

            // bookingId: último segmento no vacío del path
            let bookingId = comps.path
                .components(separatedBy: "/")
                .last(where: { !$0.isEmpty }) ?? ""

            let result = TilopayCallbackParams(
                bookingId: bookingId,
                responseCode: params["responseCode"] ?? params["code"] ?? "",
                orderNumber:  params["orderNumber"]  ?? params["tpt"]  ?? "",
                amount:       params["amount"]        ?? "",
                auth:         params["auth"],
                currency:     params["currency"],
                orderHash:    params["orderHash"]
            )

            decisionHandler(.cancel)
            DispatchQueue.main.async { self.onCallback(result) }
        }
    }
}

// MARK: - Sheet wrapper con barra de navegación

struct TilopayWebSheet: View {
    let url: URL
    let onCallback: (TilopayCallbackParams) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TilopayWebView(url: url) { params in
                dismiss()
                onCallback(params)
            }
            .ignoresSafeArea()
            .navigationTitle("Pago Seguro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
