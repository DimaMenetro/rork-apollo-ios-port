//
//  AuthManager.swift
//  ApolloEngine
//
//  Rork Auth — Sign in with Apple + Google via ASWebAuthenticationSession.
//  Tokens are stored in the Keychain. The operator's identity becomes the
//  CloudKit private-database owner so all DSPs sync across their devices.
//

import SwiftUI
import AuthenticationServices
import CryptoKit
import UIKit

@MainActor
@Observable
final class AuthManager {
    var user: User?
    var isLoading = true
    var isSigningIn = false
    var showError = false
    var errorMessage = ""

    private let authURL = Config.EXPO_PUBLIC_RORK_AUTH_URL
    /// Rork Auth client key. Resolved through the dynamic `Config.allValues` table
    /// so the build still succeeds before the env var has been provisioned via
    /// `getOrCreateAuthConfig`. When empty, the UI falls back to the offline
    /// operator path.
    private let appKey = Config.allValues["EXPO_PUBLIC_RORK_APP_KEY"] ?? ""
    private let projectID = Config.EXPO_PUBLIC_PROJECT_ID
    private var codeVerifier: String?
    private var webAuthSession: ASWebAuthenticationSession?

    /// Read at every access so Rork's simctl injection can land after launch.
    private var developerHint: String? {
        UserDefaults.standard.string(forKey: "RORK_DEVELOPER_HINT")
    }

    /// True if a Rork Auth client key is configured. When false the UI shows
    /// the offline operator option but skips OAuth.
    var isConfigured: Bool { !appKey.isEmpty && !authURL.isEmpty }

    struct User: Codable {
        let id: String
        let email: String
        let name: String?
        let picture: String?
    }

    init() {
        Task { await checkAuth() }
    }

    // MARK: - PKCE helpers

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private var authEnv: String {
        #if targetEnvironment(simulator)
        return "simulator"
        #else
        return "native"
        #endif
    }

