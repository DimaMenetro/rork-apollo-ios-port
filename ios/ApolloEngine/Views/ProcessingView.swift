//
//  ProcessingView.swift
//  ApolloEngine
//
//  Live progress for each analysis module. Calls the worker's InvokeLLM endpoint
//  per module with the exact same prompts as the web app's Processing.jsx.
//

import SwiftUI
import SwiftData

private struct AnalysisModule: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let color: Color
    let requiredStreams: [KeyPath<Subject, [String]>]
}

private let modules: [AnalysisModule] = [
    .init(id: "stylometric_fingerprint",
          title: "Module 4.1: Text Logic",
          description: "Extract syntax patterns + word choice",
          icon: "doc.text", color: Apollo.amber,
          requiredStreams: [\Subject.streamAText]),
    .init(id: "cognitive_architecture",
          title: "Module 4.2: Cognitive Logic",
          description: "Map reasoning chains + defense mechanisms",
          icon: "brain", color: Apollo.violet,
          requiredStreams: [\Subject.streamAText]),
    .init(id: "psychomotor_state",
          title: "Module 4.3: Graphology Logic",
          description: "Analyze stroke/pressure from handwriting",
          icon: "pencil.tip", color: Apollo.cyan,
          requiredStreams: [\Subject.streamEAnalog]),
    .init(id: "affective_state",
          title: "Module 4.4: Bio-Signal Logic",
          description: "Audio prosody + video micro-expressions",
          icon: "waveform.path", color: Apollo.rose,
          requiredStreams: [\Subject.streamBAudio, \Subject.streamCVideo]),
    .init(id: "behavioral_loop",
          title: "Module 4.5: Agentic Logic",
          description: "Action timing + recursive habits",
          icon: "arrow.triangle.2.circlepath", color: Apollo.emerald,
          requiredStreams: [\Subject.streamDBehavioral]),
]

struct ProcessingView: View {
    @Bindable var subject: Subject
    @Environment(\.apollo) private var palette
    @Environment(\.modelContext) private var context

