//
//  SubjectReviewView.swift
//  ApolloEngine
//

import SwiftUI
import SwiftData

struct SubjectReviewView: View {
    @Bindable var subject: Subject
    @Environment(\.apollo) private var palette
    @Environment(\.modelContext) private var context

    @State private var draft: DSP = DSP()
    @State private var isEditing = false
    @State private var generating = false
    @State private var error: String?

    var body: some View {
        ZStack {
            AtmosphereBackdrop(section: .review)
            ScrollView {
                ApolloReadingWidth(maxWidth: 920) {
                    VStack(alignment: .leading, spacing: 18) {
                        if !subject.conflicts.isEmpty {
                            conflictsCard
                        }

                        HStack(spacing: 16) {
                            GlassCard(cornerRadius: 18, padding: 18) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("CONFIDENCE")
                                        .font(.system(size: 10, weight: .semibold))
                                        .tracking(1.2).foregroundStyle(palette.label)
                                    HStack {
                                        Text("\(draft.confidence_score)%")
                                            .font(.system(size: 30, weight: .light))
                                            .foregroundStyle(Apollo.confidenceColor(draft.confidence_score))
                                            .contentTransition(.numericText())
                                        if isEditing {
                                            Slider(value: Binding(
                                                get: { Double(draft.confidence_score) },
                                                set: { draft.confidence_score = Int($0) }
                                            ), in: 0...100)
                                            .tint(Apollo.amber)
                                        }
                                    }
                                }
                            }
                            GlassCard(cornerRadius: 18, padding: 18) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("CLASSIFICATION")
                                        .font(.system(size: 10, weight: .semibold))
                                        .tracking(1.2).foregroundStyle(palette.label)
                                    if isEditing {
                                        TextField("Classification...", text: $draft.classification)
                                            .textFieldStyle(.plain)
                                            .padding(8)
                                            .background(RoundedRectangle(cornerRadius: 8).fill(palette.chipBg))
                                    } else {
                                        Text(draft.classification.isEmpty ? "—" : draft.classification)
                                            .font(.system(size: 17, weight: .light))
                                            .foregroundStyle(palette.title)
                                    }
                                }
                            }
                        }

                        sectionCard(icon: "doc.text", title: "Executive Summary", color: Apollo.amber) {
                            if isEditing {
                                TextEditor(text: $draft.executive_summary)
                                    .frame(minHeight: 180)
                                    .scrollContentBackground(.hidden)
                                    .padding(8)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(palette.chipBg))
                            } else {
                                Text(draft.executive_summary.isEmpty ? "No summary available." : draft.executive_summary)
                                    .font(.system(size: 14))
                                    .foregroundStyle(palette.text)
                                    .lineSpacing(4)
                            }
                        }

                        sectionCard(icon: "brain", title: "Personality Matrix (Big Five)", color: Apollo.violet) {
                            PersonalityMatrixView(matrix: draft.personality_matrix,
                                                  editable: isEditing,
                                                  onChange: { draft.personality_matrix = $0 })
                        }

                        sectionCard(icon: "point.3.connected.trianglepath.dotted", title: "Predictive Model", color: Apollo.emerald) {
                            ActionResponseMatrixView(entries: draft.action_response_matrix)
                        }

                        sectionCard(icon: "target", title: "Core Drivers", color: Apollo.emerald) {
                            HStack(alignment: .top, spacing: 16) {
                                pillList(title: "MOTIVATIONS", color: Apollo.emerald, items: draft.motivations)
                                pillList(title: "FEARS", color: Apollo.rose, items: draft.fears)
                            }
                        }