    private func userFromToken(_ token: String) -> User? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }
        guard let data = Data(base64Encoded: base64) else { return nil }

        struct JWTPayload: Codable {
            let sub: String
            let email: String?
            let name: String?
            let picture: String?
            let exp: TimeInterval?
        }
        guard let payload = try? JSONDecoder().decode(JWTPayload.self, from: data) else { return nil }
        if let exp = payload.exp, Date(timeIntervalSince1970: exp) < Date() { return nil }
        return User(id: payload.sub, email: payload.email ?? "", name: payload.name, picture: payload.picture)
    }

    private func getRefreshToken() -> String? {
        #if targetEnvironment(simulator)
        if let ud = UserDefaults.standard.string(forKey: "RORK_AUTH_REFRESH_TOKEN") { return ud }
        #endif
        return KeychainHelper.get("refresh_token")
    }

    // MARK: - Auth flow

    func checkAuth() async {
        defer { isLoading = false }
        if let accessToken = KeychainHelper.get("access_token"),
           let user = userFromToken(accessToken) {
            self.user = user
            return
        }
        if getRefreshToken() != nil {
            await refreshToken()
        }
    }

    func signIn(provider: String) async {
        guard isConfigured else {
            setError("Rork Auth is not configured for this build. Provision an app key to enable Google / Apple sign-in.")
            return
        }
        isSigningIn = true
        defer { isSigningIn = false }
        do {
            let verifier = generateCodeVerifier()
            let challenge = generateCodeChallenge(from: verifier)
            codeVerifier = verifier

            guard let url = URL(string: "\(authURL)/oauth/initiate") else {
                setError("Invalid auth URL"); return
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            var body: [String: String] = [
                "app_key": appKey,
                "provider": provider,
                "code_challenge": challenge,
                "target": "swift",
                "env": authEnv,
            ]
            if authEnv == "simulator", let hint = developerHint { body["developer_hint"] = hint }
            request.httpBody = try JSONEncoder().encode(body)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                if let err = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    setError(err.error)
                } else {
                    setError("Sign in failed (\(code))")
                }
                return
            }
            let initiate = try JSONDecoder().decode(InitiateResponse.self, from: data)

            let authCode: String
            if initiate.flow == "popup" {
                do { authCode = try await pollForCode(state: initiate.state) }
                catch AuthError.cancelledByUser {
                    authCode = try await runWebAuthSession(authURL: initiate.auth_url)
                }
            } else {
                authCode = try await runWebAuthSession(authURL: initiate.auth_url)
            }
            await exchangeCode(authCode)
        } catch let err as ASWebAuthenticationSessionError where err.code == .canceledLogin {
            return
        } catch {
            setError(error.localizedDescription)
        }
    }

    private func pollForCode(state: String) async throws -> String {
        guard let url = URL(string: "\(authURL)/oauth/poll-code") else { throw AuthError.invalidURL }
        let deadline = Date().addingTimeInterval(5 * 60)
        while Date() < deadline {
            try await Task.sleep(for: .milliseconds(1500))
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(["app_key": appKey, "state": state])
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { continue }
            guard let poll = try? JSONDecoder().decode(PollCodeResponse.self, from: data) else { continue }
            if poll.status == "cancelled" { throw AuthError.cancelledByUser }
            if poll.status == "ready", let code = poll.code { return code }
        }
        throw AuthError.popupTimeout
    }

    private func runWebAuthSession(authURL urlString: String) async throws -> String {
        let scheme = "rork-\(projectID)"
        return try await withCheckedThrowingContinuation { continuation in
            guard let url = URL(string: urlString) else {
                continuation.resume(throwing: AuthError.invalidURL); return
            }
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { [weak self] callback, err in
                self?.webAuthSession = nil
                if let err { continuation.resume(throwing: err); return }
                guard let cb = callback,
                      let comps = URLComponents(url: cb, resolvingAgainstBaseURL: false),
                      let code = comps.queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(throwing: AuthError.noCode); return
                }
                continuation.resume(returning: code)
            }
            self.webAuthSession = session
            session.presentationContextProvider = WebAuthPresentationContext.shared
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }

    private func exchangeCode(_ code: String) async {
        guard let verifier = codeVerifier else { return }
        codeVerifier = nil
        guard let url = URL(string: "\(authURL)/oauth/token") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode([
            "app_key": appKey,
            "code": code,
            "code_verifier": verifier,
        ])
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                if let err = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    setError(err.error)
                } else { setError("Sign in failed (\(code))") }
                return
            }
            let token = try JSONDecoder().decode(TokenResponse.self, from: data)
            KeychainHelper.set("access_token", value: token.access_token)
            KeychainHelper.set("refresh_token", value: token.refresh_token)
            user = token.user
            Haptics.success()
        } catch {
            setError("Sign in failed: \(error.localizedDescription)")
        }
    }

    private func refreshToken() async {
        guard let stored = getRefreshToken(), let url = URL(string: "\(authURL)/oauth/refresh") else {
            user = nil; return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(["app_key": appKey, "refresh_token": stored])
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { await signOut(); return }
            let refresh = try JSONDecoder().decode(RefreshResponse.self, from: data)
            KeychainHelper.set("access_token", value: refresh.access_token)
            user = userFromToken(refresh.access_token)
        } catch {
            await signOut()
        }
    }

    func signOut() async {
        KeychainHelper.delete("access_token")
        KeychainHelper.delete("refresh_token")
        UserDefaults.standard.removeObject(forKey: "RORK_AUTH_REFRESH_TOKEN")
        user = nil
    }

    private func setError(_ message: String) {
        errorMessage = message
        showError = true
        Haptics.error()
    }
}

// MARK: - Response types

nonisolated private struct InitiateResponse: Codable {
    let auth_url: String
    let state: String
    let flow: String?
}

nonisolated private struct PollCodeResponse: Codable {
    let status: String
    let code: String?
}

nonisolated private struct TokenResponse: Codable {
    let access_token: String
    let refresh_token: String
    let user: AuthManager.User
}

nonisolated private struct RefreshResponse: Codable {
    let access_token: String
    let expires_in: Int
}

nonisolated private struct ErrorResponse: Codable {
    let error: String
}

nonisolated enum AuthError: LocalizedError {
    case noCode
    case invalidURL
    case serverError(statusCode: Int)
    case popupTimeout
    case cancelledByUser

    var errorDescription: String? {
        switch self {
        case .noCode: return "No authorization code received"
        case .invalidURL: return "Invalid URL"
        case .serverError(let code): return "Server error (\(code))"
        case .popupTimeout: return "Sign-in timed out — please try again"
        case .cancelledByUser: return "Sign-in cancelled"
        }
    }
}

// MARK: - ASWebAuthenticationSession presentation

final class WebAuthPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = WebAuthPresentationContext()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
