// APIClient.swift
import Foundation

struct APIClient {

    // URLSession con certificate pinning para backend.piums.io
    private static let pinningDelegate = CertificatePinningDelegate()
    static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 30
        // Tope total por recurso: debe cubrir uploads multipart en redes lentas
        config.timeoutIntervalForResource = 300
        return URLSession(configuration: config, delegate: pinningDelegate, delegateQueue: nil)
    }()

    @discardableResult
    static func request<T: Decodable>(
        _ endpoint: APIEndpoint,
        retryOnUnauthorized: Bool = true
    ) async throws -> T {
        let data = try await rawRequest(endpoint, retryOnUnauthorized: retryOnUnauthorized)
        do {
            return try JSONDecoder.piums.decode(T.self, from: data)
        } catch {
            #if DEBUG
            let raw = String(data: data, encoding: .utf8) ?? "(binary)"
            print("🔴 Decode error [\(endpoint.url.path)]: \(error)\nRaw: \(raw.prefix(800))")
            #endif
            throw AppError.decoding(error)
        }
    }

    private static func rawRequest(
        _ endpoint: APIEndpoint,
        retryOnUnauthorized: Bool = true
    ) async throws -> Data {
        // Refresh proactivo: si el token ya expiró no esperamos a recibir 401
        if endpoint.requiresAuth && retryOnUnauthorized && TokenStorage.shared.isAccessTokenExpired {
            try? await AuthManager.shared.refreshIfNeeded()
        }

        var urlRequest = URLRequest(url: endpoint.url)
        urlRequest.httpMethod = endpoint.method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-ID")
        urlRequest.httpBody = endpoint.body

        if let token = TokenStorage.shared.accessToken {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: urlRequest)

        guard let http = response as? HTTPURLResponse else {
            throw AppError.unknown(URLError(.badServerResponse))
        }

        let errorBody = try? JSONDecoder().decode(APIErrorBody.self, from: data)
        let backendMessage = errorBody?.fullMessage

        #if DEBUG
        if http.statusCode >= 400 {
            // Solo en debug: response/request body pueden contener PII y credenciales
            let raw = String(data: data, encoding: .utf8) ?? "(binary)"
            print("❌ APIClient [\(http.statusCode)] \(endpoint.url.path):\n\(raw)")
            if let body = urlRequest.httpBody,
               let bodyStr = String(data: body, encoding: .utf8) {
                print("   ↑ Request body: \(bodyStr)")
            }
        }
        #endif

        switch http.statusCode {
        case 200..<300:
            return data
        case 429:
            let retryAfter = (http.allHeaderFields["Retry-After"] as? String).flatMap(Int.init)
            let msg = retryAfter.map { LoginRateLimiter.countdownMessage(seconds: $0) }
                ?? backendMessage
                ?? "Demasiados intentos. Espera un momento e inténtalo de nuevo."
            throw AppError.http(statusCode: 429, message: msg)
        case 401 where retryOnUnauthorized && endpoint.requiresAuth:
            try await AuthManager.shared.refreshIfNeeded()
            return try await rawRequest(endpoint, retryOnUnauthorized: false)
        case 401 where endpoint.requiresAuth:
            await AuthManager.shared.logout()
            throw AppError.unauthorized
        case 401:
            let msg = backendMessage ?? "Credenciales incorrectas"
            throw AppError.http(statusCode: 401, message: msg)
        case 404:
            throw AppError.notFound
        case 500..<600:
            throw AppError.serverError
        default:
            let msg = backendMessage ?? "Error inesperado. Intenta de nuevo."
            throw AppError.http(statusCode: http.statusCode, message: msg)
        }
    }
}

private struct APIErrorBody: Decodable {
    let message: String
    let errors: [APIFieldError]?

    struct APIFieldError: Decodable {
        let field: String?
        let message: String
    }

    // Construye un mensaje legible incluyendo los campos que fallaron
    var fullMessage: String {
        guard let errs = errors, !errs.isEmpty else { return message }
        let detail = errs.map { e in
            e.field.map { "\($0): \(e.message)" } ?? e.message
        }.joined(separator: " · ")
        return "\(message) — \(detail)"
    }
}

extension APIClient {
    /// Sube un archivo de imagen como multipart/form-data.
    /// Usado para documentos de identidad y avatar.
    @discardableResult
    static func uploadMultipart<T: Decodable>(
        _ endpoint: APIEndpoint,
        imageData: Data,
        filename: String = "photo.jpg",
        mimeType: String = "image/jpeg",
        retryOnUnauthorized: Bool = true
    ) async throws -> T {
        if endpoint.requiresAuth && retryOnUnauthorized && TokenStorage.shared.isAccessTokenExpired {
            try? await AuthManager.shared.refreshIfNeeded()
        }

        let boundary = "PiumsBoundary-\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        var urlRequest = URLRequest(url: endpoint.url)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 120 // uploads necesitan más que los 30s globales
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-ID")
        urlRequest.httpBody = body

        if let token = TokenStorage.shared.accessToken {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw AppError.unknown(URLError(.badServerResponse))
        }

        switch http.statusCode {
        case 200..<300:
            do {
                return try JSONDecoder.piums.decode(T.self, from: data)
            } catch {
                throw AppError.decoding(error)
            }
        case 401 where retryOnUnauthorized && endpoint.requiresAuth:
            // Igual que rawRequest: refrescar token y reintentar una vez antes
            // de desloguear (un upload largo puede expirar el access token)
            try await AuthManager.shared.refreshIfNeeded()
            return try await uploadMultipart(
                endpoint,
                imageData: imageData,
                filename: filename,
                mimeType: mimeType,
                retryOnUnauthorized: false
            )
        case 401 where endpoint.requiresAuth:
            await AuthManager.shared.logout()
            throw AppError.unauthorized
        case 401:
            throw AppError.unauthorized
        default:
            let msg = (try? JSONDecoder().decode(APIErrorBody.self, from: data))?.message
                ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw AppError.http(statusCode: http.statusCode, message: msg)
        }
    }
}
