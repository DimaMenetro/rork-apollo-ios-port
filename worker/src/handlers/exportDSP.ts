/**
 * PDF export — direct port of base44/functions/exportDSP/entry.ts using jsPDF.
 * Preserves the same cover layout, confidence arc, personality bars, predictive
 * model, ESP sections, SME validation, and footer — in both dark and light themes.
 */
import { Context } from "hono";
import type { Env } from "../types";
import { jsPDF } from "jspdf";

type RGB = [number, number, number];
interface Theme {
  bg: RGB; cardBg: RGB; text: RGB; title: RGB; muted: RGB;
  accent: RGB; violet: RGB; green: RGB; rose: RGB; cyan: RGB;
  border: RGB; barTrack: RGB;
}

const THEMES: Record<"dark" | "light", Theme> = {
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

interface Margin { left: number; y: number }

function drawPageBg(doc: jsPDF, theme: Theme) {
  const w = doc.internal.pageSize.getWidth();
  const h = doc.internal.pageSize.getHeight();
  doc.setFillColor(...theme.bg);
  doc.rect(0, 0, w, h, "F");
}

function ensureSpace(doc: jsPDF, needed: number, theme: Theme, margin: Margin) {
  const pageH = doc.internal.pageSize.getHeight();
  if (margin.y + needed > pageH - 20) {
    doc.addPage();
    drawPageBg(doc, theme);
    margin.y = 20;
  }
}

function drawBar(doc: jsPDF, theme: Theme, x: number, y: number, w: number, score: number, color: RGB) {
  const h = 3;
  doc.setFillColor(...theme.barTrack);
  doc.roundedRect(x, y, w, h, 1.5, 1.5, "F");
  const fillW = Math.max(2, (score / 100) * w);
  doc.setFillColor(...color);
  doc.roundedRect(x, y, fillW, h, 1.5, 1.5, "F");
}

function drawConfidenceArc(doc: jsPDF, theme: Theme, cx: number, cy: number, radius: number, score: number) {
  doc.setDrawColor(...theme.border);
  doc.setLineWidth(2);
  doc.circle(cx, cy, radius, "S");
  const color: RGB = score >= 80 ? theme.green : score >= 60 ? theme.accent : theme.rose;
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
  doc.text(`${score}%`, cx, cy + 2, { align: "center" });
}

function sectionHeader(doc: jsPDF, theme: Theme, margin: Margin, icon: string, title: string, color: RGB) {
  ensureSpace(doc, 14, theme, margin);
  doc.setFontSize(8);
  doc.setTextColor(...color);
  doc.text(icon, margin.left, margin.y);
  doc.text(title.toUpperCase(), margin.left + 6, margin.y);
  margin.y += 8;
}

function wrappedText(doc: jsPDF, theme: Theme, margin: Margin, text: string, opts: { maxW?: number; fontSize?: number; color?: RGB; x?: number } = {}) {
  const maxW = opts.maxW ?? 170;
  const fontSize = opts.fontSize ?? 9;
  doc.setFontSize(fontSize);
  doc.setTextColor(...(opts.color ?? theme.text));
  const lines = doc.splitTextToSize(text || "", maxW) as string[];
  for (const line of lines) {
    ensureSpace(doc, 5, theme, margin);
    doc.text(line, opts.x ?? margin.left, margin.y);
    margin.y += fontSize * 0.45;
  }
  margin.y += 2;
}

export async function exportDSP(c: Context<{ Bindings: Env }>) {
  let body: { subject_id: string; mode?: "dsp" | "esoteric" | "merged"; color_theme?: "dark" | "light"; payload: any };
  try {
    body = await c.req.json();
  } catch {
    return c.json({ error: "Invalid JSON body" }, 400);
  }
  const { subject_id, payload } = body;
  const mode = body.mode ?? "dsp";
  const themeKey = body.color_theme ?? "dark";
  if (!subject_id || !payload) return c.json({ error: "subject_id and payload required" }, 400);

  const theme = THEMES[themeKey];
  const subject = payload as { name?: string; dsp?: any; esoteric_profile?: any; conflicts_detected?: any[] };
  const dsp = subject.dsp ?? {};
  const esp = subject.esoteric_profile ?? null;

  const doc = new jsPDF({ orientation: "portrait", unit: "mm", format: "a4" });
  const pageW = doc.internal.pageSize.getWidth();
  const margin: Margin = { left: 20, y: 20 };
  const contentW = pageW - 40;

  drawPageBg(doc, theme);

  // ── COVER ───────────────────────────────────────────────────────────────
  margin.y = 50;
  doc.setFontSize(10);
  doc.setTextColor(...theme.muted);
  doc.text("APOLLO PROFILING ENGINE", pageW / 2, margin.y, { align: "center" });
  margin.y += 12;

  doc.setFontSize(24);
  doc.setTextColor(...theme.title);
  const docTitle = mode === "esoteric" ? "Esoteric Intelligence Profile"
    : mode === "merged" ? "Unified Subject Dossier"
    : "Definitive Subject Profile";
  doc.text(docTitle, pageW / 2, margin.y, { align: "center" });
  margin.y += 10;

  doc.setFontSize(18);
  doc.setTextColor(...theme.accent);
  doc.text(subject.name ?? "Unknown", pageW / 2, margin.y, { align: "center" });
  margin.y += 16;

  const metaLines: Array<[string, string]> = [];
  if (dsp.document_id) metaLines.push(["DOCUMENT ID", dsp.document_id]);
  metaLines.push(["PROTOCOL", dsp.protocol_version ?? "CP-003-O-D-APL v2.1"]);
  metaLines.push(["DATE", dsp.date_of_synthesis ?? new Date().toISOString().split("T")[0]]);
  if (mode !== "dsp" && esp) metaLines.push(["ESOTERIC", "CP-012-O-D-ESP"]);

  for (const [label, val] of metaLines) {
    doc.setFontSize(7);
    doc.setTextColor(...theme.muted);
    doc.text(label, pageW / 2 - 30, margin.y);
    doc.setFontSize(9);
    doc.setTextColor(...theme.text);
    doc.text(val, pageW / 2 + 5, margin.y);
    margin.y += 6;
  }
  margin.y += 8;

  if (mode !== "esoteric" && dsp.confidence_score) {
    drawConfidenceArc(doc, theme, pageW / 2, margin.y + 18, 16, dsp.confidence_score);
    margin.y += 42;
    if (dsp.confidence_justification) {
      doc.setFontSize(7);
      doc.setTextColor(...theme.muted);
      const justLines = doc.splitTextToSize(dsp.confidence_justification, 120) as string[];
      for (const l of justLines) {
        doc.text(l, pageW / 2, margin.y, { align: "center" });
        margin.y += 3.5;
      }
    }
    margin.y += 6;
  }

  if (mode !== "esoteric" && dsp.classification) {
    doc.setFontSize(7);
    doc.setTextColor(...theme.muted);
    doc.text("CLASSIFICATION", pageW / 2, margin.y, { align: "center" });
    margin.y += 6;
    doc.setFontSize(14);
    doc.setTextColor(...theme.accent);
    doc.text(dsp.classification, pageW / 2, margin.y, { align: "center" });
    margin.y += 12;
  }

  doc.setDrawColor(...theme.border);
  doc.setLineWidth(0.3);
  doc.line(pageW / 2 - 30, margin.y, pageW / 2 + 30, margin.y);
  margin.y += 8;

  doc.setFontSize(7);
  doc.setTextColor(...theme.muted);
  const modeLabel = mode === "merged" ? "UNIFIED DOSSIER — DSP + CP-012 ESOTERIC"
    : mode === "esoteric" ? "CP-012-O-D-ESP ESOTERIC INTELLIGENCE"
    : "DEFINITIVE SUBJECT PROFILE";
  doc.text(modeLabel, pageW / 2, margin.y, { align: "center" });

  // ── DSP CONTENT ────────────────────────────────────────────────────────
  if (mode !== "esoteric") {
    doc.addPage();
    drawPageBg(doc, theme);
    margin.y = 20;

    sectionHeader(doc, theme, margin, "■", "EXECUTIVE SUMMARY", theme.accent);
    wrappedText(doc, theme, margin, dsp.executive_summary || "No summary available.");
    margin.y += 4;

    sectionHeader(doc, theme, margin, "◆", "PERSONALITY MATRIX", theme.violet);
    const traits = ["openness", "conscientiousness", "extraversion", "agreeableness", "neuroticism"] as const;
    const traitLabels: Record<typeof traits[number], string> = {
      openness: "Openness", conscientiousness: "Conscientiousness", extraversion: "Extraversion",
      agreeableness: "Agreeableness", neuroticism: "Neuroticism",
    };
    for (const trait of traits) {
      const data = dsp.personality_matrix?.[trait] ?? {};
      const score: number = data.score ?? 50;
      const barColor: RGB = score >= 70 ? theme.green : score >= 40 ? theme.accent : theme.rose;
      ensureSpace(doc, 22, theme, margin);
      doc.setFontSize(10);
      doc.setTextColor(...theme.title);
      doc.text(traitLabels[trait], margin.left, margin.y);
      doc.setTextColor(...theme.muted);
      doc.text(`${score}%`, margin.left + contentW, margin.y, { align: "right" });
      margin.y += 4;
      drawBar(doc, theme, margin.left, margin.y, contentW, score, barColor);
      margin.y += 5;
      if (data.evidence) {
        doc.setFontSize(7);
        doc.setTextColor(...theme.muted);
        const evLines = doc.splitTextToSize(`"${data.evidence}"`, contentW) as string[];
        for (const l of evLines) { doc.text(l, margin.left, margin.y); margin.y += 3; }
      }
      if (Array.isArray(data.indicators)) {
        doc.setFontSize(7);
        doc.setTextColor(...theme.muted);
        for (const ind of data.indicators) {
          ensureSpace(doc, 4, theme, margin);
          doc.text(`• ${ind}`, margin.left + 2, margin.y);
          margin.y += 3.5;
        }
      }
      margin.y += 3;
    }

    sectionHeader(doc, theme, margin, "◆", "COGNITIVE ARCHITECTURE", theme.violet);
    const cogArch = dsp.cognitive_architecture ?? {};
    const cogFields: Array<[string, string | undefined]> = [
      ["THINKING STYLE", cogArch.thinking_style],
      ["EPISTEMIC REQUIREMENTS", cogArch.epistemic_requirements],
      ["DEFENSE MECHANISMS", cogArch.defense_mechanisms],
    ];
    for (const [label, val] of cogFields) {
      if (!val) continue;
      ensureSpace(doc, 10, theme, margin);
      doc.setFontSize(7);
      doc.setTextColor(...theme.muted);
      doc.text(label, margin.left, margin.y);
      margin.y += 4;
      wrappedText(doc, theme, margin, val);
    }
    if (Array.isArray(cogArch.sub_sections)) {
      for (const sub of cogArch.sub_sections) {
        ensureSpace(doc, 10, theme, margin);
        doc.setFontSize(7);
        doc.setTextColor(...theme.muted);
        doc.text(((sub.title as string) || "").toUpperCase(), margin.left, margin.y);
        margin.y += 4;
        wrappedText(doc, theme, margin, sub.content as string);
      }
    }

    if (Array.isArray(dsp.behavioral_patterns) && dsp.behavioral_patterns.length) {
      sectionHeader(doc, theme, margin, "▸", "BEHAVIORAL PATTERNS", theme.green);
      for (const pat of dsp.behavioral_patterns) {
        ensureSpace(doc, 18, theme, margin);
        doc.setFontSize(9);
        doc.setTextColor(...theme.accent);
        doc.text(pat.label ?? "", margin.left, margin.y);
        margin.y += 4;
        wrappedText(doc, theme, margin, pat.description);
        if (pat.context) {
          doc.setFontSize(7);
          doc.setTextColor(...theme.muted);
          const ctxLines = doc.splitTextToSize(pat.context, contentW) as string[];
          for (const l of ctxLines) {
            ensureSpace(doc, 4, theme, margin);
            doc.text(l, margin.left, margin.y);
            margin.y += 3.5;
          }
          margin.y += 2;
        }
      }
    }

    if (Array.isArray(dsp.action_response_matrix) && dsp.action_response_matrix.length) {
      sectionHeader(doc, theme, margin, "▸", "PREDICTIVE MODEL", theme.green);
      for (const pred of dsp.action_response_matrix) {
        const trigger = pred.trigger || pred.scenario || "";
        const behavior = pred.predicted_behavior || pred.response || "";
        const prob = pred.probability ?? 75;
        const probColor: RGB = prob >= 80 ? theme.green : prob >= 60 ? theme.accent : theme.rose;
        ensureSpace(doc, 24, theme, margin);
        doc.setFontSize(7);
        doc.setTextColor(...theme.accent);
        doc.text("TRIGGER", margin.left, margin.y);
        margin.y += 3.5;
        wrappedText(doc, theme, margin, trigger, { fontSize: 8 });
        doc.setFontSize(7);
        doc.setTextColor(...theme.green);
        doc.text("PREDICTED BEHAVIOR", margin.left, margin.y);
        margin.y += 3.5;
        wrappedText(doc, theme, margin, behavior, { fontSize: 8 });
        doc.setFontSize(8);
        doc.setTextColor(...probColor);
        doc.text(`Probability: ${prob}%`, margin.left, margin.y);
        if (pred.confidence_interval) {
          doc.setTextColor(...theme.muted);
          doc.text(`  CI: [${pred.confidence_interval.lower ?? 0}%, ${pred.confidence_interval.upper ?? 0}%]`, margin.left + 35, margin.y);
        }
        margin.y += 4;
        drawBar(doc, theme, margin.left, margin.y, 80, prob, probColor);
        margin.y += 6;
        if (pred.temporal_factors) {
          doc.setFontSize(7);
          doc.setTextColor(...theme.violet);
          doc.text("TEMPORAL: ", margin.left, margin.y);
          doc.setTextColor(...theme.muted);
          const tfLines = doc.splitTextToSize(pred.temporal_factors, contentW - 20) as string[];
          doc.text(tfLines[0] ?? "", margin.left + 18, margin.y);
          margin.y += 4;
        }
        margin.y += 2;
      }
    }

    const hasMot = Array.isArray(dsp.motivations) && dsp.motivations.length;
    const hasFears = Array.isArray(dsp.fears) && dsp.fears.length;
    if (hasMot || hasFears) {
      sectionHeader(doc, theme, margin, "◉", "CORE DRIVERS", theme.green);
      if (hasMot) {
        doc.setFontSize(8);
        doc.setTextColor(...theme.green);
        doc.text("MOTIVATIONS", margin.left, margin.y);
        margin.y += 4;
        for (const m of dsp.motivations) {
          ensureSpace(doc, 4, theme, margin);
          doc.setFontSize(8);
          doc.setTextColor(...theme.text);
          doc.text(`▸ ${m}`, margin.left + 2, margin.y);
          margin.y += 4;
        }
        margin.y += 2;
      }
      if (hasFears) {
        doc.setFontSize(8);
        doc.setTextColor(...theme.rose);
        doc.text("FEARS", margin.left, margin.y);
        margin.y += 4;
        for (const f of dsp.fears) {
          ensureSpace(doc, 4, theme, margin);
          doc.setFontSize(8);
          doc.setTextColor(...theme.text);
          doc.text(`▸ ${f}`, margin.left + 2, margin.y);
          margin.y += 4;
        }
        margin.y += 2;
      }
    }

    if (dsp.final_assessment) {
      sectionHeader(doc, theme, margin, "■", "FINAL ASSESSMENT", theme.accent);
      wrappedText(doc, theme, margin, dsp.final_assessment);
    }

    if (Array.isArray(subject.conflicts_detected) && subject.conflicts_detected.length) {
      sectionHeader(doc, theme, margin, "⚠", "ANALYSIS CONFLICTS", theme.rose);
      for (const cf of subject.conflicts_detected) {
        ensureSpace(doc, 8, theme, margin);
        wrappedText(doc, theme, margin, cf.description, { color: theme.rose, fontSize: 8 });
        if (cf.resolution) {
          wrappedText(doc, theme, margin, `Resolution: ${cf.resolution}`, { color: theme.muted, fontSize: 7 });
        }
      }
    }
  }

  // ── ESOTERIC CONTENT ───────────────────────────────────────────────────
  if ((mode === "esoteric" || mode === "merged") && esp) {
    doc.addPage();
    drawPageBg(doc, theme);
    margin.y = 20;

    if (mode === "merged") {
      margin.y = 60;
      doc.setFontSize(8);
      doc.setTextColor(...theme.muted);
      doc.text("SUPPLEMENTARY LAYER", pageW / 2, margin.y, { align: "center" });
      margin.y += 8;
      doc.setFontSize(16);
      doc.setTextColor(...theme.violet);
      doc.text("Esoteric Intelligence Profile", pageW / 2, margin.y, { align: "center" });
      margin.y += 6;
      doc.setFontSize(8);
      doc.setTextColor(...theme.muted);
      doc.text("CP-012-O-D-ESP", pageW / 2, margin.y, { align: "center" });
      margin.y += 5;
      doc.setTextColor(...theme.muted);
      doc.text(`Fidelity: ${esp.input_fidelity ?? "N/A"}  •  Status: ${esp.execution_status ?? "N/A"}  •  Executed: ${esp.date_executed ?? "N/A"}`, pageW / 2, margin.y, { align: "center" });
      margin.y += 14;
      doc.addPage();
      drawPageBg(doc, theme);
      margin.y = 20;
    } else {
      doc.setFontSize(7);
      doc.setTextColor(...theme.muted);
      doc.text(`Fidelity: ${esp.input_fidelity ?? "N/A"}  •  Status: ${esp.execution_status ?? "N/A"}  •  Executed: ${esp.date_executed ?? "N/A"}`, margin.left, margin.y);
      margin.y += 8;
    }

    const espSections: Array<[string, string, string | undefined, RGB]> = [
      ["✦", "ESOTERIC INQUIRY FRAME", esp.inquiry_frame, theme.violet],
      ["☉", "ASTROLOGICAL INTERPRETATION (NODE ALPHA)", esp.astrological_interpretation, theme.accent],
      ["#", "NUMEROLOGICAL INTERPRETATION (NODE BETA)", esp.numerological_interpretation, theme.cyan],
      ["◈", "UNIFIED EMOTIONAL SYNTHESIS", esp.unified_emotional_synthesis, theme.violet],
      ["↗", "THRESHOLD ASSESSMENT", esp.threshold_assessment, theme.accent],
      ["→", "STRATEGIC TRANSLATION", esp.strategic_translation, theme.green],
      ["⚠", "LIMITATION STATEMENT", esp.limitation_statement, theme.muted],
    ];
    for (const [icon, title, content, color] of espSections) {
      if (!content) continue;
      sectionHeader(doc, theme, margin, icon, title, color);
      wrappedText(doc, theme, margin, content);
      margin.y += 3;
    }

    if (esp.sme_validation) {
      sectionHeader(doc, theme, margin, "✓", "SME VALIDATION CHECK", theme.green);
      const checks: Array<[string, boolean | undefined]> = [
        ["Astrology Governed Timing", esp.sme_validation.astrology_governed_timing],
        ["Numerology Governed Structure", esp.sme_validation.numerology_governed_structure],
        ["Emotional Depth Prioritized", esp.sme_validation.emotional_depth_prioritized],
        ["Practical Translation Achieved", esp.sme_validation.practical_translation_achieved],
        ["Generic Horoscope Drift Avoided", esp.sme_validation.generic_horoscope_drift_avoided],
      ];
      for (const [label, val] of checks) {
        ensureSpace(doc, 5, theme, margin);
        const passed = val === true;
        doc.setFontSize(8);
        doc.setTextColor(...(passed ? theme.green : theme.rose));
        doc.text(passed ? "✓" : "✗", margin.left, margin.y);
        doc.setTextColor(...theme.text);
        doc.text(label, margin.left + 6, margin.y);
        margin.y += 5;
      }
      margin.y += 2;
      doc.setFontSize(8);
      doc.setTextColor(...theme.muted);
      doc.text(`Execution Status: ${esp.sme_validation.execution_status ?? "N/A"}`, margin.left, margin.y);
      margin.y += 6;
    }
  }

  // ── FOOTER ────────────────────────────────────────────────────────────
  const totalPages = doc.internal.pages.length - 1; // jsPDF 1-based index
  for (let i = 1; i <= totalPages; i++) {
    doc.setPage(i);
    const pH = doc.internal.pageSize.getHeight();
    doc.setFontSize(6);
    doc.setTextColor(...theme.muted);
    doc.text("APOLLO PROFILING ENGINE • CONFIDENTIAL", pageW / 2, pH - 8, { align: "center" });
    doc.text(`Page ${i} of ${totalPages}`, pageW / 2, pH - 4, { align: "center" });
  }

  const pdfBytes = doc.output("arraybuffer");
  const filename = `${(subject.name ?? "subject").replace(/\s+/g, "_")}_${mode}_${new Date().toISOString().split("T")[0]}.pdf`;
  return new Response(pdfBytes, {
    status: 200,
    headers: {
      "Content-Type": "application/pdf",
      "Content-Disposition": `attachment; filename="${filename}"`,
    },
  });
}
