//
//  PersonalityMatrixView.swift
//  ApolloEngine
//
//  Big Five horizontal gauges with evidence and indicators. Mirrors the web component.
//

import SwiftUI

struct PersonalityMatrixView: View {
    let matrix: PersonalityMatrix
    var editable: Bool = false
    var onChange: ((PersonalityMatrix) -> Void)? = nil

    @Environment(\.apollo) private var palette
    @State private var animated: Bool = false

    var body: some View {
        VStack(spacing: 18) {
            ForEach(matrix.allTraits, id: \.key) { entry in
                TraitRow(
                    label: entry.label,
                    trait: entry.trait,
                    animated: animated,
                    editable: editable,
                    onChange: { updated in
                        if let cb = onChange {
                            var copy = matrix
                            switch entry.key {
                            case "openness": copy.openness = updated
                            case "conscientiousness": copy.conscientiousness = updated
                            case "extraversion": copy.extraversion = updated
                            case "agreeableness": copy.agreeableness = updated
                            case "neuroticism": copy.neuroticism = updated
                            default: break
                            }
                            cb(copy)
                        }
                    }
                )
            }
        }
        .onAppear { withAnimation(.spring(response: 1.0, dampingFraction: 0.85)) { animated = true } }
    }
}

private struct TraitRow: View {
    let label: String
    let trait: TraitScore
    let animated: Bool
    let editable: Bool
    let onChange: (TraitScore) -> Void

    @Environment(\.apollo) private var palette

    private var color: Color {
        if trait.score >= 70 { return Apollo.emerald }
        if trait.score >= 40 { return Apollo.amber }
        return Apollo.rose
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(palette.title)
                Spacer()
                Text("\(trait.score)%")
                    .font(.apolloMono)
                    .foregroundStyle(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(palette.chipBg).frame(height: 6)
                    Capsule()
                        .fill(LinearGradient(colors: [color, color.opacity(0.7)],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: (animated ? CGFloat(trait.score) / 100.0 : 0) * geo.size.width,
                               height: 6)
                        .shadow(color: color.opacity(0.5), radius: 6)
                }
            }
            .frame(height: 6)

            if !trait.evidence.isEmpty {
                Text("\u{201C}\(trait.evidence)\u{201D}")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.muted)
                    .italic()
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !trait.indicators.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(trait.indicators, id: \.self) { ind in
                        HStack(alignment: .top, spacing: 6) {
                            Text("\u{2022}").foregroundStyle(palette.muted)
                            Text(ind).font(.system(size: 12)).foregroundStyle(palette.text)
                        }
                    }
                }
            }
        }
    }
}
