/**
 * PDF export — client-side port of the Worker's exportDSP handler.
 * Same jsPDF layout (cover, confidence arc, personality bars, predictive model,
 * ESP sections, SME validation, footer) in both dark and light themes.
 * Returns a Blob instead of a Response.
 */
import { jsPDF } from 'jspdf';

/** @typedef {[number, number, number]} RGB */

/**
 * @param {{ subject: object, mode?: 'dsp'|'esoteric'|'merged', theme?: 'dark'|'light' }} opts
 * @returns {Promise<Blob>}
 */
export async function buildDSPPdfBlob({ subject, mode = 'dsp', theme = 'dark' }) {
  const themeKey = theme;
  const payload = subject;
  const dsp = payload.dsp ?? {};
  const esp = payload.esoteric_profile ?? null;

  const THEMES = {
    dark: {
      bg: [9, 9, 15], cardBg: [18, 20, 30], text: [203, 213, 225], title: [241, 245, 249], muted: [71, 85, 105],
      accent: [245, 158, 11], violet: [139, 92, 246], green: [16, 185, 129], rose: [244, 63, 94], cyan: [6, 182, 212],
      border: [30, 35, 50], barTrack: [30, 35, 50],
    },
    light: {
      bg: [248, 248, 252], cardBg: [255, 255, 255], text: [60, 60, 67], title: [28, 28, 30], muted: [142, 142, 147],
      accent: [217, 119, 6], violet: [124, 58, 237], green: [5, 150, 105], rose: [225, 29, 72], cyan: [8, 145, 178],
      border: [220, 220, 230], barTrack: [230, 230, 238],
    },
  };

  const themeObj = THEMES[themeKey] ?? THEMES.dark;
  const t = themeObj;

  const doc = new jsPDF({ orientation: 'portrait', unit: 'mm', format: 'a4' });
  const pageW = doc.internal.pageSize.getWidth();
  const margin = { left: 20, y: 20 };
  const contentW = pageW - 40;

  function drawPageBg() {
    const w = doc.internal.pageSize.getWidth();
    const h = doc.internal.pageSize.getHeight();
    doc.setFillColor(...t.bg);
    doc.rect(0, 0, w, h, 'F');
  }

  function ensureSpace(needed) {
    const pageH = doc.internal.pageSize.getHeight();
    if (margin.y + needed > pageH - 20) {
      doc.addPage();
      drawPageBg();
      margin.y = 20;
    }
  }

  function drawBar(x, y, w, score, color) {
    const h = 3;
    doc.setFillColor(...t.barTrack);
    doc.roundedRect(x, y, w, h, 1.5, 1.5, 'F');
    const fillW = Math.max(2, (score / 100) * w);
    doc.setFillColor(...color);
    doc.roundedRect(x, y, fillW, h, 1.5, 1.5, 'F');
  }

  function drawConfidenceArc(cx, cy, radius, score) {
    doc.setDrawColor(...t.border);
    doc.setLineWidth(2);
    doc.circle(cx, cy, radius, 'S');
    const color = score >= 80 ? t.green : score >= 60 ? t.accent : t.rose;
    doc.setDrawColor(...color);
    doc.setLineWidth(2.5);
    const startAngle = -Math.PI / 2;
    const endAngle = startAngle + (2 * Math.PI * score) / 100;
    const steps = Math.max(20, Math.floor(score / 2));
    for (let i = 0; i < steps; i++) {
      const a1 = startAngle + ((endAngle - startAngle) * i) / steps;
      const a2 = startAngle + ((endAngle - startAngle) * (i + 1)) / steps;
      doc.line(cx + radius * Math.cos(a1), cy + radius * Math.sin(a1),
               cx + radius * Math.cos(a2), cy + radius * Math.sin(a2));
    }
    doc.setFontSize(16);
    doc.setTextColor(...color);
    doc.text(`${score}%`, cx, cy + 2, { align: 'center' });
  }

  function sectionHeader(icon, title, color) {
    ensureSpace(14);
    doc.setFontSize(8);
    doc.setTextColor(...color);
    doc.text(icon, margin.left, margin.y);
    doc.text(title.toUpperCase(), margin.left + 6, margin.y);
    margin.y += 8;
  }

  function wrappedText(text, opts = {}) {
    const maxW = opts.maxW ?? 170;
    const fontSize = opts.fontSize ?? 9;
    doc.setFontSize(fontSize);
    doc.setTextColor(...(opts.color ?? t.text));
    const lines = doc.splitTextToSize(text || '', maxW);
    for (const line of lines) {
      ensureSpace(5);
      doc.text(line, opts.x ?? margin.left, margin.y);
      margin.y += fontSize * 0.45;
    }
    margin.y += 2;
  }

  drawPageBg();

  // ── COVER ───────────────────────────────────────────────────────────────
  margin.y = 50;
  doc.setFontSize(10);
  doc.setTextColor(...t.muted);
  doc.text('APOLLO PROFILING ENGINE', pageW / 2, margin.y, { align: 'center' });
  margin.y += 12;

  doc.setFontSize(24);
  doc.setTextColor(...t.title);
  const docTitle = mode === 'esoteric' ? 'Esoteric Intelligence Profile'
    : mode === 'merged' ? 'Unified Subject Dossier'
    : 'Definitive Subject Profile';
  doc.text(docTitle, pageW / 2, margin.y, { align: 'center' });
  margin.y += 10;

  doc.setFontSize(18);
  doc.setTextColor(...t.accent);
  doc.text(payload.name ?? 'Unknown', pageW / 2, margin.y, { align: 'center' });
  margin.y += 16;

  const metaLines = [];
  if (dsp.document_id) metaLines.push(['DOCUMENT ID', dsp.document_id]);
  metaLines.push(['PROTOCOL', dsp.protocol_version ?? 'CP-003-O-D-APL v2.1']);
  metaLines.push(['DATE', dsp.date_of_synthesis ?? new Date().toISOString().split('T')[0]]);
  if (mode !== 'dsp' && esp) metaLines.push(['ESOTERIC', 'CP-012-O-D-ESP']);

  for (const [label, val] of metaLines) {
    doc.setFontSize(7);
    doc.setTextColor(...t.muted);
    doc.text(label, pageW / 2 - 30, margin.y);
    doc.setFontSize(9);
    doc.setTextColor(...t.text);
    doc.text(val, pageW / 2 + 5, margin.y);
    margin.y += 6;
  }
  margin.y += 8;

  if (mode !== 'esoteric' && dsp.confidence_score) {
    drawConfidenceArc(pageW / 2, margin.y + 18, 16, dsp.confidence_score);
    margin.y += 42;
    if (dsp.confidence_justification) {
      doc.setFontSize(7);
      doc.setTextColor(...t.muted);
      const justLines = doc.splitTextToSize(dsp.confidence_justification, 120);
      for (const l of justLines) {
        doc.text(l, pageW / 2, margin.y, { align: 'center' });
        margin.y += 3.5;
      }
    }
    margin.y += 6;
  }

  if (mode !== 'esoteric' && dsp.classification) {
    doc.setFontSize(7);
    doc.setTextColor(...t.muted);
    doc.text('CLASSIFICATION', pageW / 2, margin.y, { align: 'center' });
    margin.y += 6;
    doc.setFontSize(14);
    doc.setTextColor(...t.accent);
    doc.text(dsp.classification, pageW / 2, margin.y, { align: 'center' });
    margin.y += 12;
  }

  doc.setDrawColor(...t.border);
  doc.setLineWidth(0.3);
  doc.line(pageW / 2 - 30, margin.y, pageW / 2 + 30, margin.y);
  margin.y += 8;

  doc.setFontSize(7);
  doc.setTextColor(...t.muted);
  const modeLabel = mode === 'merged' ? 'UNIFIED DOSSIER — DSP + CP-012 ESOTERIC'
    : mode === 'esoteric' ? 'CP-012-O-D-ESP ESOTERIC INTELLIGENCE'
    : 'DEFINITIVE SUBJECT PROFILE';
  doc.text(modeLabel, pageW / 2, margin.y, { align: 'center' });

  // ── DSP CONTENT ────────────────────────────────────────────────────────
  if (mode !== 'esoteric') {
    doc.addPage();
    drawPageBg();
    margin.y = 20;

    sectionHeader('■', 'EXECUTIVE SUMMARY', t.accent);
    wrappedText(dsp.executive_summary || 'No summary available.');
    margin.y += 4;

    sectionHeader('◆', 'PERSONALITY MATRIX', t.violet);
    const traits = ['openness', 'conscientiousness', 'extraversion', 'agreeableness', 'neuroticism'];
    const traitLabels = {
      openness: 'Openness', conscientiousness: 'Conscientiousness', extraversion: 'Extraversion',
      agreeableness: 'Agreeableness', neuroticism: 'Neuroticism',
    };
    for (const trait of traits) {
      const data = dsp.personality_matrix?.[trait] ?? {};
      const score = data.score ?? 50;
      const barColor = score >= 70 ? t.green : score >= 40 ? t.accent : t.rose;
      ensureSpace(22);
      doc.setFontSize(10);
      doc.setTextColor(...t.title);
      doc.text(traitLabels[trait], margin.left, margin.y);
      doc.setTextColor(...t.muted);
      doc.text(`${score}%`, margin.left + contentW, margin.y, { align: 'right' });
      margin.y += 4;
      drawBar(margin.left, margin.y, contentW, score, barColor);
      margin.y += 5;
      if (data.evidence) {
        doc.setFontSize(7);
        doc.setTextColor(...t.muted);
        const evLines = doc.splitTextToSize(`"${data.evidence}"`, contentW);
        for (const l of evLines) { doc.text(l, margin.left, margin.y); margin.y += 3; }
      }
      if (Array.isArray(data.indicators)) {
        doc.setFontSize(7);
        doc.setTextColor(...t.muted);
        for (const ind of data.indicators) {
          ensureSpace(4);
          doc.text(`• ${ind}`, margin.left + 2, margin.y);
          margin.y += 3.5;
        }
      }
      margin.y += 3;
    }

    sectionHeader('◆', 'COGNITIVE ARCHITECTURE', t.violet);
    const cogArch = dsp.cognitive_architecture ?? {};
    const cogFields = [
      ['THINKING STYLE', cogArch.thinking_style],
      ['EPISTEMIC REQUIREMENTS', cogArch.epistemic_requirements],
      ['DEFENSE MECHANISMS', cogArch.defense_mechanisms],
    ];
    for (const [label, val] of cogFields) {
      if (!val) continue;
      ensureSpace(10);
      doc.setFontSize(7);
      doc.setTextColor(...t.muted);
      doc.text(label, margin.left, margin.y);
      margin.y += 4;
      wrappedText(val);
    }
    if (Array.isArray(cogArch.sub_sections)) {
      for (const sub of cogArch.sub_sections) {
        ensureSpace(10);
        doc.setFontSize(7);
        doc.setTextColor(...t.muted);
        doc.text((sub.title || '').toUpperCase(), margin.left, margin.y);
        margin.y += 4;
        wrappedText(sub.content);
      }
    }

    if (Array.isArray(dsp.behavioral_patterns) && dsp.behavioral_patterns.length) {
      sectionHeader('▸', 'BEHAVIORAL PATTERNS', t.green);
      for (const pat of dsp.behavioral_patterns) {
        ensureSpace(18);
        doc.setFontSize(9);
        doc.setTextColor(...t.accent);
        doc.text(pat.label ?? '', margin.left, margin.y);
        margin.y += 4;
        wrappedText(pat.description);
        if (pat.context) {
          doc.setFontSize(7);
          doc.setTextColor(...t.muted);
          const ctxLines = doc.splitTextToSize(pat.context, contentW);
          for (const l of ctxLines) {
            ensureSpace(4);
            doc.text(l, margin.left, margin.y);
            margin.y += 3.5;
          }
          margin.y += 2;
        }
      }
    }

    if (Array.isArray(dsp.action_response_matrix) && dsp.action_response_matrix.length) {
      sectionHeader('▸', 'PREDICTIVE MODEL', t.green);
      for (const pred of dsp.action_response_matrix) {
        const trigger = pred.trigger || pred.scenario || '';
        const behavior = pred.predicted_behavior || pred.response || '';
        const prob = pred.probability ?? 75;
        const probColor = prob >= 80 ? t.green : prob >= 60 ? t.accent : t.rose;
        ensureSpace(24);
        doc.setFontSize(7);
        doc.setTextColor(...t.accent);
        doc.text('TRIGGER', margin.left, margin.y);
        margin.y += 3.5;
        wrappedText(trigger, { fontSize: 8 });
        doc.setFontSize(7);
        doc.setTextColor(...t.green);
        doc.text('PREDICTED BEHAVIOR', margin.left, margin.y);
        margin.y += 3.5;
        wrappedText(behavior, { fontSize: 8 });
        doc.setFontSize(8);
        doc.setTextColor(...probColor);
        doc.text(`Probability: ${prob}%`, margin.left, margin.y);
        if (pred.confidence_interval) {
          doc.setTextColor(...t.muted);
          doc.text(`  CI: [${pred.confidence_interval.lower ?? 0}%, ${pred.confidence_interval.upper ?? 0}%]`, margin.left + 35, margin.y);
        }
        margin.y += 4;
        drawBar(margin.left, margin.y, 80, prob, probColor);
        margin.y += 6;
        if (pred.temporal_factors) {
          doc.setFontSize(7);
          doc.setTextColor(...t.violet);
          doc.text('TEMPORAL: ', margin.left, margin.y);
          doc.setTextColor(...t.muted);
          const tfLines = doc.splitTextToSize(pred.temporal_factors, contentW - 20);
          doc.text(tfLines[0] ?? '', margin.left + 18, margin.y);
          margin.y += 4;
        }
        margin.y += 2;
      }
    }

    const hasMot = Array.isArray(dsp.motivations) && dsp.motivations.length;
    const hasFears = Array.isArray(dsp.fears) && dsp.fears.length;
    if (hasMot || hasFears) {
      sectionHeader('◉', 'CORE DRIVERS', t.green);
      if (hasMot) {
        doc.setFontSize(8);
        doc.setTextColor(...t.green);
        doc.text('MOTIVATIONS', margin.left, margin.y);
        margin.y += 4;
        for (const m of dsp.motivations) {
          ensureSpace(4);
          doc.setFontSize(8);
          doc.setTextColor(...t.text);
          doc.text(`▸ ${m}`, margin.left + 2, margin.y);
          margin.y += 4;
        }
        margin.y += 2;
      }
      if (hasFears) {
        doc.setFontSize(8);
        doc.setTextColor(...t.rose);
        doc.text('FEARS', margin.left, margin.y);
        margin.y += 4;
        for (const f of dsp.fears) {
          ensureSpace(4);
          doc.setFontSize(8);
          doc.setTextColor(...t.text);
          doc.text(`▸ ${f}`, margin.left + 2, margin.y);
          margin.y += 4;
        }
        margin.y += 2;
      }
    }

    if (dsp.final_assessment) {
      sectionHeader('■', 'FINAL ASSESSMENT', t.accent);
      wrappedText(dsp.final_assessment);
    }

    if (Array.isArray(payload.conflicts_detected) && payload.conflicts_detected.length) {
      sectionHeader('⚠', 'ANALYSIS CONFLICTS', t.rose);
      for (const cf of payload.conflicts_detected) {
        ensureSpace(8);
        wrappedText(cf.description, { color: t.rose, fontSize: 8 });
        if (cf.resolution) {
          wrappedText(`Resolution: ${cf.resolution}`, { color: t.muted, fontSize: 7 });
        }
      }
    }
  }

  // ── ESOTERIC CONTENT ───────────────────────────────────────────────────
  if ((mode === 'esoteric' || mode === 'merged') && esp) {
    doc.addPage();
    drawPageBg();
    margin.y = 20;

    if (mode === 'merged') {
      margin.y = 60;
      doc.setFontSize(8);
      doc.setTextColor(...t.muted);
      doc.text('SUPPLEMENTARY LAYER', pageW / 2, margin.y, { align: 'center' });
      margin.y += 8;
      doc.setFontSize(16);
      doc.setTextColor(...t.violet);
      doc.text('Esoteric Intelligence Profile', pageW / 2, margin.y, { align: 'center' });
      margin.y += 6;
      doc.setFontSize(8);
      doc.setTextColor(...t.muted);
      doc.text('CP-012-O-D-ESP', pageW / 2, margin.y, { align: 'center' });
      margin.y += 5;
      doc.setTextColor(...t.muted);
      doc.text(`Fidelity: ${esp.input_fidelity ?? 'N/A'}  •  Status: ${esp.execution_status ?? 'N/A'}  •  Executed: ${esp.date_executed ?? 'N/A'}`, pageW / 2, margin.y, { align: 'center' });
      margin.y += 14;
      doc.addPage();
      drawPageBg();
      margin.y = 20;
    } else {
      doc.setFontSize(7);
      doc.setTextColor(...t.muted);
      doc.text(`Fidelity: ${esp.input_fidelity ?? 'N/A'}  •  Status: ${esp.execution_status ?? 'N/A'}  •  Executed: ${esp.date_executed ?? 'N/A'}`, margin.left, margin.y);
      margin.y += 8;
    }

    const espSections = [
      ['✦', 'ESOTERIC INQUIRY FRAME', esp.inquiry_frame, t.violet],
      ['☉', 'ASTROLOGICAL INTERPRETATION (NODE ALPHA)', esp.astrological_interpretation, t.accent],
      ['#', 'NUMEROLOGICAL INTERPRETATION (NODE BETA)', esp.numerological_interpretation, t.cyan],
      ['◈', 'UNIFIED EMOTIONAL SYNTHESIS', esp.unified_emotional_synthesis, t.violet],
      ['↗', 'THRESHOLD ASSESSMENT', esp.threshold_assessment, t.accent],
      ['→', 'STRATEGIC TRANSLATION', esp.strategic_translation, t.green],
      ['⚠', 'LIMITATION STATEMENT', esp.limitation_statement, t.muted],
    ];
    for (const [icon, title, content, color] of espSections) {
      if (!content) continue;
      sectionHeader(icon, title, color);
      wrappedText(content);
      margin.y += 3;
    }

    if (esp.sme_validation) {
      sectionHeader('✓', 'SME VALIDATION CHECK', t.green);
      const checks = [
        ['Astrology Governed Timing', esp.sme_validation.astrology_governed_timing],
        ['Numerology Governed Structure', esp.sme_validation.numerology_governed_structure],
        ['Emotional Depth Prioritized', esp.sme_validation.emotional_depth_prioritized],
        ['Practical Translation Achieved', esp.sme_validation.practical_translation_achieved],
        ['Generic Horoscope Drift Avoided', esp.sme_validation.generic_horoscope_drift_avoided],
      ];
      for (const [label, val] of checks) {
        ensureSpace(5);
        const passed = val === true;
        doc.setFontSize(8);
        doc.setTextColor(...(passed ? t.green : t.rose));
        doc.text(passed ? '✓' : '✗', margin.left, margin.y);
        doc.setTextColor(...t.text);
        doc.text(label, margin.left + 6, margin.y);
        margin.y += 5;
      }
      margin.y += 2;
      doc.setFontSize(8);
      doc.setTextColor(...t.muted);
      doc.text(`Execution Status: ${esp.sme_validation.execution_status ?? 'N/A'}`, margin.left, margin.y);
      margin.y += 6;
    }
  }

  // ── FOOTER ────────────────────────────────────────────────────────────
  const totalPages = doc.internal.pages.length - 1;
  for (let i = 1; i <= totalPages; i++) {
    doc.setPage(i);
    const pH = doc.internal.pageSize.getHeight();
    doc.setFontSize(6);
    doc.setTextColor(...t.muted);
    doc.text('APOLLO PROFILING ENGINE • CONFIDENTIAL', pageW / 2, pH - 8, { align: 'center' });
    doc.text(`Page ${i} of ${totalPages}`, pageW / 2, pH - 4, { align: 'center' });
  }

  return doc.output('blob');
}