    @State private var statuses: [String: String] = [:]
    @State private var running = false
    @State private var currentModuleIndex = 0
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            AtmosphereBackdrop(section: .processing)
            ScrollView {
                ApolloReadingWidth(maxWidth: 820) {
                    VStack(alignment: .leading, spacing: 16) {
                        progressCard
                        ForEach(modules) { module in
                            moduleRow(module)
                        }
                        if let errorMessage {
                            errorBanner(errorMessage)
                        }
                        Button {
                            Task { await runAnalysis() }
                        } label: {
                            HStack {
                                if running {
                                    ProgressView().tint(.white)
                                    Text("Processing...")
                                } else {
                                    Image(systemName: "play.fill")
                                    Text("Run Analysis")
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ApolloPrimaryButtonStyle())
                        .disabled(running)
                        .padding(.top, 8)

                        if subject.status == .review {
                            NavigationLink(value: NavRoute.review(subject.id)) {
                                HStack {
                                    Text("Review DSP Draft")
                                    Image(systemName: "arrow.right")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(ApolloSecondaryButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .padding(.bottom, 60)
                }
            }
        }
        .navigationTitle("Processing: \(subject.name)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var progressCard: some View {
        let total = modules.filter { mod in
            mod.requiredStreams.contains { subject[keyPath: $0].count > 0 }
        }.count
        let done = statuses.values.filter { $0 == "complete" || $0 == "conflict" }.count
        let percent = total > 0 ? Double(done) / Double(total) : 0
        return GlassCard(cornerRadius: 18, padding: 18) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Analysis Progress")
                        .font(.system(size: 13))
                        .foregroundStyle(palette.subtitle)
                    Spacer()
                    Text("\(Int(percent * 100))%")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Apollo.amber)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(palette.chipBg).frame(height: 4)
                        Capsule()
                            .fill(LinearGradient(colors: [Apollo.amber, Apollo.amberDeep],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: CGFloat(percent) * geo.size.width, height: 4)
                            .animation(.easeInOut, value: percent)
                    }
                }
                .frame(height: 4)
                if running {
                    Text("Running \(modules[currentModuleIndex].title)...")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.muted)
                }
            }
        }
    }

    private func moduleRow(_ module: AnalysisModule) -> some View {
        let hasData = module.requiredStreams.contains { subject[keyPath: $0].count > 0 }
        let status = hasData ? (statuses[module.id] ?? "pending") : "skipped"
        return GlassCard(cornerRadius: 16, padding: 16) {
            HStack(spacing: 14) {
                Image(systemName: module.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(module.color)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(module.color.opacity(0.14)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(module.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(palette.title)
                    Text(module.description).font(.system(size: 11)).foregroundStyle(palette.muted)
                }
                Spacer()
                statusBadge(status)
            }
        }
    }

    @ViewBuilder
    private func statusBadge(_ status: String) -> some View {
        switch status {
        case "running":
            ProgressView().controlSize(.small)
        case "complete":
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Apollo.emerald)
        case "error":
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Apollo.rose)
        case "conflict":
            Image(systemName: "bolt.trianglebadge.exclamationmark").foregroundStyle(Apollo.amber)
        case "skipped":
            Text("NO DATA").font(.system(size: 9, weight: .semibold)).tracking(0.8).foregroundStyle(palette.muted)
        default:
            Text("PENDING").font(.system(size: 9, weight: .semibold)).tracking(0.8).foregroundStyle(palette.muted)
        }
    }

    private func errorBanner(_ msg: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Apollo.rose)
            Text(msg).font(.system(size: 12)).foregroundStyle(Apollo.rose)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Apollo.rose.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Apollo.rose.opacity(0.25)))
    }

    // MARK: - Execution

    private func runAnalysis() async {
        guard !running else { return }
        running = true
        errorMessage = nil
        var results = AnalysisResults()
        for (i, module) in modules.enumerated() {
            currentModuleIndex = i
            let hasData = module.requiredStreams.contains { subject[keyPath: $0].count > 0 }
            guard hasData else { continue }
            statuses[module.id] = "running"
            do {
                // For the affective-state module, run Hume + AssemblyAI on EVERY
                // audio AND video file so the LLM receives transcription plus
                // multi-modal emotional/facial/body-language signal exactly like
                // the Base44 flow expects. Video URLs get Hume face + prosody +
                // language + burst; audio URLs get prosody + language + burst.
                // AssemblyAI universal-3-pro transcribes both.
                var audioContext = ""
                if module.id == "affective_state" {
                    let mediaItems: [(String, APIClient.MediaKind)] =
                        subject.streamBAudio.map { ($0, .audio) }
                        + subject.streamCVideo.map { ($0, .video) }
                    var blocks: [String] = []
                    for (url, kind) in mediaItems {
                        do {
                            let analysis = try await APIClient.shared.analyzeMedia(fileURL: url, kind: kind)
                            var bits: [String] = []
                            let label = kind == .video ? "VIDEO" : "AUDIO"
                            bits.append("[\(label)] \(url)")
                            if let t = analysis.transcript, !t.isEmpty {
                                bits.append("TRANSCRIPT (AssemblyAI universal-3-pro):\n\(t)")
                            } else if let err = analysis.transcript_error {
                                bits.append("TRANSCRIPT ERROR: \(err)")
                            }
                            if let p = analysis.predictions, let data = try? JSONEncoder().encode(p),
                               let json = String(data: data, encoding: .utf8) {
                                let header = kind == .video
                                    ? "HUME MULTI-MODAL (face FACS + prosody + language + burst):"
                                    : "HUME PROSODY + LANGUAGE + BURST:"
                                bits.append("\(header)\n\(json.prefix(8000))")
                            } else if let err = analysis.hume_error {
                                bits.append("HUME ERROR: \(err)")
                            }
                            blocks.append(bits.joined(separator: "\n"))
                        } catch {
                            blocks.append("[\(kind == .video ? "VIDEO" : "AUDIO")] \(url)\nANALYSIS FAILED: \(error.localizedDescription)")
                        }
                    }
                    if !blocks.isEmpty {
                        audioContext = "\n\nPRE-ANALYZED MEDIA DATA:\n" + blocks.joined(separator: "\n\n---\n\n")
                    }
                }
                let prompt = analysisPrompt(for: module.id, subjectName: subject.name) + audioContext
                let fileURLs: [String]
                switch module.id {
                case "stylometric_fingerprint", "cognitive_architecture":
                    fileURLs = subject.streamAText
                case "psychomotor_state":
                    fileURLs = subject.streamEAnalog
                case "affective_state":
                    fileURLs = subject.streamBAudio + subject.streamCVideo
                case "behavioral_loop":
                    fileURLs = subject.streamDBehavioral
                default:
                    fileURLs = []
                }
                let schema: [String: Any] = [
                    "summary": ["type": "string"],
                    "key_patterns": ["type": "array", "items": ["type": "string"]],
                    "indicators": ["type": "array", "items": ["type": "string"]],
                    "confidence": ["type": "number"],
                    "flags": ["type": "array", "items": ["type": "string"]],
                    "processing_notes": ["type": "string"],
                ]
                let response = try await APIClient.shared.invokeLLM(prompt: prompt, schema: schema, fileURLs: fileURLs)
                let result = AnalysisModuleResult(
                    summary: response["summary"] as? String ?? "",
                    key_patterns: response["key_patterns"] as? [String] ?? [],
                    indicators: response["indicators"] as? [String] ?? [],
                    confidence: response["confidence"] as? Double ?? 0,
                    flags: response["flags"] as? [String] ?? [],
                    processing_notes: response["processing_notes"] as? String ?? "",
                    preprocessing_info: ""
                )
                switch module.id {
                case "stylometric_fingerprint": results.stylometric_fingerprint = result
                case "cognitive_architecture":  results.cognitive_architecture = result
                case "psychomotor_state":       results.psychomotor_state = result
                case "affective_state":         results.affective_state = result
                case "behavioral_loop":         results.behavioral_loop = result
                default: break
                }
                statuses[module.id] = "complete"
                Haptics.soft()
            } catch {
                statuses[module.id] = "error"
                errorMessage = error.localizedDescription
            }
        }
        subject.analysisResults = results
        subject.status = .review
        subject.updatedAt = Date()
        try? context.save()
        running = false
        Haptics.success()
    }

    private func analysisPrompt(for moduleKey: String, subjectName: String) -> String {
        switch moduleKey {
        case "stylometric_fingerprint":
            return "Analyze the attached text data for subject \"\(subjectName)\". Extract writing style patterns, word choice tendencies, emotional tone, linguistic fingerprint characteristics, and any notable deviations."
        case "cognitive_architecture":
            return "Analyze the attached content for subject \"\(subjectName)\" to map cognitive patterns: reasoning chains, defense mechanisms, decision-making patterns, and cognitive biases."
        case "psychomotor_state":
            return "Analyze the attached handwriting sample for subject \"\(subjectName)\": stroke patterns, pressure indicators, baseline stability, slant, letter formation consistency."
        case "affective_state":
            return "Analyze the attached audio/video for subject \"\(subjectName)\": vocal pitch variations, facial micro-expressions, emotional baseline, congruence between verbal and non-verbal cues."
        case "behavioral_loop":
            return "Analyze the attached behavioral data for subject \"\(subjectName)\": action timing patterns, recursive habits, decision velocity, behavioral triggers and responses."
        default: return ""
        }
    }
}
