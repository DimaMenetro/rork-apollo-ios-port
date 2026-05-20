//
//  APIClient.swift
//  ApolloEngine
//
//  Talks to the Apollo backend Worker, which preserves the four Base44 functions
//  bit-for-bit: generateEsotericProfile, synthesizeDossier, analyzeAudio, exportDSP.
//
//  All prompts, model selections, and call sequencing live server-side so the
//  iOS app receives identical outputs to the web app.
//

import Foundation

nonisolated struct APIError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Endpoints exposed by the Apollo Worker.
nonisolated enum APIEndpoint: String {
    case generateEsoteric  = "/api/generateEsotericProfile"
    case synthesizeDossier = "/api/synthesizeDossier"
    case analyzeAudio      = "/api/analyzeAudio"
    case invokeLLM         = "/api/invokeLLM"
    case exportPDF         = "/api/exportDSP"
    case presignUpload     = "/api/presignUpload"
}

@MainActor
final class APIClient {
    static let shared = APIClient()

    /// Base URL for the Apollo Worker. Configure in `ApolloConfig.swift`.
    private var baseURL: URL? {
        guard let s = ApolloConfig.workerURL, let u = URL(string: s) else { return nil }
        return u
    }

    // MARK: - Generic POST

    private func post<Response: Decodable>(
        _ endpoint: APIEndpoint,
        body: [String: Any]
    ) async throws -> Response {
        guard let baseURL else {
            throw APIError(message: "Worker URL not configured. Set workerURL in ApolloConfig.swift.")
        }
        var req = URLRequest(url: baseURL.appendingPathComponent(endpoint.rawValue))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            // Try to extract worker error message
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = json["error"] as? String {
                throw APIError(message: msg)
            }
            throw APIError(message: "Server returned \(((response as? HTTPURLResponse)?.statusCode).map(String.init) ?? "unknown")")
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }

    // MARK: - Esoteric profile (CP-012)

    struct EsotericResponse: Decodable {
        let esoteric_profile: EsotericProfile
    }

    func generateEsoteric(subjectId: String, inputs: EsotericInputs, dspSummary: String) async throws -> EsotericProfile {
        let body: [String: Any] = [
            "subject_id": subjectId,
            "esoteric_inputs": [
                "full_birth_name": inputs.full_birth_name,
                "date_of_birth": inputs.date_of_birth,
                "place_of_birth": inputs.place_of_birth,
                "time_of_birth": inputs.time_of_birth,
                "mode": inputs.mode,
                "timeframe": inputs.timeframe,
                "focus": inputs.focus,
            ],
            "dsp_summary": dspSummary,
        ]
        let resp: EsotericResponse = try await post(.generateEsoteric, body: body)
        return resp.esoteric_profile
    }

    // MARK: - Synthesize unified dossier

    struct DossierResponse: Decodable {
        let unified_dossier: UnifiedDossier
    }

    func synthesizeDossier(subjectId: String, dsp: DSP, esp: EsotericProfile) async throws -> UnifiedDossier {
        let body: [String: Any] = [
            "subject_id": subjectId,
            "dsp": try jsonObject(dsp),
            "esoteric_profile": try jsonObject(esp),
            "subject_name": "" // worker reads name from DSP context
        ]
        let resp: DossierResponse = try await post(.synthesizeDossier, body: body)
        return resp.unified_dossier
    }

    // MARK: - Media analysis (Hume multi-modal + AssemblyAI)
    //
    // Audio files run Hume prosody + language + burst alongside AssemblyAI
    // universal-3-pro transcription. Video files additionally run Hume face
    // (FACS) for facial expression / body language signal. Both modalities are
    // routed through the same /api/analyzeAudio endpoint with a `media_type`
    // hint so the worker selects the correct Hume model bundle.

    enum MediaKind: String { case audio, video }

    struct MediaAnalysisResponse: Decodable {
        let media_type: String?
        let predictions: AnyCodable?
        let transcript: String?
        let hume_error: String?
        let transcript_error: String?
    }

