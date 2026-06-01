//
//  ARCaptureView.swift
//  ParkQuestGSO
//
//  AR mini-game: a glowing park "spirit" floats in the camera view.
//  Tap it to capture → triggers the quest check-in.
//

import SwiftUI
import ARKit
import RealityKit
import simd

// MARK: - Main SwiftUI wrapper

struct ARCaptureView: View {
    let quest: Quest
    let onCapture: () -> Void
    let onCancel:  () -> Void

    @State private var arReady    = false   // show HUD after camera initialises
    @State private var tapped     = false   // brief white flash
    @State private var captured   = false   // success overlay

    var body: some View {
        ZStack {
            // ── AR scene ──────────────────────────────────────────
            ARSceneView(quest: quest) {
                withAnimation(.easeOut(duration: 0.15)) { tapped = true }
                Haptics.success()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.spring(response: 0.5)) { captured = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        onCapture()
                    }
                }
            }
            .ignoresSafeArea()

            // ── Capture flash ──────────────────────────────────────
            if tapped {
                Color.white.opacity(0.6)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }

            // ── HUD (before capture) ───────────────────────────────
            if !captured {
                VStack {
                    topBar

                    Spacer()

                    if arReady {
                        // Crosshair hint
                        Image(systemName: "scope")
                            .font(.system(size: 36, weight: .ultraLight))
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.bottom, 16)
                            .transition(.opacity)

                        // Instruction pill
                        Text("Point your camera — tap the glowing spirit to capture it!")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24).padding(.vertical, 12)
                            .background(.black.opacity(0.52), in: .capsule)
                            .padding(.bottom, 52)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }

            // ── Success overlay ────────────────────────────────────
            if captured {
                successOverlay
            }
        }
        .animation(.easeInOut(duration: 0.3), value: tapped)
        .animation(.spring(response: 0.45), value: captured)
        .animation(.easeIn(duration: 0.4), value: arReady)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                arReady = true
            }
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(alignment: .center) {
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.45), in: .circle)
            }

            Spacer()

            VStack(spacing: 2) {
                Text("AR CAPTURE")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.7))
                Text(quest.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(.black.opacity(0.45), in: .capsule)

            Spacer()

            // Points badge (mirrors X button width for centering)
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.amber)
                Text("+\(quest.points)")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: 44)
        }
        .padding(.horizontal, 16)
        .padding(.top, 56)
    }

    // MARK: Success overlay

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .fill(spiritColor.opacity(0.18))
                        .frame(width: 150, height: 150)
                    Circle()
                        .fill(spiritColor.opacity(0.10))
                        .frame(width: 110, height: 110)
                    Image(systemName: "checkmark")
                        .font(.system(size: 48, weight: .black))
                        .foregroundStyle(spiritColor)
                }

                VStack(spacing: 8) {
                    Text("Spirit Captured!")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("+\(quest.points) pts")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.amber)
                }
            }
        }
        .transition(.opacity)
    }

    private var spiritColor: Color {
        switch quest.kind {
        case .nature:     return Theme.primaryGreen
        case .landmark:   return Theme.darkGreen
        case .facility:   return Color(red: 0.55, green: 0.35, blue: 0.85)
        case .recreation: return Color(red: 0.20, green: 0.50, blue: 0.95)
        case .venue:      return Theme.amber
        case .daily:      return Theme.dailyRed
        }
    }
}

// MARK: - UIViewRepresentable AR scene

