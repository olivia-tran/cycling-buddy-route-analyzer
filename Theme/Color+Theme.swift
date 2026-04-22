import SwiftUI

// MARK: – App color palette
extension Color {
    static let cbBackground = Color(hex: "#0a0a0f")
    static let cbSurface    = Color(hex: "#13131a")
    static let cbCard       = Color(hex: "#1a1a24")
    static let cbBorder     = Color(hex: "#2a2a3a")
    static let cbAccent     = Color(hex: "#ff4d1c")   // orange-red
    static let cbText       = Color(hex: "#f0f0f5")
    static let cbMuted      = Color(hex: "#6b6b80")

    init(hex: String) {
        let h = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        let rgb = UInt32(h, radix: 16) ?? 0
        self.init(
            red:   Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8)  & 0xFF) / 255,
            blue:  Double( rgb        & 0xFF) / 255
        )
    }
}
