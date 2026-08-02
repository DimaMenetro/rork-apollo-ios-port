//
//  Theme.swift
//  ApolloEngine
//
//  Apollo color palette — preserved from the web implementation (amber/violet/cyan/emerald/rose).
//  Adaptive for light & dark, designed to sit under Liquid Glass.
//

import SwiftUI

enum Apollo {
    // ── Accent palette (matches web app exactly) ─────────────────────────────
    static let amber   = Color(red: 0.961, green: 0.620, blue: 0.043)   // #f59e0b
    static let amberDeep = Color(red: 0.851, green: 0.467, blue: 0.024) // #d97706
    static let violet  = Color(red: 0.545, green: 0.361, blue: 0.965)   // #8b5cf6
    static let cyan    = Color(red: 0.024, green: 0.714, blue: 0.831)   // #06b6d4
    static let emerald = Color(red: 0.063, green: 0.725, blue: 0.506)   // #10b981
    static let rose    = Color(red: 0.957, green: 0.247, blue: 0.369)   // #f43f5e
    static let slate   = Color(red: 0.580, green: 0.639, blue: 0.722)   // #94a3b8

    // ── Confidence semantic mapping ──────────────────────────────────────────
    static func confidenceColor(_ score: Int) -> Color {
        if score >= 80 { return emerald }
        if score >= 60 { return amber }
        return rose
    }

    // ── Section accent (drives backdrop orb + chip tints) ────────────────────
    enum Section: String, CaseIterable, Hashable {
        case dashboard, intake, processing, review, dsp, esoteric, unified, reports, settings

        var accent: Color {
            switch self {
            case .dashboard, .processing, .review, .dsp, .intake: return Apollo.amber
            case .esoteric: return Apollo.violet
            case .unified: return Apollo.cyan
            case .reports: return Apollo.emerald
            case .settings: return Apollo.slate
            }
        }

        var orbTopColor: Color {
            switch self {
            case .esoteric: return Apollo.violet
            case .unified: return Apollo.cyan
            case .reports: return Apollo.emerald
            default: return Apollo.amber
            }
        }
    }
}

// ── Type-safe palette for chrome ─────────────────────────────────────────────
struct ApolloPalette {
    let bg: Color
    let title: Color
    let subtitle: Color
    let text: Color
    let muted: Color
    let label: Color
    let cardStroke: Color
    let divider: Color
    let chipBg: Color

    static let dark = ApolloPalette(
        bg:         Color(red: 0.035, green: 0.035, blue: 0.059),
        title:      Color(red: 0.945, green: 0.961, blue: 0.976),
        subtitle:   Color(red: 0.796, green: 0.835, blue: 0.882),
        text:       Color(red: 0.796, green: 0.835, blue: 0.882),
        muted:      Color(red: 0.580, green: 0.639, blue: 0.722),
        label:      Color(red: 0.580, green: 0.639, blue: 0.722),
        cardStroke: Color.white.opacity(0.08),
        divider:    Color.white.opacity(0.06),
        chipBg:     Color.white.opacity(0.06)
    )

    /// Content card background — a subtle vertical gradient that picks up
    /// atmosphere orb colour without using glassEffect (reserved for chrome).
    /// Dark mode: faint top-lift gradient. Light mode: warm-white card.
    var contentBg: AnyShapeStyle {
        switch self {
        case .dark:
            return AnyShapeStyle(
                LinearGradient(colors: [Color.white.opacity(0.07), Color.white.opacity(0.03)],
                               startPoint: .top, endPoint: .bottom)
            )
        default:
            return AnyShapeStyle(
                LinearGradient(colors: [Color.white.opacity(0.55), Color.white.opacity(0.35)],
                               startPoint: .top, endPoint: .bottom)
            )
        }
    }

    /// Refined card border — slightly brighter on the top edge for specular lift.
    var cardBorderTop: Color {
        switch self {
        case .dark:  return Color.white.opacity(0.12)
        default:     return Color.white.opacity(0.80)
        }
    }

    static let light = ApolloPalette(
        bg:         Color(red: 0.972, green: 0.972, blue: 0.988),
        title:      Color(red: 0.110, green: 0.110, blue: 0.118),
        subtitle:   Color(red: 0.235, green: 0.235, blue: 0.263),
        text:       Color(red: 0.282, green: 0.298, blue: 0.337),
        muted:      Color(red: 0.557, green: 0.557, blue: 0.576),
        label:      Color(red: 0.557, green: 0.557, blue: 0.576),
        cardStroke: Color.black.opacity(0.06),
        divider:    Color.black.opacity(0.06),
        chipBg:     Color.black.opacity(0.04)
    )

    // contentBg and cardBorderTop are computed in the dark case above;
    // the switch handles both palettes.

    static func current(for scheme: ColorScheme) -> ApolloPalette {
        scheme == .dark ? .dark : .light
    }
}

// ── SwiftUI environment access ───────────────────────────────────────────────
private struct ApolloPaletteKey: EnvironmentKey {
    static let defaultValue: ApolloPalette = .dark
}

extension EnvironmentValues {
    var apollo: ApolloPalette {
        get { self[ApolloPaletteKey.self] }
        set { self[ApolloPaletteKey.self] = newValue }
    }
}

extension View {
    /// Injects the active Apollo palette so children can read it via `@Environment(\.apollo)`.
    func apolloPalette() -> some View {
        modifier(ApolloPaletteInjector())
    }
}

private struct ApolloPaletteInjector: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        content.environment(\.apollo, ApolloPalette.current(for: scheme))
    }
}

// ── Typography helpers ───────────────────────────────────────────────────────
extension Font {
    /// Compact uppercase label, matches the web `letterSpacing: 0.12em` style.
    static let apolloLabel = Font.system(size: 10, weight: .semibold, design: .default)
    static let apolloMono  = Font.system(size: 12, weight: .regular, design: .monospaced)
    static let apolloTitle = Font.system(size: 26, weight: .light, design: .default)
}

// ── Dynamic Type–aware font helpers ──────────────────────────────────────────
/// Use these instead of fixed `.font(.system(size:))` for text that should
/// scale with the user's Dynamic Type setting. The base sizes match the
/// original fixed sizes at `.large` (the system default).
extension View {
    /// Body text (replaces `.font(.system(size: 14))`)
    func apolloBody() -> some View { font(.system(.body)) }
    /// Subtitle text (replaces `.font(.system(size: 13))`)
    func apolloSubhead() -> some View { font(.system(.subheadline)) }
    /// Small muted text (replaces `.font(.system(size: 11/12))`)
    func apolloCaption() -> some View { font(.system(.caption)) }
    /// Section title (replaces `.font(.system(size: 28, weight: .light))`)
    func apolloLargeTitle() -> some View { font(.system(.title, weight: .light)) }
    /// Card title (replaces `.font(.system(size: 17, weight: .regular))`)
    func apolloHeadline() -> some View { font(.system(.headline)) }
}
