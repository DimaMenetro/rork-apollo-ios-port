# Apollo Engine — Native iOS port with Liquid Glass, zero-regression backend

## Goal

Convert the Apollo Profiling Engine web app into a polished native iOS app. **Backend logic is preserved exactly** — same models, same prompts, same outputs as the Base44 functions today. The iOS app adds Liquid Glass UX, offline caching, and CloudKit sync.

## How the brain works (unchanged from today)

The four backend "functions" are reimplemented bit-for-bit, just hosted differently:

- **Esoteric profile generation** — Gemini 3 Flash, same 4 staggered prompts (Phase I–II, III–IV, V–VII, VIII), same pre-computed Personal Year math, same SME validation schema.
- **Dossier synthesis** — Claude Sonnet 4.6, same two parallel calls (narrative sections + convergence map), same MELLMA-style integrative-analyst system prompt.
- **Audio analysis** — Hume AI prosody + AssemblyAI universal-3-pro transcription, same polling and fallback behavior. The iOS app uploads the voice-memo/video file to a Cloudflare R2 bucket via a presigned URL, then hands the URL to the worker exactly like Base44 does.
- **PDF export** — same jsPDF layout (cover, confidence arc, personality bars, predictive model, ESP sections, SME validation, footer), in both dark and light themes. Runs on the worker so the PDF byte-for-byte matches today's output.

A small Cloudflare Worker holds the Hume + AssemblyAI keys, proxies LLM calls through Rork's AI proxy, and exposes presigned upload URLs. The Worker is the only server-side piece needed.

## Storage

- **CloudKit private database** stores every Subject record. Each user's dossiers sync across their own iPhone, iPad, and Mac silently.
- **SwiftData on-device mirror** caches all Subjects so the app opens instantly and is fully usable offline for reading, editing notes, and reviewing finished dossiers. Generations and audio analysis need internet (they always did).

## Authentication

- Sign in with Apple **and** Google, both via Rork Auth.
- First launch shows a Liquid Glass welcome screen with both buttons; account becomes the CloudKit identity owner.

## Features (full parity with the web app — 8 screens)

- **Dashboard** — Subject roster with status pills (intake / processing / review / finalized), DSP health dots, quick search, "+ New Subject" floating action.
- **Subject Intake** — Five evidence streams (text, audio, video, behavioral, handwriting) as drag-style upload cards. Files from Voice Memos / Photos / Files are imported via the standard iOS document picker and previewed inline.
- **Processing** — Live progress for each analysis module (stylometric, cognitive, psychomotor, affective, behavioral loop) with animated progress rings.
- **Subject Review** — Conflict detection panel, Big Five Personality Matrix with horizontal gauges, Action/Response Matrix with probability bars and confidence intervals, Motivations & Fears.
- **DSP Report** — Full Definitive Subject Profile with all visualizations (confidence arc, personality bars, behavioral pattern cards, predictive model).
- **Esoteric Profile** — Inputs form (birth name, DOB, place, time, mode, timeframe, focus), then the full CP-012 output with FidelityMeter, ThresholdPhaseArc, NodeConvergenceRadar (Alpha vs Beta overlay), CycleTimeline (9-year curve), ValidationDashboard, and the Text↔Visual toggle per section.
- **Unified Dossier** — "Synthesize" button (with staleness indicator if DSP or ESP changed after last synthesis), the six unified narrative sections, convergence/divergence map as an interactive radar, final unified assessment.
- **Reports** — Export center with light/dark theme picker and three export modes (DSP / Esoteric / Merged); generates the PDF, then offers Save to Files, Share Sheet, or AirDrop.

## Design — Liquid Glass, 2026 best practices

- **Atmosphere** — Each screen sits over an animated gradient backdrop with a soft accent orb that drifts behind the content (carried over from the web app's signature look). Orb color shifts per section: amber on DSP, violet on Esoteric, cyan on Unified, green on Reports.
- **Light & dark** — Full support for both. The orbs, glass tints, and divider weights are tuned per mode so neither feels like an inverted copy.
- **Glass containers** — Cards, navigation bars, tab bar, and modal sheets use the new iOS 26 `glassEffect` with `GlassEffectContainer` so neighboring glass surfaces refract together instead of stacking. iOS 18 fallback uses `.ultraThinMaterial`.
- **Morphing transitions** — Section toggles (Text↔Visual), tab switches, and the "Synthesize Dossier" reveal use matched-geometry glass morphs so a tapped chip visibly expands into the panel it opens.
- **Tactility** — Every primary action returns a haptic; long-press on a Subject card opens a glass context menu with quick actions (Open Review, Export PDF, Delete). Chart values count up on appearance with a spring; gauges fill with a one-shot ease curve.
- **Typography** — SF Pro Display for titles, SF Mono for data labels (document IDs, scores, protocol tags) — preserves the "intelligence-analyst" character without going generic.
- **Navigation** — NavigationStack with type-safe destinations, plus a glass tab bar (Dashboard, Subjects, Reports, Settings). Detail sheets use `presentationDetents` so the radar/timeline can be peeked without leaving the dossier.
- **Charts** — Native Swift Charts for the personality matrix, predictive bars, cycle timeline, and convergence radar; custom Canvas drawing for the threshold-phase arc and confidence ring to match the web aesthetic exactly.
- **App icon** — Layered icon: deep midnight backdrop, a luminous amber orb at top-left bleeding into a thin violet ring around a stylized "A" mark — readable on both light and dark home screens, hints at the dual-lens (empirical + esoteric) concept.

## What survives unchanged from your current implementation

- Subject entity schema (all DSP, ESP, unified_dossier, esoteric_inputs fields).
- Every prompt string, model selection, and call sequencing in the four functions.
- PDF cover layout, confidence arc geometry, personality-bar palette, ESP section ordering, SME validation checks, footer.
- Phase tracker semantics (intake → processing → review → finalized) and DSP health states.

## What gets better

- Instant launch + offline browsing via SwiftData cache.
- CloudKit sync across the user's Apple devices.
- Native share sheet, AirDrop, Files-app integration for evidence import and PDF export.
- Haptics + spring animations on every state change.
- Per-section glass morphs that make the Text↔Visual toggle feel physical.
- Background generation: kick off Esoteric or Dossier synthesis, lock the phone, get a notification when it completes  



 •••If feasible within this implementation pass, include an adaptive iPad-specific layout as part of the native iOS build: not a separate app, but a responsive iPad UI using split views, larger report/detail panels, and better use of horizontal space while preserving the same core logic, screens, and workflow.•••

## Out of scope for v1

- Apple Watch 
- Widgets and Live Activities (good v1.1 additions for "synthesis in progress").
- Real-time collaboration between operators.

## Next step after approval

Scaffold the Xcode project, set up CloudKit + Rork Auth, build the Worker, wire the four backend calls, then assemble the eight screens in the order they're used in a real session: Intake → Processing → Review → DSP → Esoteric → Unified → Reports → Dashboard polish.