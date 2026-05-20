//
//  ActionResponseMatrixView.swift
//  ApolloEngine
//

import SwiftUI

struct ActionResponseMatrixView: View {
    let entries: [ActionResponse]
    @Environment(\.apollo) private var palette
    @State private var animated = false

    var body: some View {
        if entries.isEmpty {
            Text("No predictions documented")
                .font(.system(size: 13))
                .foregroundStyle(palette.muted)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 12)
        } else {
            VStack(spacing: 14) {
                ForEach(entries) { entry in
                    PredictionCard(entry: entry, animated: animated)
                }
            }
            .onAppear { withAnimation(.spring(response: 1.0, dampingFraction: 0.85)) { animated = true } }
        }
    }
}

private struct PredictionCard: View {
    let entry: ActionResponse
    let animated: Bool
    @Environment(\.apollo) private var palette

    private var color: Color {
        if entry.probability >= 80 { return Apollo.emerald }
        if entry.probability >= 60 { return Apollo.amber }
        return Apollo.rose
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            labeledBlock("TRIGGER", text: entry.trigger, color: Apollo.amber)
            labeledBlock("PREDICTED BEHAVIOR", text: entry.predicted_behavior, color: Apollo.emerald)

            HStack(alignment: .center, spacing: 12) {
                Text("Probability: \(entry.probability)%")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
                if let ci = entry.confidence_interval {
                    Text("CI [\(ci.lower)%, \(ci.upper)%]")
                        .font(.apolloMono)
                        .foregroundStyle(palette.muted)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(palette.chipBg).frame(height: 5)
                    Capsule()
                        .fill(color)
                        .frame(width: (animated ? CGFloat(entry.probability) / 100.0 : 0) * geo.size.width, height: 5)
                        .shadow(color: color.opacity(0.5), radius: 4)
                }
            }
            .frame(height: 5)

            if !entry.temporal_factors.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Text("TEMPORAL")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.0)
                        .foregroundStyle(Apollo.violet)
                    Text(entry.temporal_factors)
                        .font(.system(size: 12))
                        .foregroundStyle(palette.muted)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(palette.chipBg))
    }

    @ViewBuilder
    private func labeledBlock(_ label: String, text: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 9, weight: .semibold)).tracking(1.0).foregroundStyle(color)
            Text(text).font(.system(size: 13)).foregroundStyle(palette.text).fixedSize(horizontal: false, vertical: true)
        }
    }
}
