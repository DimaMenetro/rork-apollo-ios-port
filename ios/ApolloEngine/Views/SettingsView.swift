//
//  SettingsView.swift
//  ApolloEngine
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.apollo) private var palette
    @AppStorage("apollo.preferredScheme") private var schemeRaw: String = "system"
    @AppStorage("apollo.pdfTheme") private var pdfTheme: String = "dark"

    var body: some View {
        ZStack {
            AtmosphereBackdrop(section: .settings)
            ScrollView {
                ApolloReadingWidth(maxWidth: 720) {
                    VStack(alignment: .leading, spacing: 16) {
                        GlassCard(cornerRadius: 18, padding: 18) {
                            VStack(alignment: .leading, spacing: 14) {
                                SectionHeader(icon: "paintbrush", title: "Appearance", accent: Apollo.amber)
                                Picker("Theme", selection: $schemeRaw) {
                                    Text("System").tag("system")
                                    Text("Light").tag("light")
                                    Text("Dark").tag("dark")
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                        GlassCard(cornerRadius: 18, padding: 18) {
                            VStack(alignment: .leading, spacing: 14) {
                                SectionHeader(icon: "doc.richtext", title: "PDF Export Theme", accent: Apollo.emerald)
                                Picker("PDF theme", selection: $pdfTheme) {
                                    Text("Dark").tag("dark")
                                    Text("Light").tag("light")
                                }
                                .pickerStyle(.segmented)
                                Text("Generated PDFs match the web app exactly — same cover, same gauges, same footer.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(palette.muted)
                            }
                        }
                        GlassCard(cornerRadius: 18, padding: 18) {
                            VStack(alignment: .leading, spacing: 8) {
                                SectionHeader(icon: "shield.lefthalf.filled", title: "Backend", accent: Apollo.cyan)
                                Text("Worker URL").font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundStyle(palette.label)
                                Text(ApolloConfig.workerURL ?? "Not configured").font(.apolloMono).foregroundStyle(palette.text).lineLimit(1).truncationMode(.middle)
                                Text("LLM models, prompts, and PDF layout are preserved bit-for-bit on the Worker — zero regression from the Base44 functions.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(palette.muted)
                            }
                        }
                        GlassCard(cornerRadius: 18, padding: 18) {
                            VStack(alignment: .leading, spacing: 6) {
                                SectionHeader(icon: "info.circle", title: "About", accent: Apollo.slate)
                                Text("Apollo Profiling Engine").font(.system(size: 14, weight: .semibold)).foregroundStyle(palette.title)
                                Text("Native iOS — IP-001-G-D-APL").font(.apolloMono).foregroundStyle(palette.muted)
                                Text("Version 1.0.0").font(.system(size: 11)).foregroundStyle(palette.muted)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .padding(.bottom, 80)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
    }
}
