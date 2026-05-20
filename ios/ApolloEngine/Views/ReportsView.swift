//
//  ReportsView.swift
//  ApolloEngine
//

import SwiftUI
import SwiftData
import UIKit

struct ReportsView: View {
    @Query(sort: \Subject.updatedAt, order: .reverse) private var subjects: [Subject]
    @Environment(\.apollo) private var palette
    @AppStorage("apollo.pdfTheme") private var pdfTheme: String = "dark"
    @State private var tab: ReportTab = .dsp
    @State private var search: String = ""
    @State private var statusFilter: SubjectStatus? = nil
    @State private var exportingSubjectId: String? = nil
    @State private var exportMode: ExportMode = .dsp
    @State private var sharePayload: SharePayload? = nil
    @State private var exportError: String? = nil

    enum ReportTab: String, CaseIterable, Identifiable {
        case dsp = "DSP Reports"
        case esp = "CP-012 Profiles"
        var id: String { rawValue }
    }

    enum ExportMode: String, CaseIterable, Identifiable {
        case dsp = "DSP"
        case esoteric = "Esoteric"
        case merged = "Merged"
        var id: String { rawValue }
        var apiValue: String {
            switch self {
            case .dsp: return "dsp"
            case .esoteric: return "esoteric"
            case .merged: return "merged"
            }
        }
    }

    struct SharePayload: Identifiable {
        let id = UUID()
        let url: URL
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
                        exportCenter
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
        .sheet(item: $sharePayload) { payload in
            ShareSheet(items: [payload.url])
                .presentationDetents([.medium, .large])
        }
        .alert("Export failed", isPresented: Binding(get: { exportError != nil }, set: { _ in exportError = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
    }

    // MARK: - Export center

    private var exportCenter: some View {
        GlassCard(cornerRadius: 20, padding: 18, tint: Apollo.emerald) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(icon: "square.and.arrow.up.on.square", title: "Export Center", accent: Apollo.emerald)

                VStack(alignment: .leading, spacing: 6) {
                    Text("MODE").font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundStyle(palette.label)
                    Picker("Mode", selection: $exportMode) {
                        ForEach(ExportMode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("PDF THEME").font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundStyle(palette.label)
                    Picker("Theme", selection: $pdfTheme) {
                        Text("Dark").tag("dark")
                        Text("Light").tag("light")
                    }
                    .pickerStyle(.segmented)
                }

                Text("Pick a subject below to render its PDF — same cover, gauges, and footer as the web export.")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.muted)
            }
        }
    }

    private func exportButton(for s: Subject) -> some View {
        Button {
            Task { await exportPDF(subject: s) }
        } label: {
            if exportingSubjectId == s.id {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Apollo.emerald)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Apollo.emerald.opacity(0.14)))
            }
        }
        .buttonStyle(.plain)
        .disabled(exportingSubjectId != nil)
        .accessibilityLabel("Export \(s.name) as PDF")
    }

    @MainActor
    private func exportPDF(subject s: Subject) async {
        exportingSubjectId = s.id
        defer { exportingSubjectId = nil }
        do {
            let payload: [String: Any] = [
                "name": s.name,
                "dsp": (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(s.dsp))) ?? [:],
                "esoteric_profile": (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(s.esotericProfile ?? EsotericProfile()))) ?? [:],
                "conflicts_detected": (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(s.conflicts))) ?? [],
            ]
            let data = try await APIClient.shared.exportPDF(
                subjectId: s.id,
                mode: exportMode.apiValue,
                colorTheme: pdfTheme,
                payload: payload
            )
            let filename = "\(s.name.replacingOccurrences(of: " ", with: "_"))_\(exportMode.apiValue).pdf"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: url, options: .atomic)
            sharePayload = SharePayload(url: url)
            Haptics.success()
        } catch {
            exportError = error.localizedDescription
            Haptics.error()
        }
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
            exportButton(for: s)
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
            exportButton(for: s)
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