    /// Back-compat alias used by older call-sites.
    typealias AudioAnalysisResponse = MediaAnalysisResponse

    func analyzeMedia(fileURL: String, kind: MediaKind) async throws -> MediaAnalysisResponse {
        let body: [String: Any] = [
            "file_url": fileURL,
            "media_type": kind.rawValue,
        ]
        return try await post(.analyzeAudio, body: body)
    }

    func analyzeAudio(fileURL: String) async throws -> MediaAnalysisResponse {
        try await analyzeMedia(fileURL: fileURL, kind: .audio)
    }

    // MARK: - LLM invocation (generic, used by Processing & Review)

    struct LLMResponse: Decodable {
        let response: AnyCodable
    }

    func invokeLLM(prompt: String, schema: [String: Any], fileURLs: [String] = []) async throws -> [String: Any] {
        let body: [String: Any] = [
            "prompt": prompt,
            "response_json_schema": ["type": "object", "properties": schema],
            "file_urls": fileURLs,
        ]
        guard let baseURL else {
            throw APIError(message: "Worker URL not configured.")
        }
        var req = URLRequest(url: baseURL.appendingPathComponent(APIEndpoint.invokeLLM.rawValue))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError(message: "LLM call failed")
        }
        let obj = try JSONSerialization.jsonObject(with: data)
        if let dict = obj as? [String: Any], let inner = dict["response"] as? [String: Any] {
            return inner
        }
        return (obj as? [String: Any]) ?? [:]
    }

    // MARK: - Presigned upload (R2)

    struct PresignedURL: Decodable {
        let uploadURL: String
        let publicURL: String
    }

    func presignUpload(filename: String, contentType: String) async throws -> PresignedURL {
        let body: [String: Any] = ["filename": filename, "content_type": contentType]
        return try await post(.presignUpload, body: body)
    }

    func uploadFile(_ data: Data, to presigned: PresignedURL, contentType: String) async throws {
        guard let url = URL(string: presigned.uploadURL) else {
            throw APIError(message: "Invalid upload URL")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue(contentType, forHTTPHeaderField: "Content-Type")
        let (_, response) = try await URLSession.shared.upload(for: req, from: data)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError(message: "Upload failed")
        }
    }

    // MARK: - PDF export

    func exportPDF(subjectId: String, mode: String, colorTheme: String, payload: [String: Any]) async throws -> Data {
        guard let baseURL else {
            throw APIError(message: "Worker URL not configured.")
        }
        let body: [String: Any] = [
            "subject_id": subjectId,
            "mode": mode,
            "color_theme": colorTheme,
            "payload": payload,
        ]
        var req = URLRequest(url: baseURL.appendingPathComponent(APIEndpoint.exportPDF.rawValue))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError(message: "PDF export failed")
        }
        return data
    }
}

// MARK: - JSON helpers

nonisolated private func jsonObject<T: Encodable>(_ value: T) throws -> Any {
    let data = try JSONEncoder().encode(value)
    return try JSONSerialization.jsonObject(with: data, options: [])
}

/// Type-erased Codable value for free-form LLM responses.
nonisolated struct AnyCodable: Codable, Hashable {
    let value: AnyCodableValue

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(String.self) { value = .string(v) }
        else if let v = try? c.decode(Int.self) { value = .int(v) }
        else if let v = try? c.decode(Double.self) { value = .double(v) }
        else if let v = try? c.decode(Bool.self) { value = .bool(v) }
        else if let v = try? c.decode([AnyCodable].self) { value = .array(v) }
        else if let v = try? c.decode([String: AnyCodable].self) { value = .object(v) }
        else { value = .null }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case .string(let v): try c.encode(v)
        case .int(let v): try c.encode(v)
        case .double(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }
}

nonisolated enum AnyCodableValue: Hashable {
    case string(String), int(Int), double(Double), bool(Bool)
    case array([AnyCodable]), object([String: AnyCodable]), null
}
