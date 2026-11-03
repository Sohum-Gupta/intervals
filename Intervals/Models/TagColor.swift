import SwiftUI

/// The swatches offered when creating or recolouring a tag, and hex helpers.
enum TagColor {
    static let palette: [(name: String, hex: String)] = [
        ("Red", "#F26B6B"), ("Orange", "#F29A4B"), ("Yellow", "#E8C547"),
        ("Green", "#5DBB63"), ("Mint", "#4FC9A8"), ("Teal", "#3FB4C6"),
        ("Blue", "#4A8FE7"), ("Indigo", "#6A6FE0"), ("Purple", "#A06BE0"),
        ("Pink", "#E86BA8"), ("Brown", "#A88561"), ("Gray", "#8E8E93"),
    ]

    static var defaultHex: String { palette[6].hex }

    /// The palette colour least used by the given tags, so new tags vary.
    static func nextHex(existing: [String]) -> String {
        let counts = Dictionary(existing.map { ($0.uppercased(), 1) }, uniquingKeysWith: +)
        return palette.min { counts[$0.hex, default: 0] < counts[$1.hex, default: 0] }?.hex ?? defaultHex
    }

    static func name(for hex: String) -> String {
        palette.first { $0.hex.caseInsensitiveCompare(hex) == .orderedSame }?.name ?? "Custom"
    }
}

extension Color {
    /// Parses `#RRGGBB`. Falls back to the default tag colour on bad input.
    init(hex: String) {
        var value: UInt64 = 0
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard cleaned.count == 6, Scanner(string: cleaned).scanHexInt64(&value) else {
            self.init(hex: TagColor.defaultHex)
            return
        }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

import AppKit

extension TagColor {
    /// A filled circle as a non-template image, so menus keep its colour.
    @MainActor
    static func dot(hex: String, diameter: CGFloat = 10, ring: Bool = false) -> NSImage {
        let size = NSSize(width: diameter + 2, height: diameter + 2)
        let image = NSImage(size: size, flipped: false) { rect in
            let inset = rect.insetBy(dx: 1, dy: 1)
            NSColor(Color(hex: hex)).setFill()
            NSBezierPath(ovalIn: inset).fill()
            if ring {
                NSColor.labelColor.withAlphaComponent(0.9).setStroke()
                let path = NSBezierPath(ovalIn: inset.insetBy(dx: -0.5, dy: -0.5))
                path.lineWidth = 1.5
                path.stroke()
            }
            return true
        }
        image.isTemplate = false
        return image
    }
}
