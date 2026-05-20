//
//  UnifiedDossierView.swift
//  ApolloEngine
//

import SwiftUI
import SwiftData

struct UnifiedDossierView: View {
    @Bindable var subject: Subject
    @Environment(\.apollo) private var palette
    @Environment(\.modelContext) private var context

    @State private var synthesizing = false
    @State private var error: String?

    private var hasDSP: Bool { subject.hasDSP }
    private var hasEsp: Bool { subject.esotericProfile?.execution_status.isEmpty == false }
    private var dossier: UnifiedDossier? { subject.unifiedDossier }

    private var isStale: Bool {
        guard let d = dossier else { return false }
        return d.dsp_source_date != subject.dsp.date_of_synthesis
            || d.esoteric_source_date != (subject.esotericProfile?.date_executed ?? "")
    }

    var body: some View {
        ZStack {
            AtmosphereBackdrop(section: .unified)
            ScrollView {
                ApolloReadingWidth(maxWidth: 920) {
                    VStack(alignment: .leading, spacing: 18) {
                        headerCard

                        if !hasDSP || !hasEsp {
                            EmptyStateView(
                                icon: "square.stack.3d.up",
                                title: "Both lenses required",
                                message: "Synthesis needs both a DSP and an Esoteric profile. Generate the missing one first.",
                                accent: Apollo.cyan
                            )
                        } else if let d = dossier {
                            convergenceCard(d.convergence_map)
                            narrativeSection("Unified Identity Portrait", d.unified_identity_portrait)
                            narrativeSection("Psychodynamic Architecture", d.psychodynamic_architecture)
                            narrativeSection("Personality & Archetypal Resonance", d.personality_archetypal_resonance)
                            narrativeSection("Behavioral Topology", d.behavioral_topology)
                            narrativeSection("Predictive Convergence Model", d.predictive_convergence_model)
                            narrativeSection("Core Drivers & Shadow Material", d.core_drivers_shadow)
                            finalAssessment(d)
                        } else {
                            EmptyStateView(
                                icon: "wand.and.stars",
                                title: "Synthesize the unified dossier",
                                message: "Merge the DSP and Esoteric profile into a single woven document.",
                                accent: Apollo.cyan
                            )
                        }

                        if let error {
                            Text(error).font(.system(size: 12)).foregroundStyle(Apollo.rose)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .padding(.bottom, 80)
                }
            }
        }
        .navigationTitle("Unified Dossier")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        GlassCard(cornerRadius: 22, padding: 22, tint: Apollo.cyan) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("MELLMA UNIFIED SYNTHESIS").font(.system(size: 10, weight: .semibold)).tracking(1.4).foregroundStyle(palette.label)
                        Text(subject.name).font(.system(size: 26, weight: .light)).foregroundStyle(palette.title)
                        if let d = dossier {
                            Text("Synthesized \(d.date_synthesized)").font(.apolloMono).foregroundStyle(palette.muted)
                        }
                    }
                    Spacer()
                    if let d = dossier {
                        ConfidenceArc(score: d.synthesis_confidence, diameter: 90, lineWidth: 6, label: "Synthesis")
                    }
                }
                if isStale {
                    Label("Stale: a source was updated after the last synthesis.",
                          systemImage: "exclamationmark.triangle")
                        .font(.system(size: 12))
                        .foregroundStyle(Apollo.amber)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Apollo.amber.opacity(0.08)))
                }
                Button {
                    Task { await synthesize() }
                } label: {
                    HStack {
                        if synthesizing {
                            ProgressView().tint(.white); Text("Synthesizing...")
                        } else {
                            Image(systemName: "wand.and.stars")
                            Text(dossier == nil ? "Synthesize Unified Dossier" : "Re-synthesize")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ApolloPrimaryButtonStyle(tint: Apollo.cyan))
                .disabled(!hasDSP || !hasEsp || synthesizing)
                .opacity((!hasDSP || !hasEsp || synthesizing) ? 0.5 : 1)
            }
        }
    }

    private func convergenceCard(_ map: ConvergenceMap) -> some View {
        GlassCard(cornerRadius: 20, padding: 22) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(icon: "circle.hexagongrid.fill", title: "Convergence Map", accent: Apollo.cyan)
                HStack(alignment: .top, spacing: 16) {
                    if !map.convergence_points.isEmpty {
                        NodeConvergenceRadar(
                            alphaScores: map.convergence_points.map { Double($0.confidence) },
                            betaScores: map.convergence_points.map { Double(max(40, 100 - $0.confidence / 2)) },
                            labels: map.convergence_points.map { String($0.domain.prefix(8)) }
                        )
                        .frame(maxWidth: 220)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("ALIGNMENT").font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundStyle(palette.label)
                        Text("\(map.overall_alignment_score)%").font(.system(size: 36, weight: .light)).foregroundStyle(Apollo.cyan)
                        Text("\(map.convergence_points.count) convergence • \(map.divergence_points.count) divergence")
                            .font(.system(size: 11)).foregroundStyle(palette.muted)
                    }
                }
                if !map.convergence_points.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("CONVERGENCE POINTS").font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundStyle(Apollo.emerald)
                        ForEach(map.convergence_points) { p in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.domain).font(.system(size: 13, weight: .semibold)).foregroundStyle(palette.title)
                                Text(p.significance).font(.system(size: 12)).foregroundStyle(palette.text)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Apollo.emerald.opacity(0.08)))
                        }
                    }
                }
                if !map.divergence_points.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("DIVERGENCE POINTS").font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundStyle(Apollo.rose)
                        ForEach(map.divergence_points) { d in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(d.domain).font(.system(size: 13, weight: .semibold)).foregroundStyle(palette.title)
                                Text(d.arbitration).font(.system(size: 12)).foregroundStyle(palette.text)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Apollo.rose.opacity(0.08)))
                        }
                    }
                }
            }
        }
    }

    private func narrativeSection(_ title: String, _ text: String) -> some View {
        Group {
            if !text.isEmpty {
                GlassCard(cornerRadius: 20, padding: 22) {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(icon: "text.alignleft", title: title, accent: Apollo.cyan)
                        Text(text).font(.system(size: 14)).foregroundStyle(palette.text).lineSpacing(4)
                    }
                }
            }
        }
    }

    private func finalAssessment(_ d: UnifiedDossier) -> some View {
        GlassCard(cornerRadius: 20, padding: 22, tint: Apollo.cyan) {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(icon: "seal.fill", title: "Final Unified Assessment", accent: Apollo.cyan)
                Text(d.final_unified_assessment).font(.system(size: 14)).foregroundStyle(palette.text).lineSpacing(4)
                if !d.synthesis_methodology_note.isEmpty {
                    Divider().padding(.vertical, 8)
                    Text(d.synthesis_methodology_note).font(.system(size: 11)).italic().foregroundStyle(palette.muted)
                }
            }
        }
    }

    private func synthesize() async {
        guard hasDSP, hasEsp, !synthesizing else { return }
        synthesizing = true
        error = nil
        do {
            let unified = try await APIClient.shared.synthesizeDossier(
                subjectId: subject.id,
                dsp: subject.dsp,
                esp: subject.esotericProfile ?? EsotericProfile()
            )
            subject.unifiedDossier = unified
            subject.updatedAt = Date()
            try? context.save()
            Haptics.success()
        } catch {
            self.error = error.localizedDescription
            Haptics.error()
        }
        synthesizing = false
    }
}
