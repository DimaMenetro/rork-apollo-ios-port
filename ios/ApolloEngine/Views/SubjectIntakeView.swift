//
//  SubjectIntakeView.swift
//  ApolloEngine
//

import SwiftUI
import SwiftData

struct SubjectIntakeView: View {
    @Bindable var subject: Subject
    @Environment(\.apollo) private var palette
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var streamA: [String] = []
    @State private var streamB: [String] = []
    @State private var streamC: [String] = []
    @State private var streamD: [String] = []
    @State private var streamE: [String] = []

    private var hasData: Bool { !(streamA.isEmpty && streamB.isEmpty && streamC.isEmpty && streamD.isEmpty && streamE.isEmpty) }

    var body: some View {
        ZStack {
            AtmosphereBackdrop(section: .intake)
            ScrollView {
                ApolloReadingWidth(maxWidth: 820) {
                    VStack(alignment: .leading, spacing: 18) {
                        // Subject identifier card
                        GlassCard(cornerRadius: 20, padding: 22) {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack(spacing: 10) {
                                    Image(systemName: "person.crop.circle.badge.plus")
                                        .font(.system(size: 16))
                                        .foregroundStyle(Apollo.amber)
                                        .padding(8)
                                        .background(Circle().fill(Apollo.amber.opacity(0.12)))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Subject Identifier")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(palette.title)
                                        Text("Name or codename for this subject")
                                            .font(.system(size: 12))
                                            .foregroundStyle(palette.muted)
                                    }
                                }
                                TextField("Subject name...", text: $name)
                                    .textFieldStyle(.plain)
                                    .padding(12)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(palette.chipBg))
                            }
                        }

                        // Streams card
                        GlassCard(cornerRadius: 20, padding: 22) {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Data Streams")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(palette.title)
                                EvidenceStreamUploader(stream: .text, files: $streamA)
                                EvidenceStreamUploader(stream: .audio, files: $streamB)
                                EvidenceStreamUploader(stream: .video, files: $streamC)
                                EvidenceStreamUploader(stream: .behavioral, files: $streamD)
                                EvidenceStreamUploader(stream: .analog, files: $streamE)
                            }
                        }

                        HStack {
                            Button {
                                save(status: .intake)
                                dismiss()
                            } label: {
                                Label("Save Draft", systemImage: "tray.and.arrow.down")
                            }
                            .buttonStyle(ApolloSecondaryButtonStyle())
                            .disabled(name.isEmpty)
                            .opacity(name.isEmpty ? 0.5 : 1)

                            Spacer()

                            Button {
                                save(status: .processing)
                                Haptics.success()
                                dismiss()
                            } label: {
                                Label("Begin Processing", systemImage: "arrow.right")
                            }
                            .buttonStyle(ApolloPrimaryButtonStyle())
                            .disabled(name.isEmpty || !hasData)
                            .opacity((name.isEmpty || !hasData) ? 0.5 : 1)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 80)
                }
            }
        }
        .navigationTitle(subject.name.isEmpty ? "New Subject" : "Edit: \(subject.name)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            name = subject.name
            streamA = subject.streamAText
            streamB = subject.streamBAudio
            streamC = subject.streamCVideo
            streamD = subject.streamDBehavioral
            streamE = subject.streamEAnalog
        }
    }

    private func save(status: SubjectStatus) {
        subject.name = name
        subject.streamAText = streamA
        subject.streamBAudio = streamB
        subject.streamCVideo = streamC
        subject.streamDBehavioral = streamD
        subject.streamEAnalog = streamE
        subject.status = status
        subject.updatedAt = Date()
        try? context.save()
    }
}
