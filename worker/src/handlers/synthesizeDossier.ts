/**
 * MELLMA Unified Dossier — synthesizes DSP + Esoteric Profile into one woven document.
 * Direct port of base44/functions/synthesizeDossier/entry.ts.
 * Same Claude Sonnet 4.6 model, same two parallel calls, same integrative-analyst system prompt.
 */
import { Context } from "hono";
import type { Env } from "../types";
import { invokeLLM } from "../llm";

interface RequestBody {
  subject_id: string;
  subject_name?: string;
  dsp: Record<string, any>;
  esoteric_profile: Record<string, any>;
}

function buildDSPSummary(dsp: any): string {
  const parts: string[] = [];
  parts.push(`CLASSIFICATION: ${dsp.classification || "Not classified"}`);
  parts.push(`CONFIDENCE: ${dsp.confidence_score || 0}% — ${dsp.confidence_justification || "No justification"}`);
  if (dsp.executive_summary) parts.push(`\nEXECUTIVE SUMMARY:\n${dsp.executive_summary}`);

  if (dsp.personality_matrix) {
    const traits = ["openness", "conscientiousness", "extraversion", "agreeableness", "neuroticism"];
    const lines = traits.map((t) => {
      const d = dsp.personality_matrix[t];
      if (!d) return null;
      return `  ${t.toUpperCase()}: ${d.score}/100 (${d.label}) — ${d.evidence || "No evidence"}`;
    }).filter(Boolean);
    if (lines.length) parts.push(`\nPERSONALITY MATRIX (Big Five):\n${lines.join("\n")}`);
  }

  if (dsp.cognitive_architecture) {
    const ca = dsp.cognitive_architecture;
    const lines: string[] = [];
    if (ca.thinking_style) lines.push(`  Thinking Style: ${ca.thinking_style}`);
    if (ca.epistemic_requirements) lines.push(`  Epistemic Requirements: ${ca.epistemic_requirements}`);
    if (ca.defense_mechanisms) lines.push(`  Defense Mechanisms: ${ca.defense_mechanisms}`);
    if (ca.sub_sections?.length) ca.sub_sections.forEach((s: any) => lines.push(`  ${s.title}: ${s.content}`));
    if (lines.length) parts.push(`\nCOGNITIVE ARCHITECTURE:\n${lines.join("\n")}`);
  }

  if (dsp.behavioral_patterns?.length) {
    const bp = dsp.behavioral_patterns.map((p: any) => `  [${p.label}] ${p.description} (Context: ${p.context})`);
    parts.push(`\nBEHAVIORAL PATTERNS:\n${bp.join("\n")}`);
  }

  if (dsp.action_response_matrix?.length) {
    const arm = dsp.action_response_matrix.map((p: any) => {
      const prob = p.probability ? `${p.probability}%` : "?";
      const ci = p.confidence_interval ? ` [CI: ${p.confidence_interval.lower}-${p.confidence_interval.upper}]` : "";
      return `  Trigger: ${p.trigger || "?"} → ${p.predicted_behavior || "?"} (P=${prob}${ci})`;
    });
    parts.push(`\nPREDICTIVE MODEL:\n${arm.join("\n")}`);
  }

  if (dsp.motivations?.length) parts.push(`\nMOTIVATIONS: ${dsp.motivations.join("; ")}`);
  if (dsp.fears?.length) parts.push(`FEARS: ${dsp.fears.join("; ")}`);
  if (dsp.final_assessment) parts.push(`\nFINAL ASSESSMENT:\n${dsp.final_assessment}`);

  return parts.join("\n");
}