struct ARSceneView: UIViewRepresentable {
    let quest: Quest
    let onCapture: () -> Void

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero,
                            cameraMode: .ar,
                            automaticallyConfigureSession: true)
        arView.renderOptions = [.disablePersonOcclusion]

        let config = ARWorldTrackingConfiguration()
        config.planeDetection      = [.horizontal]
        config.environmentTexturing = .automatic
        arView.session.run(config, options: [])

        // Place the spirit after the camera has had a moment to initialise
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            context.coordinator.placeSpirit(in: arView, quest: quest)
        }

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        arView.addGestureRecognizer(tap)
        context.coordinator.arView    = arView
        context.coordinator.onCapture = onCapture

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(quest: quest) }

    // MARK: Coordinator

    final class Coordinator: NSObject {
        let quest: Quest
        weak var arView: ARView?
        var spiritEntity: ModelEntity?
        var bobTimer: Timer?
        var startTime: TimeInterval = 0
        var onCapture: (() -> Void)?

        init(quest: Quest) { self.quest = quest }

        // ── Build & place the spirit ──────────────────────────────

        func placeSpirit(in arView: ARView, quest: Quest) {
            let cam = arView.cameraTransform

            // Project 1.8 m forward, slightly below eye level
            let fwd = simd_normalize(
                SIMD3<Float>(-cam.matrix.columns.2.x, 0, -cam.matrix.columns.2.z)
            )
            let pos = SIMD3<Float>(
                cam.translation.x + fwd.x * 1.8,
                cam.translation.y - 0.25,
                cam.translation.z + fwd.z * 1.8
            )

            let spirit = makeSpirit()
            self.spiritEntity = spirit
            self.startTime    = Date().timeIntervalSince1970

            let anchor = AnchorEntity(world: pos)
            anchor.addChild(spirit)
            arView.scene.addAnchor(anchor)

            // Bob + rotate animation loop (≈30 fps)
            bobTimer = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { [weak self] _ in
                guard let self, let s = self.spiritEntity else { return }
                let t = Float(Date().timeIntervalSince1970 - self.startTime)
                s.position.y = sin(t * 1.5) * 0.055
                s.orientation = simd_quatf(angle: t * 0.7, axis: [0, 1, 0])
            }
        }

        // ── Entity factory ────────────────────────────────────────

        private func makeSpirit() -> ModelEntity {
            // Core glowing sphere
            let coreMesh = MeshResource.generateSphere(radius: 0.13)
            var coreMat  = SimpleMaterial()
            coreMat.color    = .init(tint: uiColor(for: quest).withAlphaComponent(0.95), texture: nil)
            coreMat.roughness = .float(0.1)
            coreMat.metallic  = .float(0.55)
            let core = ModelEntity(mesh: coreMesh, materials: [coreMat])
            core.name = "spirit_core"

            // Outer translucent aura
            let auraMesh = MeshResource.generateSphere(radius: 0.22)
            var auraMat  = SimpleMaterial()
            auraMat.color    = .init(tint: uiColor(for: quest).withAlphaComponent(0.12), texture: nil)
            auraMat.roughness = .float(1.0)
            let aura = ModelEntity(mesh: auraMesh, materials: [auraMat])
            aura.name = "spirit_aura"
            core.addChild(aura)

            // Collision shape for entity(at:) hit-testing
            core.components.set(
                CollisionComponent(shapes: [.generateSphere(radius: 0.22)])
            )

            return core
        }

        private func uiColor(for quest: Quest) -> UIColor {
            switch quest.kind {
            case .nature:     return UIColor(red: 0.18, green: 0.65, blue: 0.32, alpha: 1)
            case .landmark:   return UIColor(red: 0.10, green: 0.45, blue: 0.20, alpha: 1)
            case .facility:   return UIColor(red: 0.55, green: 0.35, blue: 0.85, alpha: 1)
            case .recreation: return UIColor(red: 0.20, green: 0.50, blue: 0.95, alpha: 1)
            case .venue:      return UIColor(red: 0.96, green: 0.65, blue: 0.14, alpha: 1)
            case .daily:      return UIColor(red: 0.90, green: 0.20, blue: 0.20, alpha: 1)
            }
        }

        // ── Tap handler ───────────────────────────────────────────

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let arView, let spirit = spiritEntity else { return }
            let pt = gesture.location(in: arView)
            if let hit = arView.entity(at: pt),
               hit == spirit || hit.parent == spirit || hit.name.hasPrefix("spirit") {
                bobTimer?.invalidate()
                // Scale up then disappear
                var bigTransform        = spirit.transform
                bigTransform.scale      = SIMD3(repeating: 2.8)
                spirit.move(to: bigTransform,
                            relativeTo: spirit.parent,
                            duration: 0.4,
                            timingFunction: .easeOut)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    self.onCapture?()
                }
            }
        }

        deinit { bobTimer?.invalidate() }
    }
}
