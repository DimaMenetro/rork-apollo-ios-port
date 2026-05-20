//
//  SubjectDetailView.swift
//  ApolloEngine
//
//  Landing screen for a Subject — surfaces the current phase + quick links
//  to all related views (Intake, Processing, Review, DSP, Esoteric, Unified).
//

import SwiftUI
import SwiftData

struct SubjectDetailView: View {
    @Bindable var subject: Subject
    @Environment(\.apollo) private var palette
    @Environment(\.modelContext) private var context

    var body: some View {
        ZStack {
            AtmosphereBackdrop(section: section(for: subject.status))
            ScrollView {
                ApolloReadingWidth(maxWidth: 820) {
                    VStack(alignment: .leading, spacing: 18) {
                        headerCard
                        phaseLinks
                        if !subject.conflicts.isEmpty {
                            conflictBanner
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .padding(.bottom, 80)
                }
            }
        }
        .navigationTitle(subject.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    NavigationLink("Edit Intake", value: NavRoute.subject(subject.id))
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        context.delete(subject)
                        Haptics.warning()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    private var headerCard: some View {
        GlassCard(cornerRadius: 22, padding: 22, tint: tintForStatus) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    StatusPill(subject.status.label, color: tintForStatus)
                    Text(subject.name).font(.system(size: 28, weight: .light)).foregroundStyle(palette.title)
                    Text(subject.documentID).font(.apolloMono).foregroundStyle(palette.muted)
                    HStack(spacing: 16) {
                        Label("\(subject.streamCount)/5", systemImage: "doc.on.doc")
                            .font(.system(size: 12))
                            .foregroundStyle(palette.muted)
                        Label("\(subject.totalEvidence) files", systemImage: "paperclip")
                            .font(.system(size: 12))
                            .foregroundStyle(palette.muted)
                    }
                }
                Spacer()
                if subject.hasDSP {
                    ConfidenceArc(score: subject.dsp.confidence_score, diameter: 96, lineWidth: 6)
                }
            }
        }
    }

    private var phaseLinks: some View {
        VStack(spacing: 12) {
            phaseRow(label: "Intake", subtitle: "Manage evidence streams",
                     icon: "tray.and.arrow.down", color: Apollo.slate,
                     route: .subject(subject.id))
            phaseRow(label: "Processing", subtitle: "Run the 5 analysis modules",
                     icon: "waveform.path.ecg", color: Apollo.amber,
                     route: .processing(subject.id))
            phaseRow(label: "Review", subtitle: subject.hasDSP ? "Refine the DSP draft" : "Generate the DSP",
                     icon: "doc.text.below.ecg", color: Apollo.violet,
                     route: .review(subject.id))
            phaseRow(label: "DSP Report", subtitle: subject.hasDSP ? "View finalized profile" : "DSP pending",
                     icon: "checkmark.seal", color: Apollo.emerald,
                     route: .dspReport(subject.id), disabled: !subject.hasDSP)
            phaseRow(label: "Esoteric Profile", subtitle: subject.esotericProfile != nil ? "View CP-012 output" : "Execute CP-012-O-D-ESP",
                     icon: "sparkles", color: Apollo.violet,
                     route: .esoteric(subject.id))
            phaseRow(label: "Unified Dossier", subtitle: subject.hasUnified ? "MELLMA synthesis" : "Requires DSP + Esoteric",
                     icon: "wand.and.stars", color: Apollo.cyan,
                     route: .unified(subject.id), disabled: !subject.hasDSP || subject.esotericProfile == nil)
        }
    }

    private var conflictBanner: some View {
        GlassCard(cornerRadius: 16, padding: 14, tint: Apollo.rose) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Apollo.rose)
                Text("\(subject.conflicts.count) conflict\(subject.conflicts.count == 1 ? "" : "s") flagged")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Apollo.rose)
                Spacer()
            }
        }
    }

    private func phaseRow(label: String, subtitle: String, icon: String, color: Color, route: NavRoute, disabled: Bool = false) -> some View {
        NavigationLink(value: route) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(color)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(color.opacity(0.14)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(.system(size: 14, weight: .semibold)).foregroundStyle(palette.title)
                    Text(subtitle).font(.system(size: 11)).foregroundStyle(palette.muted)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(palette.muted)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(palette.cardStroke, lineWidth: 1)
            )
            .opacity(disabled ? 0.4 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private var tintForStatus: Color {
        switch subject.status {
        case .intake: return Apollo.slate
        case .processing: return Apollo.amber
        case .review: return Apollo.violet
        case .finalized: return Apollo.emerald
        }
    }

    private func section(for status: SubjectStatus) -> Apollo.Section {
        switch status {
        case .intake: return .intake
        case .processing: return .processing
        case .review: return .review
        case .finalized: return .dsp
        }
    }
}
