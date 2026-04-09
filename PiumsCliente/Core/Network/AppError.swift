// AppError.swift
import Foundation

enum AppError: LocalizedError, Equatable {
    case network(URLError)
    case http(statusCode: Int, message: String)
    case decoding(Error)
    case unauthorized          // 401 → cerrar sesión
    case notFound              // 404
    case serverError           // 5xx
    case unknown(Error)

    static func == (lhs: AppError, rhs: AppError) -> Bool {
        switch (lhs, rhs) {
        case (.unauthorized, .unauthorized): return true
        case (.notFound, .notFound): return true
        case (.serverError, .serverError): return true
        case (.http(let a, _), .http(let b, _)): return a == b
        default: return false
        }
    }

    var errorDescription: String? {
        switch self {
        case .network:              return "Sin conexión a internet"
        case .http(_, let m):       return m
        case .decoding:             return "Error al procesar la respuesta"
        case .unauthorized:         return "Sesión expirada. Inicia sesión de nuevo"
        case .notFound:             return "Recurso no encontrado"
        case .serverError:          return "Error del servidor. Intenta más tarde"
        case .unknown(let e):       return e.localizedDescription
        }
    }

    init(from error: Error) {
        if let e = error as? AppError { self = e; return }
        if let e = error as? URLError { self = .network(e); return }
        self = .unknown(error)
    }
}
