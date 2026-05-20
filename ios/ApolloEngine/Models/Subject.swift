//
//  Subject.swift
//  ApolloEngine
//
//  SwiftData mirror of the Base44 Subject entity schema.
//  All fields have default values so the model is CloudKit-sync compatible.
//

import Foundation
import SwiftData

// MARK: - Status enums

enum SubjectStatus: String, Codable, CaseIterable {
    case intake, processing, review, finalized

    var label: String {
        switch self {
        case .intake: return "Intake"
        case .processing: return "Processing"
        case .review: return "Review"
        case .finalized: return "Finalized"
        }
    }
}

enum DSPStatus: String, Codable, CaseIterable {
    case pending, generating, valid, failed, empty
}

// MARK: - Codable sub-types (stored as encoded JSON for portability)

nonisolated struct TraitScore: Codable, Hashable {
    var score: Int = 50
    var label: String = ""
    var evidence: String = ""
    var indicators: [String] = []
}

nonisolated struct PersonalityMatrix: Codable, Hashable {
    var openness: TraitScore = TraitScore()
    var conscientiousness: TraitScore = TraitScore()
    var extraversion: TraitScore = TraitScore()
    var agreeableness: TraitScore = TraitScore()
    var neuroticism: TraitScore = TraitScore()

    var allTraits: [(key: String, label: String, trait: TraitScore)] {
        [
            ("openness", "Openness", openness),
            ("conscientiousness", "Conscientiousness", conscientiousness),
            ("extraversion", "Extraversion", extraversion),
            ("agreeableness", "Agreeableness", agreeableness),
            ("neuroticism", "Neuroticism", neuroticism),
        ]
    }
}

nonisolated struct CognitiveSubsection: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var title: String = ""
    var content: String = ""
}

nonisolated struct CognitiveArchitecture: Codable, Hashable {
    var thinking_style: String = ""
    var epistemic_requirements: String = ""
    var defense_mechanisms: String = ""
    var sub_sections: [CognitiveSubsection] = []
}

nonisolated struct BehavioralPattern: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var label: String = ""
    var description: String = ""
    var context: String = ""
}

nonisolated struct ConfidenceInterval: Codable, Hashable {
    var lower: Int = 0
    var upper: Int = 100
}

nonisolated struct ActionResponse: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var trigger: String = ""
    var predicted_behavior: String = ""
    var probability: Int = 75
    var confidence_interval: ConfidenceInterval? = nil
    var temporal_factors: String = ""
}

nonisolated struct ConflictDetected: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var type: String = ""           // "analysis_conflict" | "dsp_integrity"
    var description: String = ""
    var resolution: String = ""
    var timestamp: String = ""
}

nonisolated struct AnalysisResults: Codable, Hashable {
    var stylometric_fingerprint: AnalysisModuleResult? = nil
    var cognitive_architecture: AnalysisModuleResult? = nil
    var psychomotor_state: AnalysisModuleResult? = nil
    var affective_state: AnalysisModuleResult? = nil
    var behavioral_loop: AnalysisModuleResult? = nil
}

nonisolated struct AnalysisModuleResult: Codable, Hashable {
    var summary: String = ""
    var key_patterns: [String] = []
    var indicators: [String] = []
    var confidence: Double = 0
    var flags: [String] = []
    var processing_notes: String = ""
    var preprocessing_info: String = ""
}

nonisolated struct DSP: Codable, Hashable {
    var document_id: String = ""
    var protocol_version: String = "CP-003-O-D-APL v2.1"
    var date_of_synthesis: String = ""
    var confidence_score: Int = 0
    var confidence_justification: String = ""
    var executive_summary: String = ""
    var classification: String = ""
    var final_assessment: String = ""
    var personality_matrix: PersonalityMatrix = PersonalityMatrix()
    var cognitive_architecture: CognitiveArchitecture = CognitiveArchitecture()
    var behavioral_patterns: [BehavioralPattern] = []
    var action_response_matrix: [ActionResponse] = []
    var motivations: [String] = []
    var fears: [String] = []
}

