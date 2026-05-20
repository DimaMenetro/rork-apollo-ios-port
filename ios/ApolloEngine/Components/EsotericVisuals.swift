//
//  EsotericVisuals.swift
//  ApolloEngine
//
//  FidelityMeter, ThresholdPhaseArc, NodeConvergenceRadar, CycleTimeline,
//  ValidationDashboard — ports of the web Esoteric Phase 2 components.
//

import SwiftUI

// MARK: - FidelityMeter (signal-bar style)

struct FidelityMeter: View {
    let level: String   // "FULL" | "REDUCED-FIDELITY" | "HALTED"

    private var bars: Int {
        switch level {
        case "FULL": return 5
        case "REDUCED-FIDELITY": return 3
        case "HALTED": return 1
        default: return 0
        }
    }

    private var color: Color {
        switch level {
        case "FULL": return Apollo.emerald
        case "REDUCED-FIDELITY": return Apollo.amber
        case "HALTED": return Apollo.rose
        default: return .gray
        }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i < bars ? color : color.opacity(0.18))
                    .frame(width: 6, height: 8 + CGFloat(i) * 4)
                    .shadow(color: i < bars ? color.opacity(0.5) : .clear, radius: 4)
            }
            Text(level)
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(color)
                .padding(.leading, 8)
        }
    }
}

// MARK: - ThresholdPhaseArc

struct ThresholdPhaseArc: View {
    let assessment: String   // free text — we infer the phase

    private let phases = ["rupture", "reintegration", "plateau", "threshold transit"]

    private var activeIndex: Int {
        let lower = assessment.lowercased()
        for (i, p) in phases.enumerated() where lower.contains(p) { return i }
        return 2 // default to plateau
    }

    @Environment(\.apollo) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 0) {
                ForEach(phases.indices, id: \.self) { i in
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(i == activeIndex ? Apollo.violet : palette.chipBg)
                                .frame(width: i == activeIndex ? 14 : 10,
                                       height: i == activeIndex ? 14 : 10)
                                .shadow(color: i == activeIndex ? Apollo.violet.opacity(0.5) : .clear, radius: 6)
                        }
                        Text(phases[i].capitalized)
                            .font(.system(size: 9, weight: i == activeIndex ? .semibold : .regular))
                            .foregroundStyle(i == activeIndex ? Apollo.violet : palette.muted)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity)
                    if i < phases.count - 1 {
                        Rectangle()
                            .fill(i < activeIndex ? Apollo.violet : palette.chipBg)
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                            .offset(y: -10)
                    }
                }
            }
        }
    }
}

// MARK: - NodeConvergenceRadar

struct NodeConvergenceRadar: View {
    /// Alpha (astrological) scores per domain 0-100
    let alphaScores: [Double]
    /// Beta (numerological) scores per domain 0-100
    let betaScores: [Double]
    let labels: [String]

