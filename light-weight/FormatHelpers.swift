import Foundation

extension Double {
    /// Formats a weight for display: 185.0 → "185", 187.5 → "187.5"
    var formattedWeight: String {
        truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(self))" : String(format: "%.1f", self)
    }
}

/// Parses a weight string that may use either `.` or `,` as the decimal separator.
func parseWeight(_ text: String) -> Double? {
    Double(text.replacingOccurrences(of: ",", with: "."))
}