function buildEsotericSummary(esp: any): string {
  const parts: string[] = [];
  parts.push(`FIDELITY: ${esp.input_fidelity || "UNKNOWN"}`);
  parts.push(`EXECUTION STATUS: ${esp.execution_status || "UNKNOWN"}`);
  parts.push(`DATE: ${esp.date_executed || "Unknown"}`);
  if (esp.inquiry_frame) parts.push(`\nINQUIRY FRAME:\n${esp.inquiry_frame}`);
  if (esp.astrological_interpretation) parts.push(`\nASTROLOGICAL INTERPRETATION (Node Alpha):\n${esp.astrological_interpretation}`);
  if (esp.numerological_interpretation) parts.push(`\nNUMEROLOGICAL INTERPRETATION (Node Beta):\n${esp.numerological_interpretation}`);
  if (esp.unified_emotional_synthesis) parts.push(`\nUNIFIED EMOTIONAL SYNTHESIS:\n${esp.unified_emotional_synthesis}`);
  if (esp.threshold_assessment) parts.push(`\nTHRESHOLD ASSESSMENT:\n${esp.threshold_assessment}`);
  if (esp.strategic_translation) parts.push(`\nSTRATEGIC TRANSLATION:\n${esp.strategic_translation}`);
  if (esp.limitation_statement) parts.push(`\nLIMITATION STATEMENT:\n${esp.limitation_statement}`);
  if (esp.sme_validation) {
    const v = esp.sme_validation;
    const checks = [
      `Astrology Governed Timing: ${v.astrology_governed_timing ? "PASS" : "FAIL"}`,
      `Numerology Governed Structure: ${v.numerology_governed_structure ? "PASS" : "FAIL"}`,
      `Emotional Depth Prioritized: ${v.emotional_depth_prioritized ? "PASS" : "FAIL"}`,
      `Practical Translation: ${v.practical_translation_achieved ? "PASS" : "FAIL"}`,
      `Generic Drift Avoided: ${v.generic_horoscope_drift_avoided ? "PASS" : "FAIL"}`,
    ];
    parts.push(`\nSME VALIDATION: ${v.execution_status || "UNKNOWN"}\n  ${checks.join("\n  ")}`);
  }
  return parts.join("\n");
}

