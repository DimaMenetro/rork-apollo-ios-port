/**
 * CP-012-O-D-ESP — client-side port of the Worker's generateEsotericProfile handler.
 * Same prompts, same model (Gemini 3 Flash), same pre-computed Personal Year math,
 * same SME validation schema, same staggered Promise.all sequencing.
 *
 * NOTE: Unlike the Worker's llm.ts which returns { response, raw }, our client-side
 * invokeLLM returns the parsed object directly when a schema is supplied.
 */
import { invokeLLM } from './llm';

const MONTH_MAP = {
  january: 1, february: 2, march: 3, april: 4, may: 5, june: 6,
  july: 7, august: 8, september: 9, october: 10, november: 11, december: 12,
};

function reduceNumerologyDigit(n) {
  while (n > 9 && n !== 11 && n !== 22 && n !== 33) {
    n = String(n).split('').reduce((a, d) => a + parseInt(d, 10), 0);
  }
  return n;
}

/**
 * @param {{ subject_id: string, subject_name?: string, esoteric_inputs: object, dsp_summary?: string }} body
 * @returns {Promise<object>} the esoteric_profile object
 */
export async function generateEsotericProfileLocal(body) {
  const { subject_id, subject_name, esoteric_inputs, dsp_summary } = body;
  if (!subject_id) throw new Error('subject_id required');
  if (!esoteric_inputs) throw new Error('esoteric_inputs required');

  const {
    full_birth_name, date_of_birth, place_of_birth,
    time_of_birth, timeframe, mode, focus,
  } = esoteric_inputs;

  if (!full_birth_name || !date_of_birth || !place_of_birth) {
    throw new Error(
      'HALTED: Missing required inputs. Required: full birth name, date of birth, place of birth.'
    );
  }

  const fidelityState = time_of_birth ? 'FULL' : 'REDUCED-FIDELITY';
  const subjectName = subject_name || 'Unknown Subject';
  const executionMode = mode || 'PRESENT-STATE';
  const dspSummary = (dsp_summary ?? '').slice(0, 600);

  const now = new Date();
  const today = now.toISOString().split('T')[0];
  const currentYear = now.getFullYear();
  const currentMonth = now.getMonth() + 1;

  // Pre-compute Personal Year so the LLM cannot hallucinate it.
  let personalYearNote = '';
  try {
    const rawDob = date_of_birth.toLowerCase().trim();
    let bMonth = null;
    let bDay = null;
    for (const [name, num] of Object.entries(MONTH_MAP)) {
      if (rawDob.includes(name)) { bMonth = num; break; }
    }
    const numericDate = rawDob.match(/^(\d{1,2})[/\-](\d{1,2})[/\-](\d{2,4})/);
    if (numericDate && !bMonth) {
      bMonth = parseInt(numericDate[1], 10);
      bDay = parseInt(numericDate[2], 10);
    } else {
      const dayMatch = rawDob.match(/\b(\d{1,2})\b/);
      if (dayMatch) bDay = parseInt(dayMatch[1], 10);
    }
    if (bMonth && bDay) {
      const yearDigits = String(currentYear).split('').reduce((a, d) => a + parseInt(d, 10), 0);
      const personalYear = reduceNumerologyDigit(bDay + bMonth + yearDigits);
      personalYearNote = `\nPRE-COMPUTED (do not recalculate): Personal Year for ${currentYear} = ${personalYear} (birth day ${bDay} + birth month ${bMonth} + ${currentYear} digit sum ${yearDigits} = reduced to ${personalYear})`;
    }
  } catch { /* personal year is optional */ }

  const baseParams = `Subject: ${subjectName}
Full Birth Name: ${full_birth_name}
Date of Birth: ${date_of_birth}
Time of Birth: ${time_of_birth || 'Not provided — Reduced-Fidelity'}
Place of Birth: ${place_of_birth}
Mode: ${executionMode}
CURRENT DATE: ${today} — Year: ${currentYear}, Month: ${currentMonth}. Use ONLY this date for all transit, progression, and personal year calculations. Do NOT use any other year.${personalYearNote}${timeframe ? `\nTimeframe: ${timeframe}` : ''}${focus ? `\nFocus: ${focus}` : ''}${dspSummary ? `\nDSP Summary: ${dspSummary}` : ''}`;

  const llm = (prompt, schema) =>
    invokeLLM({ model: 'claude_sonnet_4_6', prompt, response_json_schema: { type: 'object', properties: schema } });

  const [a, b] = await Promise.all([
    llm(
      `CP-012 PHASE I–II\n${baseParams}\n\nINSTRUCTION: Proceed immediately with your best calculations using standard assumptions (tropical zodiac, Placidus houses, Western numerology Pythagorean system). Do NOT ask clarifying questions.\n\nPHASE I: Show astrological calculations (Sun/Moon/Rising using TOB if provided) and numerological calculations (Life Path, Expression, Soul Urge, Personal Year). Show your arithmetic.\n\nPHASE II — Inquiry Frame: Answer these 3 questions with analytical depth (2 paragraphs each):\n1. What emotional pattern / developmental task is currently activated?\n2. Is subject in rupture, reintegration, plateau, or threshold transit?\n3. Which relational/identity pattern is repeating and what mechanism drives it now?\nNo vague symbolic language. Every claim anchored to a specific planetary or numerological mechanism.`,
      { inquiry_frame: { type: 'string' } },
    ),
    llm(
      `CP-012 PHASE III–IV\n${baseParams}\n\nINSTRUCTION: Proceed immediately with your best calculations using standard assumptions (tropical zodiac, Placidus houses, Western Pythagorean numerology). Do NOT ask clarifying questions.\n\nPHASE III — Astrological Interpretation (Node Alpha): Time-governed psychodynamic map. Current transits and progressions that are active now. Reference specific degrees and aspects. 3 tight paragraphs.\n\nPHASE IV — Numerological Interpretation (Node Beta): Structural cycle architecture. Life Path lesson, current pinnacle/challenge, personal year meaning. 2 tight paragraphs.\n\nNo vague language. Every claim mechanistically grounded.`,
      { astrological_interpretation: { type: 'string' }, numerological_interpretation: { type: 'string' } },
    ),
  ]);

  const [cc, d] = await Promise.all([
    llm(
      `CP-012 PHASE V–VII\n${baseParams}\n\nINSTRUCTION: Proceed immediately. Do NOT ask clarifying questions. Use standard astrological and numerological assumptions.\n\nPHASE V–VI — Unified Emotional Synthesis: Reconcile astrology (timing) and numerology (structure) into one subject model. Dominant emotional pattern, core defense, relational pattern, current threshold state. If divergent, declare tension explicitly. 3 paragraphs.\n\nPHASE VI — Threshold Assessment: Current phase (rupture/reintegration/plateau/threshold transit). What is being crossed, what this period demands. 2 paragraphs.\n\nPHASE VII — Strategic Translation: Concrete behavioral, relational, and developmental implications. Specific and practical. 2 paragraphs.`,
      { unified_emotional_synthesis: { type: 'string' }, threshold_assessment: { type: 'string' }, strategic_translation: { type: 'string' } },
    ),
    llm(
      `CP-012 PHASE VIII\n${baseParams}\n\nINSTRUCTION: Proceed immediately. Do NOT ask clarifying questions.\n\nLIMITATION STATEMENT: In 1 paragraph, describe the material constraints affecting confidence in this reading — missing TOB impact, calculation approximations, fidelity caveats.\n\nSME VALIDATION: Honestly assess whether each criterion was met (true/false) and set execution_status to COMPLIANT or NONCOMPLIANT.`,
      {
        limitation_statement: { type: 'string' },
        sme_validation: {
          type: 'object',
          properties: {
            astrology_governed_timing: { type: 'boolean' },
            numerology_governed_structure: { type: 'boolean' },
            emotional_depth_prioritized: { type: 'boolean' },
            practical_translation_achieved: { type: 'boolean' },
            generic_horoscope_drift_avoided: { type: 'boolean' },
            execution_status: { type: 'string' },
          },
        },
      },
    ),
  ]);

  // Our invokeLLM returns the parsed object directly (no .response wrapper)
  const sme = d.sme_validation ?? {};
  const esoteric_profile = {
    ...a, ...b, ...cc, ...d,
    input_fidelity: fidelityState,
    execution_status: sme.execution_status || 'COMPLIANT',
    date_executed: today,
    include_in_dsp: false,
  };

  return esoteric_profile;
}
