//
//  ReportsView.swift
//  ApolloEngine
//

import SwiftUI
import SwiftData

struct ReportsView: View {
    @Query(sort: \Subject.updatedAt, order: .reverse) private var subjects: [Subject]
    @Environment(\.apollo) private var palette
    @State private var tab: ReportTab = .dsp
    @State private var search: String = ""
    @State private var statusFilter: SubjectStatus? = nil

    enum ReportTab: String, CaseIterable, Identifiable {
        case dsp = "DSP Reports"
        case esp = "CP-012 Profiles"
        var id: String { rawValue }
    }

    private var esotericSubjects: [Subject] { subjects.filter { $0.esotericProfile != nil } }

    private var filteredDSP: [Subject] {
        subjects.filter { s in
            (search.isEmpty || s.name.localizedStandardContains(search))
            && (statusFilter == nil || s.status == statusFilter)
        }
    }

    private var filteredESP: [Subject] {
        esotericSubjects.filter { search.isEmpty || $0.name.localizedStandardContains(search) }
    }

    var body: some View {
        ZStack {
            AtmosphereBackdrop(section: .reports)
            ScrollView {
                ApolloReadingWidth(maxWidth: 1080) {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        tabBar
                        if tab == .dsp { dspTable } else { espTable }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .padding(.bottom, 80)
                }
            }
        }
        .navigationTitle("Reports")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $search, prompt: "Search subjects")
    }

    private var header: some View {
        Text("\(subjects.count) subject\(subjects.count == 1 ? "" : "s") · \(esotericSubjects.count) CP-012 profile\(esotericSubjects.count == 1 ? "" : "s")")
            .font(.system(size: 13))
            .foregroundStyle(palette.muted)
    }

    private var tabBar: some View {
        HStack(spacing: 8) {
            ForEach(ReportTab.allCases) { t in
                Button {
                    Haptics.selection()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { tab = t }
                } label: {
                    Text(t.rawValue)
                        .font(.system(size: 13, weight: tab == t ? .semibold : .regular))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .foregroundStyle(tab == t ? Apollo.emerald : palette.muted)
                        .background(
                            Capsule().fill(tab == t ? Apollo.emerald.opacity(0.14) : palette.chipBg)
                        )
                        .overlay(
                            Capsule().strokeBorder(tab == t ? Apollo.emerald.opacity(0.30) : palette.cardStroke)
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private var dspTable: some View {
        GlassCard(cornerRadius: 20, padding: 0) {
            VStack(spacing: 0) {
                ForEach(Array(filteredDSP.enumerated()), id: \.element.id) { _, s in
                    NavigationLink(value: NavRoute.subject(s.id)) {
                        rowDSP(s)
                    }
                    .buttonStyle(.plain)
                    Divider().background(palette.divider)
                }
                if filteredDSP.isEmpty {
                    EmptyStateView(icon: "magnifyingglass", title: "No subjects found",
                                   message: search.isEmpty ? "Create a subject to see it here." : "Try a different search.")
                }
            }
        }
    }

    private var espTable: some View {
        GlassCard(cornerRadius: 20, padding: 0) {
            VStack(spacing: 0) {
                ForEach(Array(filteredESP.enumerated()), id: \.element.id) { _, s in
                    NavigationLink(value: NavRoute.esoteric(s.id)) {
                        rowESP(s)
                    }
                    .buttonStyle(.plain)
                    Divider().background(palette.divider)
                }
                if filteredESP.isEmpty {
                    EmptyStateView(icon: "sparkles", title: "No CP-012 profiles yet",
                                   message: "Open any subject and run the Esoteric Profile.", accent: Apollo.violet)
                }
            }
        }
    }

    private func rowDSP(_ s: Subject) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(s.name).font(.system(size: 14, weight: .medium)).foregroundStyle(palette.title)
                Text("DSP-\(s.id.suffix(8).uppercased())").font(.apolloMono).foregroundStyle(palette.muted)
            }
            Spacer()
            StatusPill(s.status.label, color: pillColor(for: s.status))
            if s.hasDSP {
                Text("\(s.dsp.confidence_score)%")
                    .font(.apolloMono)
                    .foregroundStyle(Apollo.confidenceColor(s.dsp.confidence_score))
            }
            Image(systemName: "chevron.right").foregroundStyle(palette.muted).font(.system(size: 12))
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
    }

    private func rowESP(_ s: Subject) -> some View {
        let ep = s.esotericProfile!
        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(s.name).font(.system(size: 14, weight: .medium)).foregroundStyle(palette.title)
                Text("CP-012-O-D-ESP").font(.apolloMono).foregroundStyle(palette.muted)
            }
            Spacer()
            FidelityMeter(level: ep.input_fidelity)
            Image(systemName: "chevron.right").foregroundStyle(palette.muted).font(.system(size: 12))
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
    }

    private func pillColor(for status: SubjectStatus) -> Color {
        switch status {
        case .intake: return Apollo.slate
        case .processing: return Apollo.amber
        case .review: return Apollo.violet
        case .finalized: return Apollo.emerald
        }
    }
}
