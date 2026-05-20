//
//  GlassComponents.swift
//  ApolloEngine
//
//  Reusable Liquid Glass containers with iOS 18 fallback to `.ultraThinMaterial`.
//

import SwiftUI

// MARK: - Glass card

struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 20
    var padding: CGFloat = 20
    var tint: Color? = nil
    @ViewBuilder var content: () -> Content

    @Environment(\.apollo) private var palette

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if #available(iOS 26.0, *) {
                    Color.clear
                        .glassEffect(in: .rect(cornerRadius: cornerRadius))
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [.white.opacity(0.10), .clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(palette.cardStroke, lineWidth: 1)
            )
            .overlay(alignment: .top) {
                if let tint {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .trim(from: 0, to: 0.5)
                        .stroke(tint.opacity(0.45), lineWidth: 2)
                        .frame(height: cornerRadius * 2)
                        .clipped()
                        .allowsHitTesting(false)
                }
            }
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let icon: String
    let title: String
    let accent: Color
    @Environment(\.apollo) private var palette

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(accent)
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(palette.label)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Status pill

struct StatusPill: View {
    let label: String
    let color: Color
    let icon: String?

    init(_ label: String, color: Color, icon: String? = nil) {
        self.label = label
        self.color = color
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon).font(.system(size: 9, weight: .semibold))
            }
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .foregroundStyle(color)
        .background(
            Capsule().fill(color.opacity(0.14))
        )
        .overlay(
            Capsule().strokeBorder(color.opacity(0.30), lineWidth: 1)
        )
    }
}

// MARK: - Glass button styles

struct ApolloPrimaryButtonStyle: ButtonStyle {
    var tint: Color = Apollo.amber
    @Environment(\.apollo) private var palette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .padding(.horizontal, 22)
            .padding(.vertical, 11)
            .foregroundStyle(.white)
            .background {
                if #available(iOS 26.0, *) {
                    Capsule().fill(
                        LinearGradient(colors: [tint, tint.opacity(0.85)],
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing)
                    )
                } else {
                    Capsule().fill(
                        LinearGradient(colors: [tint, tint.opacity(0.85)],
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing)
                    )
                }
            }
            .shadow(color: tint.opacity(0.35), radius: 12, y: 6)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct ApolloSecondaryButtonStyle: ButtonStyle {
    @Environment(\.apollo) private var palette
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .foregroundStyle(palette.title)
            .background {
                Capsule().fill(.ultraThinMaterial)
            }
            .overlay(Capsule().strokeBorder(palette.cardStroke, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Adaptive container width (clamps content on iPad)

struct ApolloReadingWidth<Content: View>: View {
    var maxWidth: CGFloat = 920
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            content()
                .frame(maxWidth: maxWidth)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Empty state

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var accent: Color = Apollo.amber
    @Environment(\.apollo) private var palette

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(accent.opacity(0.6))
            Text(title)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(palette.subtitle)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(palette.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}
