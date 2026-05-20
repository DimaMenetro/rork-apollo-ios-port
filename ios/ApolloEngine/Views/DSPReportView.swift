//
//  DSPReportView.swift
//  ApolloEngine
//

import SwiftUI

struct DSPReportView: View {
    let subject: Subject
    @Environment(\.apollo) private var palette
    private var dsp: DSP { subject.dsp }

    var body: some View {
        ZStack {
            AtmosphereBackdrop(section: .dsp)
            ScrollView {
                ApolloReadingWidth(maxWidth: 920) {
                    VStack(alignment: .leading, spacing: 18) {
                        headerCard

                        sectionCard(icon: "doc.text", title: "Executive Summary", color: Apollo.amber) {
                            Text(dsp.executive_summary.isEmpty ? "No summary available." : dsp.executive_summary)
                                .font(.system(size: 14)).foregroundStyle(palette.text).lineSpacing(4)
                        }

                        sectionCard(icon: "brain", title: "Personality Matrix", color: Apollo.violet) {
                            PersonalityMatrixView(matrix: dsp.personality_matrix)
                        }

                        if !dsp.cognitive_architecture.thinking_style.isEmpty
                            || !dsp.cognitive_architecture.epistemic_requirements.isEmpty
                            || !dsp.cognitive_architecture.defense_mechanisms.isEmpty {
                            sectionCard(icon: "circle.grid.cross", title: "Cognitive Architecture", color: Apollo.violet) {
                                VStack(alignment: .leading, spacing: 16) {
                                    if !dsp.cognitive_architecture.thinking_style.isEmpty {
                                        labelBlock("Thinking Style", text: dsp.cognitive_architecture.thinking_style)
                                    }
                                    if !dsp.cognitive_architecture.epistemic_requirements.isEmpty {
                                        labelBlock("Epistemic Requirements", text: dsp.cognitive_architecture.epistemic_requirements)
                                    }
                                    if !dsp.cognitive_architecture.defense_mechanisms.isEmpty {
                                        labelBlock("Defense Mechanisms", text: dsp.cognitive_architecture.defense_mechanisms)
                                    }
                                    ForEach(dsp.cognitive_architecture.sub_sections) { sub in
                                        labelBlock(sub.title, text: sub.content)
                                    }
                                }
                            }
                        }

                        if !dsp.behavioral_patterns.isEmpty {
                            sectionCard(icon: "arrow.triangle.branch", title: "Behavioral Patterns", color: Apollo.emerald) {
                                VStack(spacing: 10) {
                                    ForEach(dsp.behavioral_patterns) { p in
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(p.label).font(.system(size: 13, weight: .semibold)).foregroundStyle(Apollo.amber)
                                            Text(p.description).font(.system(size: 13)).foregroundStyle(palette.text)
                                            Text(p.context).font(.system(size: 11)).italic().foregroundStyle(palette.muted)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(12)
                                        .background(RoundedRectangle(cornerRadius: 12).fill(palette.chipBg))
                                    }
                                }
                            }
                        }

                        sectionCard(icon: "point.3.connected.trianglepath.dotted", title: "Predictive Model", color: Apollo.emerald) {
                            ActionResponseMatrixView(entries: dsp.action_response_matrix)
                        }

                        if !dsp.motivations.isEmpty || !dsp.fears.isEmpty {
                            HStack(alignment: .top, spacing: 14) {
                                sectionCard(icon: "target", title: "Motivations", color: Apollo.emerald) {
                                    driverList(items: dsp.motivations, color: Apollo.emerald)
                                }
                                sectionCard(icon: "shield", title: "Fears", color: Apollo.rose) {
                                    driverList(items: dsp.fears, color: Apollo.rose)
                                }
                            }
                        }

                        if !dsp.final_assessment.isEmpty {
                            sectionCard(icon: "checkmark.seal", title: "Final Assessment", color: Apollo.amber) {
                                Text(dsp.final_assessment).font(.system(size: 14)).foregroundStyle(palette.text).lineSpacing(4)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .padding(.bottom, 80)
                }
            }
        }
        .navigationTitle("Definitive Subject Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: NavRoute.esoteric(subject.id)) {
                    Label("Esoteric", systemImage: "sparkles")
                }
            }
        }
    }

    private var headerCard: some View {
        GlassCard(cornerRadius: 22, padding: 24, tint: Apollo.amber) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        StatusPill("Finalized", color: Apollo.emerald, icon: "lock.fill")
                        StatusPill("Verified", color: palette.muted, icon: "checkmark")
                    }
                    Text(subject.name)
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(palette.title)
                    VStack(alignment: .leading, spacing: 4) {
                        metaRow("DOCUMENT ID", subject.documentID)
                        metaRow("PROTOCOL", dsp.protocol_version)
                        metaRow("DATE", dsp.date_of_synthesis.isEmpty ? "—" : dsp.date_of_synthesis)
                    }
                }
                Spacer()
                ConfidenceArc(score: dsp.confidence_score, diameter: 120, lineWidth: 8)
            }
            if !dsp.classification.isEmpty {
                Divider().padding(.vertical, 12)
                VStack(alignment: .leading, spacing: 6) {
                    Text("CLASSIFICATION").font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundStyle(palette.label)
                    Text(dsp.classification).font(.system(size: 18, weight: .light)).foregroundStyle(Apollo.amber)
                }
            }
        }
    }

    private func metaRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: 10) {
            Text(label).font(.system(size: 9, weight: .semibold)).tracking(1.2).foregroundStyle(palette.label).frame(width: 100, alignment: .leading)
            Text(value).font(.apolloMono).foregroundStyle(palette.text)
        }
    }

    private func labelBlock(_ label: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased()).font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundStyle(palette.label)
            Text(text).font(.system(size: 13)).foregroundStyle(palette.text).lineSpacing(3)
        }
    }

    private func driverList(items: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.system(size: 12))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(color)
                    .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.10)))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(color.opacity(0.25)))
            }
        }
    }

    private func sectionCard<C: View>(icon: String, title: String, color: Color, @ViewBuilder content: @escaping () -> C) -> some View {
        GlassCard(cornerRadius: 20, padding: 22) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(icon: icon, title: title, accent: color)
                content()
            }
        }
    }
}
