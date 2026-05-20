//
//  EsotericProfileView.swift
//  ApolloEngine
//

import SwiftUI
import SwiftData

struct EsotericProfileView: View {
    @Bindable var subject: Subject
    @Environment(\.apollo) private var palette
    @Environment(\.modelContext) private var context

    @State private var inputs = EsotericInputs()
    @State private var executing = false
    @State private var error: String?
    @State private var visualMode: [String: Bool] = [:]

    private let modes = ["RETROSPECTIVE", "PRESENT-STATE", "PROSPECTIVE", "FULL-CYCLE"]

    private var canExecute: Bool {
        !inputs.full_birth_name.isEmpty && !inputs.date_of_birth.isEmpty && !inputs.place_of_birth.isEmpty
    }

    private var fidelityLabel: String {
        guard canExecute else { return "HALTED" }
        return inputs.time_of_birth.isEmpty ? "REDUCED-FIDELITY" : "FULL"
    }

    var body: some View {
        ZStack {
            AtmosphereBackdrop(section: .esoteric)
            ScrollView {
                ApolloReadingWidth(maxWidth: 920) {
                    VStack(alignment: .leading, spacing: 18) {
                        inputsCard
                        if let profile = subject.esotericProfile {
                            outputCard(profile)
                        } else if !executing {
                            EmptyStateView(
                                icon: "sparkles",
                                title: "No esoteric profile generated yet",
                                message: "Fill in the required inputs and execute CP-012-O-D-ESP.",
                                accent: Apollo.violet
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .padding(.bottom, 80)
                }
            }
        }
        .navigationTitle("Esoteric Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { inputs = subject.esotericInputs }
    }

    private var inputsCard: some View {
        GlassCard(cornerRadius: 22, padding: 22, tint: Apollo.violet) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(icon: "sparkles", title: "Esoteric Inputs — CP-012 §4.10", accent: Apollo.violet)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 12)], spacing: 12) {
                    inputField("Full Birth Name *", placeholder: "John Michael Smith", text: $inputs.full_birth_name)
                    inputField("Date of Birth *", placeholder: "March 15, 1985", text: $inputs.date_of_birth)
                    inputField("Place of Birth *", placeholder: "Chicago, Illinois, USA", text: $inputs.place_of_birth)
                    inputField("Time of Birth", placeholder: "14:32", text: $inputs.time_of_birth)
                    modeField
                    inputField("Timeframe", placeholder: "2023–2026", text: $inputs.timeframe)
                }
                inputField("Focus Domain", placeholder: "e.g. identity transition", text: $inputs.focus)

                HStack(spacing: 10) {
                    Text("Execution state:")
                        .font(.system(size: 11)).foregroundStyle(palette.muted)
                    FidelityMeter(level: fidelityLabel)
                }

                if let error {
                    Text(error).font(.system(size: 12)).foregroundStyle(Apollo.rose)
                }

                Button {
                    Task { await execute() }
                } label: {
                    HStack {
                        if executing {
                            ProgressView().tint(.white)
                            Text("Executing CP-012...")
                        } else {
                            Image(systemName: subject.esotericProfile != nil ? "arrow.clockwise" : "sparkles")
                            Text(subject.esotericProfile != nil ? "Re-Execute CP-012" : "Execute CP-012-O-D-ESP")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ApolloPrimaryButtonStyle(tint: Apollo.violet))
                .disabled(!canExecute || executing)
                .opacity((!canExecute || executing) ? 0.5 : 1)
            }
        }
    }

    private func outputCard(_ profile: EsotericProfile) -> some View {
        GlassCard(cornerRadius: 22, padding: 22) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    SectionHeader(icon: "doc.text.magnifyingglass", title: "Esoteric Analysis Output", accent: Apollo.violet)
                    Spacer()
                    Text(profile.date_executed).font(.apolloMono).foregroundStyle(palette.muted)
                }

                FidelityMeter(level: profile.input_fidelity)

                espSection("Inquiry Frame", text: profile.inquiry_frame, icon: "questionmark.diamond", color: Apollo.violet)
                espSection("Astrological Interpretation (Node Alpha)", text: profile.astrological_interpretation,
                           icon: "sun.max", color: Apollo.amber)
                espSection("Numerological Interpretation (Node Beta)", text: profile.numerological_interpretation,
                           icon: "number", color: Apollo.cyan)

                // Cycle timeline (Personal Year inferred from numerology text)
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(icon: "chart.line.uptrend.xyaxis", title: "Numerological Cycle", accent: Apollo.violet)
                    CycleTimeline(personalYear: inferPersonalYear(from: profile.numerological_interpretation))
                }

                // Threshold phase arc
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(icon: "arrow.left.and.right.righttriangle.left.righttriangle.right",
                                  title: "Threshold Phase", accent: Apollo.violet)
                    ThresholdPhaseArc(assessment: profile.threshold_assessment)
                    Text(profile.threshold_assessment).font(.system(size: 13)).foregroundStyle(palette.text).lineSpacing(3)
                }

                espSection("Unified Emotional Synthesis", text: profile.unified_emotional_synthesis,
                           icon: "infinity", color: Apollo.violet)
                espSection("Strategic Translation", text: profile.strategic_translation,
                           icon: "arrow.right", color: Apollo.emerald)
                espSection("Limitation Statement", text: profile.limitation_statement,
                           icon: "exclamationmark.triangle", color: palette.muted)

                ValidationDashboard(validation: profile.sme_validation)
            }
        }
    }

    private func espSection(_ title: String, text: String, icon: String, color: Color) -> some View {
        Group {
            if !text.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(icon: icon, title: title, accent: color)
                    Text(text).font(.system(size: 13)).foregroundStyle(palette.text).lineSpacing(3)
                }
            }
        }
    }

    private func inputField(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased()).font(.system(size: 9, weight: .semibold)).tracking(1.0).foregroundStyle(palette.label)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(palette.chipBg))
        }
    }

    private var modeField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("MODE").font(.system(size: 9, weight: .semibold)).tracking(1.0).foregroundStyle(palette.label)
            Picker("Mode", selection: $inputs.mode) {
                ForEach(modes, id: \.self) { m in Text(m).tag(m) }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 8).fill(palette.chipBg))
        }
    }

    private func execute() async {
        guard canExecute, !executing else { return }
        executing = true
        error = nil
        subject.esotericInputs = inputs
        try? context.save()
        do {
            let profile = try await APIClient.shared.generateEsoteric(
                subjectId: subject.id,
                inputs: inputs,
                dspSummary: subject.dsp.executive_summary
            )
            subject.esotericProfile = profile
            subject.updatedAt = Date()
            try? context.save()
            Haptics.success()
        } catch {
            self.error = error.localizedDescription
            Haptics.error()
        }
        executing = false
    }

    /// Best-effort: pull a Personal Year digit (1-9) out of the numerology text.
    private func inferPersonalYear(from text: String) -> Int {
        let lower = text.lowercased()
        if let range = lower.range(of: "personal year") {
            let tail = lower[range.upperBound...].prefix(40)
            for c in tail where c.isWholeNumber {
                if let n = Int(String(c)), (1...9).contains(n) { return n }
            }
        }
        return 5
    }
}
