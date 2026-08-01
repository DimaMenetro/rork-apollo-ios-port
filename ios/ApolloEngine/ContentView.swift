//
//  ContentView.swift
//  ApolloEngine
//
//  Top-level navigation. Adaptive: tab bar on iPhone, sidebar/split on iPad.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("apollo.signedIn") private var signedIn: Bool = false
    @AppStorage("apollo.preferredScheme") private var schemeRaw: String = "system"
    @Environment(AuthManager.self) private var auth

    var body: some View {
        Group {
            if auth.isLoading {
                ZStack {
                    AtmosphereBackdrop(section: .esoteric)
                    ProgressView().controlSize(.large)
                }
            } else if signedIn || auth.user != nil {
                MainAppView()
            } else {
                WelcomeView()
            }
        }
        .preferredColorScheme(preferredScheme)
        .apolloPalette()
    }

    private var preferredScheme: ColorScheme? {
        switch schemeRaw {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}

private struct MainAppView: View {
    @Environment(\.horizontalSizeClass) private var hSize
    @State private var selectedTab: AppTab = .dashboard

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Dashboard", systemImage: "rectangle.grid.2x2", value: AppTab.dashboard) {
                NavigationStack {
                    DashboardView()
                        .apolloRoutes()
                }
            }
            Tab("Reports", systemImage: "doc.text.magnifyingglass", value: AppTab.reports) {
                NavigationStack {
                    ReportsView()
                        .apolloRoutes()
                }
            }
            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}

// MARK: - Centralized navigation destinations

private struct ApolloRoutesModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .navigationDestination(for: NavRoute.self) { route in
                switch route {
                case .subject(let id):    SubjectResolver(id: id) { SubjectDetailView(subject: $0) }
                case .intake(let id):     SubjectResolver(id: id) { SubjectIntakeView(subject: $0) }
                case .processing(let id): SubjectResolver(id: id) { ProcessingView(subject: $0) }
                case .review(let id):     SubjectResolver(id: id) { SubjectReviewView(subject: $0) }
                case .dspReport(let id):  SubjectResolver(id: id) { DSPReportView(subject: $0) }
                case .esoteric(let id):   SubjectResolver(id: id) { EsotericProfileView(subject: $0) }
                case .unified(let id):    SubjectResolver(id: id) { UnifiedDossierView(subject: $0) }
                }
            }
    }
}

extension View {
    func apolloRoutes() -> some View { modifier(ApolloRoutesModifier()) }
}

/// Resolves a Subject by id from SwiftData. Shows a clean fallback if missing.
private struct SubjectResolver<Content: View>: View {
    let id: String
    @ViewBuilder var content: (Subject) -> Content
    @Query private var subjects: [Subject]
    @Environment(\.apollo) private var palette

    init(id: String, @ViewBuilder content: @escaping (Subject) -> Content) {
        self.id = id
        self.content = content
        _subjects = Query(filter: #Predicate<Subject> { $0.id == id })
    }

    var body: some View {
        if let subject = subjects.first {
            content(subject)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "questionmark.folder").font(.system(size: 36)).foregroundStyle(palette.muted)
                Text("Subject not found").font(.system(size: 14)).foregroundStyle(palette.muted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AtmosphereBackdrop(section: .dashboard))
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Subject.self, inMemory: true)
}
