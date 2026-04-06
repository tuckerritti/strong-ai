import Foundation

extension Double {
    /// Formats a weight for display: 185.0 → "185", 187.5 → "187.5"
    var formattedWeight: String {
        truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(self))" : String(format: "%.1f", self)
    }
}
