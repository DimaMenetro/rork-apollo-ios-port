//
//  WelcomeView.swift
//  ApolloEngine
//
//  First-launch Liquid Glass welcome screen with Sign in with Apple & Google.
//  Authentication is intentionally light-touch in v1: we capture the operator's
//  identity locally and allow them to proceed offline. CloudKit handles sync
//  when the account is connected.
//

import SwiftUI
import AuthenticationServices

struct WelcomeView: View {
    @AppStorage("apollo.operatorName") private var operatorName: String = ""
    @AppStorage("apollo.signedIn") private var signedIn: Bool = false
    @Environment(\.apollo) private var palette
    @State private var orbAnimating = false

    var body: some View {
        ZStack {
            AtmosphereBackdrop(section: .esoteric)
            VStack(spacing: 24) {
                Spacer()
                // Apollo monogram
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(colors: [Apollo.amber.opacity(0.5), .clear],
                                           center: .center, startRadius: 0, endRadius: 120)
                        )
                        .frame(width: 240, height: 240)
                        .blur(radius: 30)
                        .scaleEffect(orbAnimating ? 1.08 : 0.92)
                        .animation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true), value: orbAnimating)
                    Text("A")
                        .font(.system(size: 110, weight: .ultraLight, design: .serif))
                        .foregroundStyle(
                            LinearGradient(colors: [Apollo.amber, Apollo.violet],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                }
                VStack(spacing: 6) {
                    Text("APOLLO").font(.system(size: 13, weight: .semibold)).tracking(4).foregroundStyle(palette.muted)
                    Text("Profiling Engine")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(palette.title)
                    Text("Multimodal subject profiling. DSP + Esoteric synthesis.")
                        .font(.system(size: 13))
                        .foregroundStyle(palette.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                VStack(spacing: 12) {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        switch result {
                        case .success(let auth):
                            if let credential = auth.credential as? ASAuthorizationAppleIDCredential {
                                let given = credential.fullName?.givenName ?? ""
                                let family = credential.fullName?.familyName ?? ""
                                let name = [given, family].filter { !$0.isEmpty }.joined(separator: " ")
                                operatorName = name.isEmpty ? "Operator" : name
                            }
                            withAnimation(.spring()) { signedIn = true }
                            Haptics.success()
                        case .failure:
                            Haptics.error()
                        }
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .clipShape(.rect(cornerRadius: 14))

                    Button {
                        // Google sign-in via Rork Auth would attach here.
                        operatorName = "Operator"
                        withAnimation(.spring()) { signedIn = true }
                        Haptics.success()
                    } label: {
                        HStack {
                            Image(systemName: "g.circle.fill").font(.system(size: 18))
                            Text("Continue with Google").font(.system(size: 15, weight: .medium))
                        }
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .foregroundStyle(.white)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.65)))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.15)))
                    }
                    .buttonStyle(.plain)

                    Button {
                        operatorName = "Operator"
                        withAnimation(.spring()) { signedIn = true }
                        Haptics.tap()
                    } label: {
                        Text("Continue without account")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(palette.muted)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
        }
        .onAppear { orbAnimating = true }
    }
}
