// NetworkSecurity.swift — Certificate pinning para URLSession
import Foundation
import CryptoKit

/// Verifica que la cadena de certificados del servidor contenga al menos uno
/// cuyo hash SHA-256 (DER) coincida con los valores fijados.
///
/// Cómo rotar hashes cuando el certificado vence:
///   $ echo | openssl s_client -connect backend.piums.io:443 2>/dev/null \
///       | openssl x509 -outform der | openssl dgst -sha256 -binary | base64
///
/// Hashes actuales:
///   Leaf cert:    vence 2026-07-21  →  bXcinqCEgWfTR8vYpEctiYO9Tq7YLAfUtvWLZJKvNhI=
///   Intermediate: Let's Encrypt E8  →  g2JP0zjI2bAjwYpny3qcBRnaQ9EXdbTGy9rUXD2ZfFI=
final class CertificatePinningDelegate: NSObject, URLSessionDelegate {

    private static let pinnedHashes: Set<String> = [
        "bXcinqCEgWfTR8vYpEctiYO9Tq7YLAfUtvWLZJKvNhI=",  // leaf — vence 2026-07-21
        "g2JP0zjI2bAjwYpny3qcBRnaQ9EXdbTGy9rUXD2ZfFI="   // Let's Encrypt E8 intermediate
    ]

    // Solo aplicar pinning a nuestros propios hosts; CDN / Firebase / Stripe pasan normal
    private static let pinnedHosts: Set<String> = ["backend.piums.io"]

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let host = challenge.protectionSpace.host
        guard Self.pinnedHosts.contains(host) else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        #if DEBUG
        // En debug se permite cualquier certificado para que Charles Proxy / simulador funcionen.
        // Para probar pinning en debug, comenta esta línea.
        completionHandler(.performDefaultHandling, nil)
        return
        #else
        var error: CFError?
        guard SecTrustEvaluateWithError(serverTrust, &error) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        guard let chain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate] else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let matched = chain.contains { cert in
            let data = SecCertificateCopyData(cert) as Data
            let hash = SHA256.hash(data: data)
            return Self.pinnedHashes.contains(Data(hash).base64EncodedString())
        }

        completionHandler(
            matched ? .useCredential : .cancelAuthenticationChallenge,
            matched ? URLCredential(trust: serverTrust) : nil
        )
        #endif
    }
}
