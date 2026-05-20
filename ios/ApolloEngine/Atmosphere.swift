//
//  Atmosphere.swift
//  ApolloEngine
//
//  Animated gradient backdrop with a soft drifting accent orb.
//  This is the signature "Apollo" atmosphere — carried over from the web app.
//

import SwiftUI

struct AtmosphereBackdrop: View {
    let section: Apollo.Section
    @Environment(\.colorScheme) private var scheme
    @State private var orbPhase: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                base
                    .ignoresSafeArea()

                // Accent orb — drifts in a slow Lissajous figure
                let w = geo.size.width
                let h = geo.size.height
                let driftX = sin(orbPhase * 0.6) * (w * 0.18)
                let driftY = cos(orbPhase * 0.4) * (h * 0.10)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                section.orbTopColor.opacity(scheme == .dark ? 0.45 : 0.32),
                                section.orbTopColor.opacity(0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: max(w, h) * 0.55
                        )
                    )
                    .frame(width: max(w, h) * 1.1, height: max(w, h) * 1.1)
                    .offset(x: -w * 0.15 + driftX, y: -h * 0.25 + driftY)
                    .blur(radius: 60)
                    .blendMode(scheme == .dark ? .screen : .plusLighter)

                // Secondary distant orb — adds depth
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                secondaryColor.opacity(scheme == .dark ? 0.28 : 0.18),
                                secondaryColor.opacity(0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: max(w, h) * 0.45
                        )
                    )
                    .frame(width: max(w, h) * 0.9, height: max(w, h) * 0.9)
                    .offset(x: w * 0.25 + driftY, y: h * 0.30 - driftX)
                    .blur(radius: 80)
                    .blendMode(scheme == .dark ? .screen : .plusLighter)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.linear(duration: 24).repeatForever(autoreverses: true)) {
                orbPhase = .pi * 2
            }
        }
        .accessibilityHidden(true)
    }

    private var base: some View {
        LinearGradient(
            colors: scheme == .dark
                ? [
                    Color(red: 0.028, green: 0.028, blue: 0.055),
                    Color(red: 0.045, green: 0.043, blue: 0.075),
                    Color(red: 0.020, green: 0.020, blue: 0.043)
                  ]
                : [
                    Color(red: 0.980, green: 0.984, blue: 0.996),
                    Color(red: 0.945, green: 0.953, blue: 0.984),
                    Color(red: 0.965, green: 0.961, blue: 0.984)
                  ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var secondaryColor: Color {
        switch section {
        case .esoteric: return Apollo.amber       // counterpoint to violet
        case .unified: return Apollo.violet       // counterpoint to cyan
        case .reports: return Apollo.cyan         // counterpoint to emerald
        default: return Apollo.violet             // counterpoint to amber
        }
    }
}
