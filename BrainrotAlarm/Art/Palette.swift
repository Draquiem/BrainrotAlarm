import SwiftUI

/// A character's colour scheme. Stored as hex so the catalogue stays readable and
/// the whole model layer keeps compiling without SwiftUI.
struct Palette: Equatable {
    let body: UInt32
    let bodyShade: UInt32
    let accent: UInt32
    let backdropTop: UInt32
    let backdropBottom: UInt32

    static let ink = Color(hex: 0x1B1524)

    var bodyColor: Color { Color(hex: body) }
    var shadeColor: Color { Color(hex: bodyShade) }
    var accentColor: Color { Color(hex: accent) }
    var backdrop: LinearGradient {
        LinearGradient(colors: [Color(hex: backdropTop), Color(hex: backdropBottom)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Chooses black or white for text laid over the backdrop, by relative luminance.
    var backdropIsDark: Bool {
        func luminance(_ hex: UInt32) -> Double {
            let channels = [Double((hex >> 16) & 0xFF), Double((hex >> 8) & 0xFF), Double(hex & 0xFF)]
                .map { value -> Double in
                    let c = value / 255
                    return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
                }
            return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
        }
        return (luminance(backdropTop) + luminance(backdropBottom)) / 2 < 0.45
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}
