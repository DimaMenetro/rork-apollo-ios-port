//
//  SubjectCard.swift
//  ApolloEngine
//

import SwiftUI

struct SubjectCard: View {
    let subject: Subject
    @Environment(\.apollo) private var palette

    private var statusColor: Color {
        switch subject.status {
        case .intake: return Apollo.slate
        case .processing: return Apollo.amber
        case .review: return Apollo.violet
        case .finalized: return Apollo.emerald
        }
    }

    var body: some View {
        GlassCard(cornerRadius: 18, padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(subject.name.isEmpty ? "Untitled subject" : subject.name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(palette.title)
                            .lineLimit(1)
                        Text("DSP-\(subject.id.suffix(8).uppercased())")
                            .font(.apolloMono)
                            .foregroundStyle(palette.muted)
                            .lineLimit(1)
                    }
                    Spacer()
                    StatusPill(subject.status.label, color: statusColor)
                }

                HStack(spacing: 14) {
                    StreamDot(label: "TEXT",  active: !subject.streamAText.isEmpty,        color: Apollo.amber)
                    StreamDot(label: "AUDIO", active: !subject.streamBAudio.isEmpty,       color: Apollo.amber)
                    StreamDot(label: "VIDEO", active: !subject.streamCVideo.isEmpty,       color: Apollo.amber)
                    StreamDot(label: "BHV",   active: !subject.streamDBehavioral.isEmpty,  color: Apollo.amber)
                    StreamDot(label: "ANLG",  active: !subject.streamEAnalog.isEmpty,      color: Apollo.amber)
                    Spacer()
                    if subject.hasDSP {
                        Text("\(subject.dsp.confidence_score)%")
                            .font(.apolloMono)
                            .foregroundStyle(Apollo.confidenceColor(subject.dsp.confidence_score))
                    }
                }
            }
        }
    }
}

private struct StreamDot: View {
    let label: String
    let active: Bool
    let color: Color
    @Environment(\.apollo) private var palette

    var body: some View {
        VStack(spacing: 3) {
            Circle()
                .fill(active ? color : palette.chipBg)
                .frame(width: 6, height: 6)
                .shadow(color: active ? color.opacity(0.5) : .clear, radius: 4)
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(active ? color : palette.muted)
        }
    }
}
