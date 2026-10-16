import SwiftUI

/// ShutterDrop's one dark look. The app has no light mode.
/// Palette: coolors.co/palette/cfdbd5-e8eddf-f5cb5c-242423-333533
enum Palette {
    /// Charcoal: screen backgrounds.
    static let background = Color(hex: 0x242423)
    /// Graphite: cards, lists, the tab bar.
    static let surface = Color(hex: 0x333533)
    /// Thumbnails, chips and separators on graphite.
    static let raised = Color(hex: 0x444644)
    /// Off-white: main text.
    static let text = Color(hex: 0xE8EDDF)
    /// Sage, softened so small labels stay readable on graphite.
    static let secondaryText = Color(hex: 0xA0A9A4)
    /// Sage at full strength, for quiet text on larger sizes.
    static let sage = Color(hex: 0xCFDBD5)
    /// Saffron: buttons, links, toggles, the selected tab.
    static let accent = Color(hex: 0xF5CB5C)
    /// Text on filled saffron buttons.
    static let onAccent = Color(hex: 0x242423)
    /// Terracotta: Remove and Reset to Default.
    static let destructive = Color(hex: 0xE5856B)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

