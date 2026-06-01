//
//  Theme.swift
//  ParkQuestGSO
//

import SwiftUI

enum Theme {
    static let primaryGreen = Color(red: 0x2D / 255, green: 0x6A / 255, blue: 0x4F / 255)
    static let darkGreen = Color(red: 0x1B / 255, green: 0x43 / 255, blue: 0x32 / 255)
    static let mossGreen = Color(red: 0x52 / 255, green: 0x82 / 255, blue: 0x68 / 255)
    static let foundTint = Color(red: 0xD1 / 255, green: 0xFA / 255, blue: 0xE5 / 255)
    static let amber = Color(red: 0xD9 / 255, green: 0x76 / 255, blue: 0x06 / 255)
    static let amberSoft = Color(red: 0xFD / 255, green: 0xE6 / 255, blue: 0x8A / 255)
    static let cream = Color(red: 0xFA / 255, green: 0xF6 / 255, blue: 0xEC / 255)
    static let bg = Color(red: 0xF9 / 255, green: 0xFA / 255, blue: 0xFB / 255)
    static let darkText = Color(red: 0x11 / 255, green: 0x18 / 255, blue: 0x27 / 255)
    static let mutedText = Color(red: 0x6B / 255, green: 0x72 / 255, blue: 0x80 / 255)
    static let lockGray = Color(red: 0xE5 / 255, green: 0xE7 / 255, blue: 0xEB / 255)
    static let dailyRed = Color(red: 0xDC / 255, green: 0x26 / 255, blue: 0x26 / 255)

    // Map illustration palette
    static let grassDeep = Color(red: 0xAE / 255, green: 0xC8 / 255, blue: 0x9F / 255)
    static let grassLight = Color(red: 0xC8 / 255, green: 0xDC / 255, blue: 0xA8 / 255)
    static let pathSand = Color(red: 0xE7 / 255, green: 0xD5 / 255, blue: 0xA8 / 255)
    static let waterBlue = Color(red: 0x7F / 255, green: 0xB6 / 255, blue: 0xD5 / 255)
    static let treeShadow = Color(red: 0x52 / 255, green: 0x82 / 255, blue: 0x68 / 255)
}

extension Font {
    static let pqDisplay = Font.system(size: 32, weight: .heavy, design: .rounded)
    static let pqTitle = Font.system(size: 22, weight: .bold, design: .rounded)
    static let pqHeadline = Font.system(size: 18, weight: .semibold, design: .rounded)
    static let pqBody = Font.system(size: 15, weight: .regular, design: .default)
    static let pqLabel = Font.system(size: 12, weight: .semibold, design: .rounded)
    static let pqStat = Font.system(size: 28, weight: .heavy, design: .rounded)
}
