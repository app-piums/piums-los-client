import UIKit

extension UIImage {
    /// Reescala la imagen manteniendo proporción (sin agrandar) y la codifica a JPEG.
    func resizedJPEG(maxDimension: CGFloat, quality: CGFloat) -> Data? {
        let ratio = min(maxDimension / size.width, maxDimension / size.height, 1)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
        return resized.jpegData(compressionQuality: quality)
    }

    /// Normaliza data de imagen arbitraria (HEIC, PNG, JPEG grande) a un JPEG
    /// que el backend acepta: magic bytes JPEG y tamaño bajo el límite de 5MB
    /// de users-service. El PhotosPicker entrega el asset original (HEIC en
    /// iPhones modernos), que el backend rechaza si se sube sin convertir.
    static func normalizedJPEG(from data: Data, maxDimension: CGFloat = 2000, quality: CGFloat = 0.8) -> Data? {
        UIImage(data: data)?.resizedJPEG(maxDimension: maxDimension, quality: quality)
    }
}
