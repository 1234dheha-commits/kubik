import SwiftUI

enum Theme {
    static let bg     = Color(red: 0.06, green: 0.07, blue: 0.12)
    static let panel  = Color(red: 0.13, green: 0.14, blue: 0.22)
    static let empty  = Color(red: 0.16, green: 0.17, blue: 0.27)
    static let text   = Color.white
    static let muted  = Color.white.opacity(0.55)
    static let accent = Color(red: 1.0, green: 0.54, blue: 0.12)

    /// Vibrant block colours.
    static let palette: [Color] = [
        Color(red: 0.21, green: 0.81, blue: 0.88),  // cyan
        Color(red: 1.00, green: 0.54, blue: 0.12),  // orange
        Color(red: 1.00, green: 0.31, blue: 0.48),  // pink
        Color(red: 0.34, green: 0.84, blue: 0.56),  // green
        Color(red: 0.58, green: 0.46, blue: 1.00),  // purple
        Color(red: 1.00, green: 0.79, blue: 0.25)   // yellow
    ]
}
