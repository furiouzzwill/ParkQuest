//
//  Confetti.swift
//  ParkQuestGSO
//

import SwiftUI

struct ConfettiPiece: Identifiable {
    let id = UUID()
    var x: CGFloat
    var startY: CGFloat
    var endY: CGFloat
    var rotation: Double
    var endRotation: Double
    var color: Color
    var size: CGFloat
    var delay: Double
    var duration: Double
    var shape: Int
}

struct ConfettiView: View {
    let trigger: Int
    @State private var pieces: [ConfettiPiece] = []
    @State private var animate = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { p in
                    confettiShape(p.shape)
                        .foregroundStyle(p.color)
                        .frame(width: p.size, height: p.size * 0.5)
                        .rotationEffect(.degrees(animate ? p.endRotation : p.rotation))
                        .position(
                            x: p.x * geo.size.width,
                            y: animate ? p.endY : p.startY
                        )
                        .opacity(animate ? 0 : 1)
                        .animation(
                            .easeOut(duration: p.duration).delay(p.delay),
                            value: animate
                        )
                }
            }
            .allowsHitTesting(false)
            .onAppear { fire(in: geo.size) }
            .onChange(of: trigger) { _, _ in
                animate = false
                pieces = []
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                    fire(in: geo.size)
                }
            }
        }
    }

    private func fire(in size: CGSize) {
        let palette: [Color] = [
            Theme.primaryGreen, Theme.amber, Theme.amberSoft,
            Theme.dailyRed, Theme.waterBlue, Theme.darkGreen
        ]
        var new: [ConfettiPiece] = []
        for _ in 0..<70 {
            new.append(ConfettiPiece(
                x: CGFloat.random(in: 0.05...0.95),
                startY: -30,
                endY: size.height + 60,
                rotation: Double.random(in: 0...360),
                endRotation: Double.random(in: 360...1440),
                color: palette.randomElement() ?? .green,
                size: CGFloat.random(in: 8...14),
                delay: Double.random(in: 0...0.35),
                duration: Double.random(in: 1.6...2.6),
                shape: Int.random(in: 0...2)
            ))
        }
        pieces = new
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            animate = true
        }
    }

    @ViewBuilder
    private func confettiShape(_ kind: Int) -> some View {
        switch kind {
        case 0: Rectangle()
        case 1: Capsule()
        default: Ellipse()
        }
    }
}
