//
//  StatCard.swift
//  ApolloEngine
//

import SwiftUI

struct StatCard: View {
    let title: String
    let value: Int
    let icon: String
    let color: Color
    @Environment(\.apollo) private var palette
    @State private var animated: Double = 0

    var body: some View {
        GlassCard(cornerRadius: 18, padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(color)
                        .padding(8)
                        .background(Circle().fill(color.opacity(0.14)))
                    Spacer()
                }
                Text("\(Int(animated))")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(palette.title)
                    .contentTransition(.numericText())
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(palette.muted)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.85)) {
                animated = Double(value)
            }
        }
        .onChange(of: value) { _, newValue in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                animated = Double(newValue)
            }
        }
    }
}