nonisolated struct EsotericInputs: Codable, Hashable {
    var full_birth_name: String = ""
    var date_of_birth: String = ""
    var place_of_birth: String = ""
    var time_of_birth: String = ""
    var mode: String = "PRESENT-STATE"
    var timeframe: String = ""
    var focus: String = ""
}

nonisolated struct SMEValidation: Codable, Hashable {
    var astrology_governed_timing: Bool = true
    var numerology_governed_structure: Bool = true
    var emotional_depth_prioritized: Bool = true
    var practical_translation_achieved: Bool = true
    var generic_horoscope_drift_avoided: Bool = true
    var execution_status: String = "COMPLIANT"

    var checks: [(label: String, passed: Bool)] {
        [
            ("Astrology Governed Timing", astrology_governed_timing),
            ("Numerology Governed Structure", numerology_governed_structure),
            ("Emotional Depth Prioritized", emotional_depth_prioritized),
            ("Practical Translation Achieved", practical_translation_achieved),
            ("Generic Drift Avoided", generic_horoscope_drift_avoided),
        ]
    }
}

nonisolated struct EsotericProfile: Codable, Hashable {
    var include_in_dsp: Bool = false
    var input_fidelity: String = ""       // FULL | REDUCED-FIDELITY | HALTED
    var execution_status: String = ""     // COMPLIANT | NONCOMPLIANT
    var date_executed: String = ""
    var inquiry_frame: String = ""
    var astrological_interpretation: String = ""
    var numerological_interpretation: String = ""
    var unified_emotional_synthesis: String = ""
    var threshold_assessment: String = ""
    var strategic_translation: String = ""
    var limitation_statement: String = ""
    var sme_validation: SMEValidation = SMEValidation()
}

nonisolated struct ConvergencePoint: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var domain: String = ""
    var dsp_evidence: String = ""
    var esoteric_evidence: String = ""
    var significance: String = ""
    var confidence: Int = 0
}

nonisolated struct DivergencePoint: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var domain: String = ""
    var dsp_position: String = ""
    var esoteric_position: String = ""
    var arbitration: String = ""
    var tension_value: String = ""
}

nonisolated struct ConvergenceMap: Codable, Hashable {
    var convergence_points: [ConvergencePoint] = []
    var divergence_points: [DivergencePoint] = []
    var overall_alignment_score: Int = 0
}

nonisolated struct UnifiedDossier: Codable, Hashable {
    var date_synthesized: String = ""
    var dsp_source_date: String = ""
    var esoteric_source_date: String = ""
    var unified_identity_portrait: String = ""
    var psychodynamic_architecture: String = ""
    var personality_archetypal_resonance: String = ""
    var behavioral_topology: String = ""
    var predictive_convergence_model: String = ""
    var core_drivers_shadow: String = ""
    var convergence_map: ConvergenceMap = ConvergenceMap()
    var final_unified_assessment: String = ""
    var synthesis_confidence: Int = 0
    var synthesis_methodology_note: String = ""
}

// MARK: - SwiftData Subject

@Model
final class Subject {
    @Attribute(.unique) var id: String = UUID().uuidString
    var name: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // Status flags
    var statusRaw: String = SubjectStatus.intake.rawValue
    var dspStatusRaw: String = DSPStatus.pending.rawValue

    // Evidence streams — stored as JSON-encoded arrays of URL strings (CloudKit-safe)
    var streamATextData: Data = Data()
    var streamBAudioData: Data = Data()
    var streamCVideoData: Data = Data()
    var streamDBehavioralData: Data = Data()
    var streamEAnalogData: Data = Data()

    // Analytical results & dossiers — stored as encoded JSON blobs
    var analysisResultsData: Data = Data()
    var dspData: Data = Data()
    var esotericInputsData: Data = Data()
    var esotericProfileData: Data = Data()
    var unifiedDossierData: Data = Data()
    var conflictsData: Data = Data()

