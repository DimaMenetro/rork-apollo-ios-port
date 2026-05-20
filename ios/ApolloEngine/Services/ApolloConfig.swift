//
//  ApolloConfig.swift
//  ApolloEngine
//
//  Runtime configuration for the Apollo Worker (the only server-side piece).
//  Replace `workerURL` with your deployed Worker URL — see `worker/README.md`.
//

import Foundation

@MainActor
enum ApolloConfig {
    /// Apollo backend Worker URL. The Worker hosts the four ported Base44 functions
    /// (generateEsotericProfile, synthesizeDossier, analyzeAudio, exportDSP) plus
    /// presigned R2 uploads and a generic InvokeLLM endpoint via the Rork AI proxy.
    static var workerURL: String? = "https://apollo-engine.workers.dev"

    /// Optional shared secret sent as `X-Apollo-Secret` to the Worker.
    static var workerSecret: String? = nil

    /// Maximum file size accepted for inline base64 transit. Larger files use presigned uploads.
    static let inlineUploadCutoff: Int = 4 * 1024 * 1024 // 4 MB
}
