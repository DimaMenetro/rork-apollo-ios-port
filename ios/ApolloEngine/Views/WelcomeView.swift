//
//  WelcomeView.swift
//  ApolloEngine
//
//  First-launch Liquid Glass welcome. Sign in with Apple + Google through Rork Auth.
//  The signed-in user becomes the CloudKit identity owner.
//

import SwiftUI
import AuthenticationServices

struct WelcomeView: View {
    @AppStorage("apollo.operatorName") private var operatorName: String = ""
    @AppStorage("apollo.signedIn") private var signedIn: Bool = false
    @Environment(\.apollo) private var palette
    @Environment(AuthManager.self) private var auth
    @State private var orbAnimating = false

    var body: some View {
        @Bindable var auth = auth

        ZStack {
            AtmosphereBackdrop(section: .esoteric)
            VStack(spacing: 24) {
                Spacer()
                monogram

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

                authButtons
                    .padding(.horizontal, 28)
                    .padding(.bottom, 40)
            }
        }
        .onAppear { orbAnimating = true }
        .alert("Sign-in error", isPresented: $auth.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(auth.errorMessage)
        }
        .onChange(of: auth.user?.id) { _, _ in
            if let user = auth.user {
                operatorName = user.name ?? user.email
                withAnimation(.spring()) { signedIn = true }
                Haptics.success()
            }
        }
    }

    // MARK: - Sub-views

    private var monogram: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Apollo.amber.opacity(0.5), .clear],
                                     center: .center, startRadius: 0, endRadius: 120))
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
    }

    @ViewBuilder
    private var authButtons: some View {
        VStack(spacing: 12) {
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                handleAppleResult(result)
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 50)
            .clipShape(.rect(cornerRadius: 14))
            .disabled(auth.isSigningIn)

            Button {
                Task { await auth.signIn(provider: "google") }
            } label: {
                HStack {
                    if auth.isSigningIn {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "g.circle.fill").font(.system(size: 18))
                    }
                    Text("Continue with Google").font(.system(size: 15, weight: .medium))
                }
                .frame(maxWidth: .infinity, minHeight: 50)
                .foregroundStyle(.white)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.65)))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.15)))
            }
            .buttonStyle(.plain)
            .disabled(auth.isSigningIn)

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
    }

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            // Capture the local Apple name immediately for offline use.
            if let credential = auth.credential as? ASAuthorizationAppleIDCredential {
                let given = credential.fullName?.givenName ?? ""
                let family = credential.fullName?.familyName ?? ""
                let local = [given, family].filter { !$0.isEmpty }.joined(separator: " ")
                if !local.isEmpty { operatorName = local }
            }
            // Then exchange with Rork Auth (if configured) for the CloudKit-bound identity.
            Task { await self.auth.signIn(provider: "apple") }
        case .failure:
            Haptics.error()
        }
    }
}
