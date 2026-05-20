//
//  EvidenceStreamUploader.swift
//  ApolloEngine
//
//  Five evidence stream cards. Uses the standard iOS document picker so users
//  can pull files from Voice Memos, Photos (export), Files, iCloud Drive, etc.
//

import SwiftUI
import UniformTypeIdentifiers
import Foundation

enum EvidenceStream: String, CaseIterable, Identifiable {
    case text       // stream_a_text
    case audio      // stream_b_audio
    case video      // stream_c_video
    case behavioral // stream_d_behavioral
    case analog     // stream_e_analog

    var id: String { rawValue }

    var title: String {
        switch self {
        case .text: return "Stream A — Text"
        case .audio: return "Stream B — Audio"
        case .video: return "Stream C — Video"
        case .behavioral: return "Stream D — Behavioral"
        case .analog: return "Stream E — Analog"
        }
    }

    var subtitle: String {
        switch self {
        case .text: return "Logs, emails, transcripts"
        case .audio: return "Voice memos, calls (Hume prosody)"
        case .video: return "Footage (micro-expression analysis)"
        case .behavioral: return "Decision logs, purchase history"
        case .analog: return "Handwriting samples"
        }
    }

    var icon: String {
        switch self {
        case .text: return "doc.text"
        case .audio: return "waveform"
        case .video: return "video"
        case .behavioral: return "chart.line.uptrend.xyaxis"
        case .analog: return "pencil.tip"
        }
    }

    var contentTypes: [UTType] {
        switch self {
        case .text: return [.text, .pdf, .plainText, .commaSeparatedText]
        case .audio: return [.audio, .mp3, .wav, .mpeg4Audio]
        case .video: return [.movie, .video, .mpeg4Movie, .quickTimeMovie]
        case .behavioral: return [.commaSeparatedText, .spreadsheet, .json, .text]
        case .analog: return [.image, .png, .jpeg]
        }
    }

    var mimeType: String {
        switch self {
        case .text: return "application/octet-stream"
        case .audio: return "audio/m4a"
        case .video: return "video/mp4"
        case .behavioral: return "application/octet-stream"
        case .analog: return "image/jpeg"
        }
    }
}

struct EvidenceStreamUploader: View {
    let stream: EvidenceStream
    @Binding var files: [String]
    @State private var pickerOpen = false
    @State private var uploadingCount: Int = 0
    @State private var lastError: String? = nil
    @Environment(\.apollo) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: stream.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Apollo.amber)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Apollo.amber.opacity(0.12)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(stream.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(palette.title)
                    Text(stream.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(palette.muted)
                }
                Spacer()
                if uploadingCount > 0 {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.mini)
                        Text("\(uploadingCount) uploading")
                            .font(.system(size: 11))
                            .foregroundStyle(palette.muted)
                    }
                }
                Text("\(files.count)")
                    .font(.apolloMono)
                    .foregroundStyle(files.isEmpty ? palette.muted : Apollo.emerald)
            }

            if let lastError {
                Text(lastError)
                    .font(.system(size: 11))
                    .foregroundStyle(Apollo.rose)
            }

            if !files.isEmpty {
                VStack(spacing: 4) {
                    ForEach(files, id: \.self) { url in
                        HStack {
                            Image(systemName: "paperclip")
                                .font(.system(size: 11))
                                .foregroundStyle(palette.muted)
                            Text(url.split(separator: "/").last.map(String.init) ?? url)
                                .font(.system(size: 12))
                                .foregroundStyle(palette.text)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button {
                                files.removeAll { $0 == url }
                                Haptics.tap()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(palette.muted)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(palette.chipBg))
                    }
                }
            }

            Button {
                Haptics.tap()
                pickerOpen = true
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("Add files")
                    Spacer()
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(palette.subtitle)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(palette.cardStroke, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(palette.chipBg))
        .fileImporter(
            isPresented: $pickerOpen,
            allowedContentTypes: stream.contentTypes,
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                Task { await uploadAll(urls) }
            case .failure:
                Haptics.error()
            }
        }
    }

    /// Reads each picked file and uploads it through the Worker's presigned PUT URL,
    /// then appends the resulting publicURL to `files`. Public URLs are what the
    /// LLM and audio-analysis modules ingest, exactly like the Base44 flow.
    @MainActor
    private func uploadAll(_ urls: [URL]) async {
        uploadingCount = urls.count
        defer { uploadingCount = 0 }
        for url in urls {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let filename = url.lastPathComponent
                let contentType = stream.mimeType
                let presigned = try await APIClient.shared.presignUpload(filename: filename, contentType: contentType)
                try await APIClient.shared.uploadFile(data, to: presigned, contentType: contentType)
                files.append(presigned.publicURL)
                Haptics.success()
            } catch {
                lastError = error.localizedDescription
                Haptics.error()
            }
            uploadingCount -= 1
        }
    }
}