    var operatorNotes: String = ""

    init(name: String) {
        self.name = name
    }
}

// MARK: - Subject computed accessors (Codec-friendly)

extension Subject {
    var status: SubjectStatus {
        get { SubjectStatus(rawValue: statusRaw) ?? .intake }
        set { statusRaw = newValue.rawValue }
    }

    var dspStatus: DSPStatus {
        get { DSPStatus(rawValue: dspStatusRaw) ?? .pending }
        set { dspStatusRaw = newValue.rawValue }
    }

    var streamAText: [String] {
        get { decode(streamATextData) ?? [] }
        set { streamATextData = encode(newValue) }
    }
    var streamBAudio: [String] {
        get { decode(streamBAudioData) ?? [] }
        set { streamBAudioData = encode(newValue) }
    }
    var streamCVideo: [String] {
        get { decode(streamCVideoData) ?? [] }
        set { streamCVideoData = encode(newValue) }
    }
    var streamDBehavioral: [String] {
        get { decode(streamDBehavioralData) ?? [] }
        set { streamDBehavioralData = encode(newValue) }
    }
    var streamEAnalog: [String] {
        get { decode(streamEAnalogData) ?? [] }
        set { streamEAnalogData = encode(newValue) }
    }

    var dsp: DSP {
        get { decode(dspData) ?? DSP() }
        set { dspData = encode(newValue) }
    }
    var analysisResults: AnalysisResults {
        get { decode(analysisResultsData) ?? AnalysisResults() }
        set { analysisResultsData = encode(newValue) }
    }
    var esotericInputs: EsotericInputs {
        get { decode(esotericInputsData) ?? EsotericInputs() }
        set { esotericInputsData = encode(newValue) }
    }
    var esotericProfile: EsotericProfile? {
        get {
            let p: EsotericProfile? = decode(esotericProfileData)
            guard let p, !p.execution_status.isEmpty || !p.input_fidelity.isEmpty else { return nil }
            return p
        }
        set { esotericProfileData = encode(newValue ?? EsotericProfile()) }
    }
    var unifiedDossier: UnifiedDossier? {
        get {
            let d: UnifiedDossier? = decode(unifiedDossierData)
            guard let d, !d.date_synthesized.isEmpty else { return nil }
            return d
        }
        set { unifiedDossierData = encode(newValue ?? UnifiedDossier()) }
    }
    var conflicts: [ConflictDetected] {
        get { decode(conflictsData) ?? [] }
        set { conflictsData = encode(newValue) }
    }

    // ── Helpers ──────────────────────────────────────────────────────────────
    var streamCount: Int {
        [streamAText, streamBAudio, streamCVideo, streamDBehavioral, streamEAnalog]
            .reduce(0) { $0 + ($1.isEmpty ? 0 : 1) }
    }

    var totalEvidence: Int {
        streamAText.count + streamBAudio.count + streamCVideo.count + streamDBehavioral.count + streamEAnalog.count
    }

    var hasDSP: Bool { !dsp.executive_summary.isEmpty }
    var hasEsoteric: Bool { esotericProfile?.execution_status.isEmpty == false }
    var hasUnified: Bool { unifiedDossier != nil }

    var documentID: String {
        let suffix = String(id.suffix(6)).uppercased()
        return dsp.document_id.isEmpty ? "DSP-\(suffix)-CP-003-APL" : dsp.document_id
    }
}

// MARK: - JSON helpers (nonisolated for actor-safety)

nonisolated private func encode<T: Encodable>(_ value: T) -> Data {
    (try? JSONEncoder().encode(value)) ?? Data()
}

nonisolated private func decode<T: Decodable>(_ data: Data) -> T? {
    guard !data.isEmpty else { return nil }
    return try? JSONDecoder().decode(T.self, from: data)
}