                        sectionCard(icon: "checkmark.seal", title: "Final Assessment", color: Apollo.amber) {
                            if isEditing {
                                TextEditor(text: $draft.final_assessment)
                                    .frame(minHeight: 200)
                                    .scrollContentBackground(.hidden)
                                    .padding(8)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(palette.chipBg))
                            } else {
                                Text(draft.final_assessment.isEmpty ? "No final assessment yet." : draft.final_assessment)
                                    .font(.system(size: 14))
                                    .foregroundStyle(palette.text)
                                    .lineSpacing(4)
                            }
                        }

                        if let error {
                            Text(error)
                                .font(.system(size: 12))
                                .foregroundStyle(Apollo.rose)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .padding(.bottom, 80)
                }
            }
        }
        .navigationTitle("Review: \(subject.name)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(isEditing ? "Save Draft" : "Edit", systemImage: isEditing ? "checkmark" : "pencil") {
                        if isEditing { saveDraft() }
                        isEditing.toggle()
                    }
                    Button("Regenerate DSP", systemImage: "arrow.clockwise") {
                        Task { await regenerateDSP() }
                    }
                    .disabled(generating)
                    Divider()
                    Button("Finalize", systemImage: "lock.fill") {
                        finalize()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear { draft = subject.dsp }
    }

    private func sectionCard<C: View>(icon: String, title: String, color: Color, @ViewBuilder content: @escaping () -> C) -> some View {
        GlassCard(cornerRadius: 20, padding: 22) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(icon: icon, title: title, accent: color)
                content()
            }
        }
    }

    private var conflictsCard: some View {
        GlassCard(cornerRadius: 16, padding: 16, tint: Apollo.rose) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Apollo.rose)
                    Text("Conflicts Detected").font(.system(size: 14, weight: .semibold)).foregroundStyle(Apollo.rose)
                }
                ForEach(subject.conflicts) { c in
                    Text("• \(c.description)").font(.system(size: 12)).foregroundStyle(palette.text)
                }
            }
        }
    }

    private func pillList(title: String, color: Color, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundStyle(color)
            if items.isEmpty {
                Text("None identified").font(.system(size: 12)).foregroundStyle(palette.muted)
            } else {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.system(size: 12))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .foregroundStyle(color)
                        .background(Capsule().fill(color.opacity(0.10)))
                        .overlay(Capsule().strokeBorder(color.opacity(0.25)))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func saveDraft() {
        subject.dsp = draft
        subject.status = .review
        subject.updatedAt = Date()
        try? context.save()
        Haptics.success()
    }

    private func finalize() {
        subject.dsp = draft
        subject.status = .finalized
        subject.dspStatus = .valid
        subject.updatedAt = Date()
        try? context.save()
        Haptics.success()
    }

    private func regenerateDSP() async {
        guard !generating else { return }
        generating = true
        error = nil
        do {
            // Send the analysis results to the worker for full DSP synthesis
            let resultsData = subject.analysisResultsData
            let resultsJSON = (try? JSONSerialization.jsonObject(with: resultsData)) ?? [:]
            let prompt = """
            Generate a Definitive Subject Profile (DSP) for "\(subject.name)" based on the analysis data below. Return a JSON object with executive_summary, classification, confidence_score (int 0-100), confidence_justification, personality_matrix (openness, conscientiousness, extraversion, agreeableness, neuroticism — each with score, label, evidence, indicators), cognitive_architecture, behavioral_patterns, predictions (with trigger, predicted_behavior, probability, confidence_interval, temporal_factors), motivations, fears, final_assessment.

            ANALYSIS DATA:
            \(resultsJSON)
            """
            let schema: [String: Any] = [
                "executive_summary": ["type": "string"],
                "classification": ["type": "string"],
                "confidence_score": ["type": "number"],
                "confidence_justification": ["type": "string"],
                "personality_matrix": ["type": "object"],
                "cognitive_architecture": ["type": "object"],
                "behavioral_patterns": ["type": "array", "items": ["type": "object"]],
                "predictions": ["type": "array", "items": ["type": "object"]],
                "motivations": ["type": "array", "items": ["type": "string"]],
                "fears": ["type": "array", "items": ["type": "string"]],
                "final_assessment": ["type": "string"],
            ]
            let response = try await APIClient.shared.invokeLLM(prompt: prompt, schema: schema)
            let data = try JSONSerialization.data(withJSONObject: response)
            if var decoded = try? JSONDecoder().decode(DSP.self, from: data) {
                decoded.date_of_synthesis = ISO8601DateFormatter().string(from: Date()).prefix(10).description
                decoded.document_id = "DSP-\(subject.id.suffix(6).uppercased())-CP-003-APL"
                draft = decoded
                subject.dsp = decoded
                subject.dspStatus = .valid
                try? context.save()
            }
            Haptics.success()
        } catch {
            self.error = error.localizedDescription
            Haptics.error()
        }
        generating = false
    }
}
