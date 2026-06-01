//
//  BadgeArt.swift
//  ParkQuestGSO
//
//  Ranger-patch style badge, drawn entirely in SwiftUI.
//

import SwiftUI

struct BadgeArt: View {
    let name: String
    let symbol: String
    let earned: Bool

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                // Outer ring
                Circle()
                    .fill(earned
                          ? LinearGradient(colors: [Theme.darkGreen, Theme.primaryGreen],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                          : LinearGradient(colors: [Theme.lockGray, Color(white: 0.78)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing))
                // Outer ring stroke
                Circle()
                    .strokeBorder(earned ? Theme.amber : Color(white: 0.6), lineWidth: s * 0.04)
                    .padding(s * 0.02)
                // Inner cream face
                Circle()
                    .fill(earned ? Theme.cream : Color(white: 0.92))
                    .padding(s * 0.16)
                // Stitching dots around ring
                ForEach(0..<24, id: \.self) { i in
                    Circle()
                        .fill(earned ? Theme.amber.opacity(0.7) : Color(white: 0.55).opacity(0.5))
                        .frame(width: s * 0.018, height: s * 0.018)
                        .offset(y: -(s / 2) * 0.78)
                        .rotationEffect(.degrees(Double(i) / 24 * 360))
                }
                // Symbol
                Image(systemName: symbol)
                    .font(.system(size: s * 0.32, weight: .black))
                    .foregroundStyle(earned ? Theme.primaryGreen : Color(white: 0.55))
                    .offset(y: -s * 0.02)
                // Name arc (simple flat text along bottom)
                Text(earned ? name.uppercased() : "LOCKED")
                    .font(.system(size: s * 0.07, weight: .heavy, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(earned ? Theme.darkGreen : Color(white: 0.55))
                    .frame(maxWidth: s * 0.72)
                    .multilineTextAlignment(.center)
                    .offset(y: s * 0.28)

                // Lock overlay if not earned
                if !earned {
                    Image(systemName: "lock.fill")
                        .font(.system(size: s * 0.22, weight: .black))
                        .foregroundStyle(.white)
                        .padding(s * 0.06)
                        .background(Theme.mutedText.opacity(0.85), in: .circle)
                        .offset(x: s * 0.22, y: s * 0.22)
                }

                // Star at top (earned)
                if earned {
                    Image(systemName: "star.fill")
                        .font(.system(size: s * 0.1, weight: .black))
                        .foregroundStyle(Theme.amber)
                        .offset(y: -s * 0.42)
                        .shadow(color: Theme.darkGreen.opacity(0.4), radius: 2)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

#Preview {
    HStack {
        BadgeArt(name: "Barber Park Explorer", symbol: "tree.fill", earned: true)
            .frame(width: 160, height: 160)
        BadgeArt(name: "Country Park", symbol: "leaf.fill", earned: false)
            .frame(width: 160, height: 160)
    }
    .padding()
}