    @Environment(\.apollo) private var palette

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: size / 2)
            let radius = size * 0.40
            ZStack {
                // Background rings
                ForEach(1..<5) { i in
                    Circle()
                        .stroke(palette.cardStroke, lineWidth: 1)
                        .frame(width: radius * 2 * CGFloat(i) / 4,
                               height: radius * 2 * CGFloat(i) / 4)
                }
                // Spokes
                ForEach(0..<labels.count, id: \.self) { i in
                    Path { p in
                        p.move(to: center)
                        let angle = angleFor(i: i, total: labels.count)
                        p.addLine(to: pointOn(center: center, radius: radius, angle: angle))
                    }
                    .stroke(palette.cardStroke, lineWidth: 1)
                }
                // Alpha polygon
                polygon(scores: alphaScores, color: Apollo.amber, radius: radius, center: center)
                // Beta polygon
                polygon(scores: betaScores, color: Apollo.violet, radius: radius, center: center)

                // Labels
                ForEach(0..<labels.count, id: \.self) { i in
                    let angle = angleFor(i: i, total: labels.count)
                    Text(labels[i])
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(palette.muted)
                        .position(pointOn(center: center, radius: radius + 18, angle: angle))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func angleFor(i: Int, total: Int) -> Double {
        -.pi / 2 + (2 * .pi * Double(i) / Double(total))
    }

    private func pointOn(center: CGPoint, radius: CGFloat, angle: Double) -> CGPoint {
        CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
    }

    @ViewBuilder
    private func polygon(scores: [Double], color: Color, radius: CGFloat, center: CGPoint) -> some View {
        Path { path in
            for (i, score) in scores.enumerated() {
                let r = radius * CGFloat(score / 100.0)
                let angle = angleFor(i: i, total: scores.count)
                let pt = pointOn(center: center, radius: r, angle: angle)
                if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }
            path.closeSubpath()
        }
        .fill(color.opacity(0.20))
        .overlay(
            Path { path in
                for (i, score) in scores.enumerated() {
                    let r = radius * CGFloat(score / 100.0)
                    let angle = angleFor(i: i, total: scores.count)
                    let pt = pointOn(center: center, radius: r, angle: angle)
                    if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                }
                path.closeSubpath()
            }
            .stroke(color, lineWidth: 1.5)
        )
    }
}

// MARK: - CycleTimeline (9-year numerological curve)

struct CycleTimeline: View {
    /// Personal year number 1-9 for the current year
    let personalYear: Int
    @Environment(\.apollo) private var palette

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let step = w / 9
            ZStack {
                Path { p in
                    for i in 0..<9 {
                        let x = CGFloat(i) * step + step / 2
                        let energy = sin(Double(i) / 9 * .pi * 2) * 0.4 + 0.5
                        let y = h * (1 - energy)
                        if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                        else { p.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(
                    LinearGradient(colors: [Apollo.amber, Apollo.violet],
                                   startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                )
                // Year markers
                ForEach(0..<9, id: \.self) { i in
                    let year = i + 1
                    let x = CGFloat(i) * step + step / 2
                    VStack(spacing: 4) {
                        Circle()
                            .fill(year == personalYear ? Apollo.violet : palette.chipBg)
                            .frame(width: year == personalYear ? 12 : 6,
                                   height: year == personalYear ? 12 : 6)
                            .shadow(color: year == personalYear ? Apollo.violet.opacity(0.5) : .clear, radius: 5)
                        Text("\(year)")
                            .font(.system(size: 9, weight: year == personalYear ? .semibold : .regular))
                            .foregroundStyle(year == personalYear ? Apollo.violet : palette.muted)
                    }
                    .position(x: x, y: h - 10)
                }
            }
        }
        .frame(height: 70)
    }
}

// MARK: - ValidationDashboard

struct ValidationDashboard: View {
    let validation: SMEValidation
    @Environment(\.apollo) private var palette

    private var passCount: Int { validation.checks.filter(\.passed).count }
    private var percent: Int { Int(Double(passCount) / Double(validation.checks.count) * 100) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                ConfidenceArc(score: percent, diameter: 80, lineWidth: 6, label: "Compliance")
                VStack(alignment: .leading, spacing: 4) {
                    Text("SME Validation")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(palette.title)
                    Text(validation.execution_status)
                        .font(.apolloMono)
                        .foregroundStyle(validation.execution_status == "COMPLIANT" ? Apollo.emerald : Apollo.rose)
                }
            }
            VStack(spacing: 8) {
                ForEach(validation.checks, id: \.label) { check in
                    HStack {
                        Image(systemName: check.passed ? "checkmark.seal.fill" : "xmark.seal.fill")
                            .foregroundStyle(check.passed ? Apollo.emerald : Apollo.rose)
                            .font(.system(size: 13))
                        Text(check.label)
                            .font(.system(size: 12))
                            .foregroundStyle(palette.text)
                        Spacer()
                    }
                }
            }
        }
    }
}
