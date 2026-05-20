//
//  ConfidenceArc.swift
//  ApolloEngine
//
//  Circular confidence gauge — color-coded amber/emerald/rose, animates on appear.
//

import SwiftUI

struct ConfidenceArc: View {
    let score: Int
    var diameter: CGFloat = 130
    var lineWidth: CGFloat = 8
    var label: String = "Confidence"

    @Environment(\.apollo) private var palette
    @State private var animatedScore: Double = 0

    private var color: Color { Apollo.confidenceColor(score) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(palette.cardStroke, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(animatedScore / 100.0))
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.6), radius: 10)
            VStack(spacing: 2) {
                Text("\(Int(animatedScore))%")
                    .font(.system(size: diameter * 0.28, weight: .light))
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(palette.muted)
            }
        }
        .frame(width: diameter, height: diameter)
        .onAppear {
            animatedScore = 0
            withAnimation(.spring(response: 1.0, dampingFraction: 0.85)) {
                animatedScore = Double(score)
            }
        }
        .onChange(of: score) { _, newValue in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
                animatedScore = Double(newValue)
            }
        }
    }
}
