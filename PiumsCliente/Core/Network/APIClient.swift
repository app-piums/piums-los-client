// APIClient.swift
import Foundation

struct APIClient {
    @discardableResult
    static func request<T: Decodable>(
        _ endpoint: APIEndpoint,
        retryOnUnauthorized: Bool = true
    ) async throws -> T {
        let data = try await rawRequest(endpoint, retryOnUnauthorized: retryOnUnauthorized)
        do {
            return try JSONDecoder.piums.decode(T.self, from: data)
        } catch {
            throw AppError.decoding(error)
        }
    }

    private static func rawRequest(
        _ endpoint: APIEndpoint,
        retryOnUnauthorized: Bool = true
    ) async throws -> Data {
        var urlRequest = URLRequest(url: endpoint.url)
        urlRequest.httpMethod = endpoint.method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = endpoint.body

        if let token = TokenStorage.shared.accessToken {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let http = response as? HTTPURLResponse else {
            throw AppError.unknown(URLError(.badServerResponse))
        }

        switch http.statusCode {
        case 200..<300:
            return data
        case 401 where retryOnUnauthorized:
            try await AuthManager.shared.refreshIfNeeded()
            return try await rawRequest(endpoint, retryOnUnauthorized: false)
        case 401:
            await AuthManager.shared.logout()
            throw AppError.unauthorized
        case 404:
            throw AppError.notFound
        case 500..<600:
            throw AppError.serverError
        default:
            let msg = (try? JSONDecoder().decode(APIErrorBody.self, from: data))?.message
                      ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw AppError.http(statusCode: http.statusCode, message: msg)
        }
    }
}

private struct APIErrorBody: Decodable { let message: String }
