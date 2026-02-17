import { z } from "zod";

// ── Proposition ──────────────────────────────────────────────────────────

export const PropositionSchema = z
  .object({
    statement: z.string().min(1, "statement must not be empty"),
    source: z.enum(["observed", "assumed", "derived"]),
    timestamp: z.string().datetime(),
  })
  .strict(); // rejects confidence, certainty, belief, etc.

export type Proposition = z.infer<typeof PropositionSchema>;

// ── Penalty ──────────────────────────────────────────────────────────────

export const PENALTY_TYPES = [
  "CONTRADICTORY_PREMISES",
  "UNSUPPORTED_CONCLUSION",
  "TEMPORAL_CONTRADICTION",
  "CONCEPT_LEAP",
  "CIRCULAR_REASONING",
  "UNGROUNDED_ASSUMPTION",
] as const;

export const PenaltyTypeEnum = z.enum(PENALTY_TYPES);
export type PenaltyType = z.infer<typeof PenaltyTypeEnum>;

export const PenaltySchema = z.object({
  type: PenaltyTypeEnum,
  weight: z.number().min(0).max(1),
  description: z.string().min(1),
  timestamp: z.string().datetime(),
});

export type Penalty = z.infer<typeof PenaltySchema>;

export const PENALTY_WEIGHTS: Readonly<Record<PenaltyType, number>> =
  Object.freeze({
    CONTRADICTORY_PREMISES: 0.5,
    UNSUPPORTED_CONCLUSION: 0.3,
    TEMPORAL_CONTRADICTION: 0.25,
    CONCEPT_LEAP: 0.2,
    CIRCULAR_REASONING: 0.15,
    UNGROUNDED_ASSUMPTION: 0.1,
  });

// ── Contradiction ────────────────────────────────────────────────────────

export const ContradictionSchema = z.object({
  id: z.string().uuid(),
  propositionA: PropositionSchema,
  propositionB: PropositionSchema,
  detectedAt: z.string().datetime(),
  resolved: z.boolean(),
  resolution: z.string().optional(),
});

export type Contradiction = z.infer<typeof ContradictionSchema>;

// ── Action Record ────────────────────────────────────────────────────────

export const ActionRecordSchema = z.object({
  id: z.string(),
  timestamp: z.string(),
  actionType: z.enum(["search", "edit", "read", "write", "verify", "plan", "ask"]),
  target: z.string().min(1),
  intent: z.string().min(10),
  rationale: z.string().min(10),
}).strict();

export type ActionRecord = z.infer<typeof ActionRecordSchema>;

// ── Drift Warning ────────────────────────────────────────────────────────

export const DriftWarningSchema = z.object({
  timestamp: z.string(),
  entropy: z.number().min(0).max(1),
  message: z.string(),
  severity: z.enum(["WARNING", "HARD_STOP"]),
}).strict();

export type DriftWarning = z.infer<typeof DriftWarningSchema>;

// ── Rule ─────────────────────────────────────────────────────────────────

export const RuleSchema = z.object({
  id: z.string(),
  createdAt: z.string(),
  createdFrom: z.string().min(1),
  condition: z.string().min(1),
  severity: z.enum(["error", "warning"]),
  message: z.string().min(1),
  evidence: z.string(),
  tags: z.array(z.string()),
}).strict();

export type Rule = z.infer<typeof RuleSchema>;

// ── Tattoo ───────────────────────────────────────────────────────────────

export const TattooSchema = z.object({
  id: z.string(),
  targetFile: z.string().min(1),
  content: z.string().min(1),
  position: z.enum(["append", "section"]),
  sectionName: z.string().optional(),
  justification: z.string().min(1),
  createdAt: z.string(),
}).strict();

export type Tattoo = z.infer<typeof TattooSchema>;

// ── Alert ────────────────────────────────────────────────────────────────

export const AlertSchema = z.object({
  id: z.string().uuid(),
  level: z.enum(["info", "warning", "critical"]),
  message: z.string().min(1),
  source: z.enum(["integrity", "chronos", "nomos"]),
  timestamp: z.string().datetime(),
  dismissed: z.boolean(),
});

export type Alert = z.infer<typeof AlertSchema>;

// ── Logos Status (top-level document) ────────────────────────────────────

export const LogosStatusSchema = z.object({
  integrity: z.object({
    score: z.number().min(0).max(1),
    penalties: z.array(PenaltySchema),
    contradictions: z.array(ContradictionSchema),
    lastCheck: z.string().datetime(),
  }),
  chronos: z.object({
    actions: z.array(ActionRecordSchema),
    driftWarnings: z.array(DriftWarningSchema),
    lastCheck: z.string().datetime(),
  }),
  nomos: z.object({
    activeRules: z.array(RuleSchema),
    pendingTattoos: z.array(TattooSchema),
    totalRulesGenerated: z.number().int().min(0),
    lastFailureAnalysis: z.object({
      timestamp: z.string(),
      failureType: z.string(),
      generatedRule: z.string(),
    }).nullable(),
  }),
  orbit: z.object({
    consensusState: z.enum(["ALIGNED", "DIVERGENT", "HALTED"]),
    alerts: z.array(AlertSchema),
    lastSync: z.string().datetime(),
  }),
});

export type LogosStatus = z.infer<typeof LogosStatusSchema>;

// ── Factory ──────────────────────────────────────────────────────────────

export function createEmptyStatus(): LogosStatus {
  const now = new Date().toISOString();
  return {
    integrity: {
      score: 1.0,
      penalties: [],
      contradictions: [],
      lastCheck: now,
    },
    chronos: {
      actions: [],
      driftWarnings: [],
      lastCheck: now,
    },
    nomos: {
      activeRules: [],
      pendingTattoos: [],
      totalRulesGenerated: 0,
      lastFailureAnalysis: null,
    },
    orbit: {
      consensusState: "ALIGNED",
      alerts: [],
      lastSync: now,
    },
  };
}