export async function synthesizeDossier(c: Context<{ Bindings: Env }>) {
  let body: RequestBody;
  try {
    body = (await c.req.json()) as RequestBody;
  } catch {
    return c.json({ error: "Invalid JSON body" }, 400);
  }

  const { subject_id, subject_name, dsp, esoteric_profile: esp } = body;
  if (!subject_id) return c.json({ error: "subject_id required" }, 400);
  if (!dsp?.executive_summary) {
    return c.json({ error: "DSP not yet generated. Generate the DSP before synthesizing." }, 400);
  }
  if (!esp?.execution_status) {
    return c.json({ error: "Esoteric Profile not yet generated. Execute CP-012 before synthesizing." }, 400);
  }

  const subjectName = subject_name || "Unknown Subject";
  const today = new Date().toISOString().split("T")[0];

  const systemContext = `You are a senior integrative analyst. You have two independent assessments of the same subject on your desk:

1. DEFINITIVE SUBJECT PROFILE (DSP) — Empirical, data-driven psychological portrait derived from multimodal behavioral analysis (text, audio, video, behavioral data, handwriting).
2. ESOTERIC INTELLIGENCE PROFILE (ESP) — Symbolic, archetypal portrait derived from astrological and numerological analysis.

Your task is NOT to summarize them separately or concatenate them. Your task is to SYNTHESIZE them into a single unified document written in ONE authoritative voice, as if you had access to both knowledge domains simultaneously.

CRITICAL RULES:
- Write as one analyst who sees through both lenses, not as a reporter quoting two sources
- When the two lenses agree, state the finding with strengthened confidence and note that convergence
- When they diverge, declare the tension explicitly and explain what the disagreement reveals
- PRESERVE all quantitative data: Big Five scores, probability percentages, CI ranges, transit names, numerological values, personal year numbers
- Every section must weave empirical and symbolic insights together, not present them sequentially
- The tone should be analytical, authoritative, and psychologically sophisticated

SUBJECT: ${subjectName}`;

  const dspSummary = buildDSPSummary(dsp);
  const espSummary = buildEsotericSummary(esp);

  const llm = (prompt: string, schema: Record<string, unknown>) =>
    invokeLLM(c.env, { model: "claude_sonnet_4_6", prompt, response_json_schema: { type: "object", properties: schema } });

  const narrativePrompt = `${systemContext}

DSP DATA:
${dspSummary}

ESOTERIC DATA:
${espSummary}

Produce these unified sections. Each must integrate BOTH lenses into a single woven narrative:

1. UNIFIED IDENTITY PORTRAIT (4-5 paragraphs): Merge the DSP executive summary with the esoteric inquiry frame and unified emotional synthesis. Who IS this person when seen through both lenses simultaneously?

2. PSYCHODYNAMIC ARCHITECTURE (3-4 paragraphs): Merge DSP cognitive architecture (thinking style, epistemic requirements, defense mechanisms) with the astrological interpretation. How do the subject's cognitive patterns align with or diverge from their planetary activations?

3. PERSONALITY & ARCHETYPAL RESONANCE (3-4 paragraphs): Merge the Big Five personality matrix with the numerological interpretation. Reference specific scores alongside cycle positions. Where does the empirical personality confirm or challenge the archetypal structure?

4. BEHAVIORAL TOPOLOGY (3-4 paragraphs): Merge behavioral patterns with the threshold assessment. Is the subject's observed behavioral loop congruent with their esoteric phase? What does the combination reveal?

5. PREDICTIVE CONVERGENCE MODEL (3-4 paragraphs): Merge the action/response matrix (triggers, predicted behaviors, probabilities) with the strategic translation. Where do empirical predictions and esoteric guidance point in the same direction? Where do they diverge?

6. CORE DRIVERS & SHADOW MATERIAL (2-3 paragraphs): Merge motivations/fears with the limitation statement. What drives this person at the deepest level when both lenses are applied?`;

  const narrativeSchema = {
    unified_identity_portrait: { type: "string" },
    psychodynamic_architecture: { type: "string" },
    personality_archetypal_resonance: { type: "string" },
    behavioral_topology: { type: "string" },
    predictive_convergence_model: { type: "string" },
    core_drivers_shadow: { type: "string" },
  };

  const convergencePrompt = `${systemContext}

DSP DATA:
${dspSummary}

ESOTERIC DATA:
${espSummary}

Produce:

1. CONVERGENCE MAP — Analyze where the two lenses agree and disagree:
   - convergence_points: Array of 4-6 objects. Each has: domain (string), dsp_evidence (string), esoteric_evidence (string), significance (string), confidence (0-100).
   - divergence_points: Array of 2-4 objects. Each has: domain (string), dsp_position (string), esoteric_position (string), arbitration (string), tension_value (low|medium|high).
   - overall_alignment_score: Integer 0-100.

2. FINAL UNIFIED ASSESSMENT (5-7 paragraphs): The single-voice definitive portrait of this subject. This is the culmination. It should read as if one brilliant analyst wrote it from complete knowledge. Reference specific data points from both domains naturally.

3. SYNTHESIS CONFIDENCE: Integer 0-100.

4. SYNTHESIS METHODOLOGY NOTE: 2-3 sentences.`;

  const convergenceSchema = {
    convergence_map: {
      type: "object",
      properties: {
        convergence_points: { type: "array", items: { type: "object" } },
        divergence_points: { type: "array", items: { type: "object" } },
        overall_alignment_score: { type: "number" },
      },
    },
    final_unified_assessment: { type: "string" },
    synthesis_confidence: { type: "number" },
    synthesis_methodology_note: { type: "string" },
  };

  try {
    const [narrativeResult, convergenceResult] = await Promise.all([
      llm(narrativePrompt, narrativeSchema),
      llm(convergencePrompt, convergenceSchema),
    ]);
    const narrative = narrativeResult.response as any;
    const convergence = convergenceResult.response as any;

    const unified_dossier = {
      date_synthesized: today,
      dsp_source_date: dsp.date_of_synthesis || "",
      esoteric_source_date: esp.date_executed || "",
      unified_identity_portrait: narrative.unified_identity_portrait || "",
      psychodynamic_architecture: narrative.psychodynamic_architecture || "",
      personality_archetypal_resonance: narrative.personality_archetypal_resonance || "",
      behavioral_topology: narrative.behavioral_topology || "",
      predictive_convergence_model: narrative.predictive_convergence_model || "",
      core_drivers_shadow: narrative.core_drivers_shadow || "",
      convergence_map: convergence.convergence_map || { convergence_points: [], divergence_points: [], overall_alignment_score: 0 },
      final_unified_assessment: convergence.final_unified_assessment || "",
      synthesis_confidence: convergence.synthesis_confidence || 0,
      synthesis_methodology_note: convergence.synthesis_methodology_note || "",
    };

    return c.json({ success: true, unified_dossier });
  } catch (e: any) {
    return c.json({ error: e?.message ?? "synthesis failed" }, 500);
  }
}
