//
//  DashboardView.swift
//  ApolloEngine
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query(sort: \Subject.updatedAt, order: .reverse) private var subjects: [Subject]
    @Environment(\.modelContext) private var context
    @Environment(\.apollo) private var palette
    @State private var newSubjectSheet = false
    @State private var newSubjectName = ""

    private var processing: [Subject] { subjects.filter { $0.status == .processing } }
    private var finalized: Int { subjects.filter { $0.status == .finalized }.count }
    private var flagged: Int {
        subjects.filter { !$0.conflicts.isEmpty || $0.dspStatus == .failed || $0.dspStatus == .empty }.count
    }
    private var recent: [Subject] { Array(subjects.prefix(6)) }

    var body: some View {
        ZStack {
            AtmosphereBackdrop(section: .dashboard)
            ScrollView {
                ApolloReadingWidth(maxWidth: 1080) {
                    VStack(alignment: .leading, spacing: 24) {
                        header

                        // Stats grid
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 14)], spacing: 14) {
                            StatCard(title: "Total Subjects", value: subjects.count,
                                     icon: "person.2.fill", color: Apollo.slate)
                            StatCard(title: "In Processing", value: processing.count,
                                     icon: "waveform.path.ecg", color: Apollo.amber)
                            StatCard(title: "Finalized DSPs", value: finalized,
                                     icon: "checkmark.seal.fill", color: Apollo.emerald)
                            StatCard(title: "Conflicts Flagged", value: flagged,
                                     icon: "exclamationmark.triangle.fill", color: Apollo.rose)
                        }

                        if !processing.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 8) {
                                    Circle().fill(Apollo.amber).frame(width: 8, height: 8)
                                        .shadow(color: Apollo.amber.opacity(0.6), radius: 4)
                                    Text("ACTIVE PROCESSING")
                                        .font(.system(size: 11, weight: .semibold))
                                        .tracking(1.4)
                                        .foregroundStyle(palette.label)
                                }
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 14)], spacing: 14) {
                                    ForEach(processing.prefix(3)) { s in
                                        NavigationLink(value: NavRoute.subject(s.id)) {
                                            SubjectCard(subject: s)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("RECENT SUBJECTS")
                                    .font(.system(size: 11, weight: .semibold))
                                    .tracking(1.4)
                                    .foregroundStyle(palette.label)
                                Spacer()
                            }
                            if recent.isEmpty {
                                GlassCard(cornerRadius: 20, padding: 32) {
                                    EmptyStateView(
                                        icon: "person.crop.circle.badge.plus",
                                        title: "No subjects yet",
                                        message: "Create your first subject profile to begin analysis."
                                    )
                                }
                            } else {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 14)], spacing: 14) {
                                    ForEach(recent) { s in
                                        NavigationLink(value: NavRoute.subject(s.id)) {
                                            SubjectCard(subject: s)
                                        }
                                        .buttonStyle(.plain)
                                        .contextMenu {
                                            NavigationLink("Open Review", value: NavRoute.review(s.id))
                                            NavigationLink("DSP Report", value: NavRoute.dspReport(s.id))
                                            NavigationLink("Esoteric Profile", value: NavRoute.esoteric(s.id))
                                            Divider()
                                            Button("Delete", role: .destructive) {
                                                context.delete(s)
                                                Haptics.warning()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 80)
                }
            }
        }
        .navigationTitle("Operations Center")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Haptics.tap()
                    newSubjectSheet = true
                } label: {
                    Label("New Subject", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $newSubjectSheet) {
            NewSubjectSheet(name: $newSubjectName) { name in
                let subject = Subject(name: name)
                context.insert(subject)
                try? context.save()
                Haptics.success()
                newSubjectName = ""
                newSubjectSheet = false
            }
            .presentationDetents([.height(280)])
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Multimodal Profiling & Prediction Engine")
                .font(.system(size: 13))
                .foregroundStyle(palette.muted)
            Text("Operations Center")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(palette.title)
        }
    }
}

private struct NewSubjectSheet: View {
    @Binding var name: String
    let onCreate: (String) -> Void
    @Environment(\.apollo) private var palette
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("New Subject Intake")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(palette.title)
                Text("Subject Identifier")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(palette.label)
                TextField("Enter subject name or codename...", text: $name)
                    .textFieldStyle(.plain)
                    .focused($focused)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(palette.chipBg))
                Spacer()
                HStack {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(ApolloSecondaryButtonStyle())
                    Spacer()
                    Button("Begin Intake") {
                        guard !name.isEmpty else { return }
                        onCreate(name)
                    }
                    .buttonStyle(ApolloPrimaryButtonStyle())
                    .disabled(name.isEmpty)
                    .opacity(name.isEmpty ? 0.5 : 1)
                }
            }
            .padding(24)
        }
        .onAppear { focused = true }
    }
}
