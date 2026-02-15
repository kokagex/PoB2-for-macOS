import {
  PENALTY_WEIGHTS,
  type Proposition,
  type Penalty,
  type PenaltyType,
} from "@logos-orbit/shared";

// ── Stopwords for token analysis ────────────────────────────────────────────

const STOPWORDS = new Set([
  "a", "an", "the", "is", "are", "was", "were", "be", "been", "being",
  "have", "has", "had", "do", "does", "did", "will", "would", "shall",
  "should", "may", "might", "must", "can", "could", "of", "in", "to",
  "for", "with", "on", "at", "from", "by", "about", "as", "into",
  "through", "during", "before", "after", "above", "below", "between",
  "and", "but", "or", "nor", "not", "so", "yet", "both", "either",
  "neither", "each", "every", "all", "any", "few", "more", "most",
  "other", "some", "such", "no", "only", "own", "same", "than", "too",
  "very", "just", "because", "if", "when", "while", "where", "how",
  "what", "which", "who", "whom", "this", "that", "these", "those",
  "it", "its", "i", "me", "my", "we", "our", "you", "your", "he",
  "him", "his", "she", "her", "they", "them", "their",
]);

// ── Helpers ─────────────────────────────────────────────────────────────────

function tokenize(text: string): string[] {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, " ")
    .split(/\s+/)
    .filter((t) => t.length > 0);
}

function contentTokens(text: string): string[] {
  return tokenize(text).filter((t) => !STOPWORDS.has(t));
}

function normalize(text: string): string {
  return tokenize(text).join(" ");
}

function makePenalty(type: PenaltyType, description: string): Penalty {
  return {
    type,
    weight: PENALTY_WEIGHTS[type],
    description,
    timestamp: new Date().toISOString(),
  };
}

// ── Penalty Detectors ───────────────────────────────────────────────────────

function detectContradictoryPremises(premises: Proposition[]): Penalty | null {
  const normalized = premises.map((p) => normalize(p.statement));

  for (let i = 0; i < normalized.length; i++) {
    for (let j = i + 1; j < normalized.length; j++) {
      const a = normalized[i];
      const b = normalized[j];

      // "X" vs "not X"
      if (a === `not ${b}` || b === `not ${a}`) {
        return makePenalty(
          "CONTRADICTORY_PREMISES",
          `Premise "${premises[i].statement}" contradicts "${premises[j].statement}"`
        );
      }

      // "X is Y" vs "X is not Y"
      const isPatternA = a.match(/^(.+?) is (.+)$/);
      const isPatternB = b.match(/^(.+?) is (.+)$/);
      if (isPatternA && isPatternB && isPatternA[1] === isPatternB[1]) {
        const valA = isPatternA[2];
        const valB = isPatternB[2];
        if (valA === `not ${valB}` || valB === `not ${valA}`) {
          return makePenalty(
            "CONTRADICTORY_PREMISES",
            `Premise "${premises[i].statement}" contradicts "${premises[j].statement}"`
          );
        }
      }
    }
  }

  return null;
}

function detectConceptLeap(
  premises: Proposition[],
  conclusion: Proposition
): Penalty | null {
  const premiseTokens = new Set(
    premises.flatMap((p) => contentTokens(p.statement))
  );
  const conclusionTokens = contentTokens(conclusion.statement);

  if (conclusionTokens.length === 0) return null;

  const novelCount = conclusionTokens.filter(
    (t) => !premiseTokens.has(t)
  ).length;
  const novelRatio = novelCount / conclusionTokens.length;

  if (novelRatio > 0.5) {
    return makePenalty(
      "CONCEPT_LEAP",
      `Over ${Math.round(novelRatio * 100)}% of conclusion tokens are not found in premises`
    );
  }

  return null;
}

function detectCircularReasoning(
  premises: Proposition[],
  conclusion: Proposition
): Penalty | null {
  const normConclusion = normalize(conclusion.statement);

  for (const premise of premises) {
    const normPremise = normalize(premise.statement);
    if (normPremise.includes(normConclusion) || normConclusion === normPremise) {
      return makePenalty(
        "CIRCULAR_REASONING",
        `Conclusion "${conclusion.statement}" is already stated in a premise`
      );
    }
  }

  return null;
}

function detectUngroundedAssumption(premises: Proposition[]): Penalty | null {
  if (premises.length === 0) return null;

  const assumedCount = premises.filter(
    (p) => p.source === "assumed"
  ).length;
  const ratio = assumedCount / premises.length;

  if (ratio > 0.5) {
    return makePenalty(
      "UNGROUNDED_ASSUMPTION",
      `${assumedCount}/${premises.length} premises are ungrounded (assumed/premise source)`
    );
  }

  return null;
}

function detectTemporalContradiction(
  conclusion: Proposition,
  priorConclusions: Proposition[]
): Penalty | null {
  const normConclusion = normalize(conclusion.statement);

  for (const prior of priorConclusions) {
    const normPrior = normalize(prior.statement);

    // "X" vs "not X"
    if (
      normConclusion === `not ${normPrior}` ||
      normPrior === `not ${normConclusion}`
    ) {
      return makePenalty(
        "TEMPORAL_CONTRADICTION",
        `Conclusion "${conclusion.statement}" contradicts prior conclusion "${prior.statement}"`
      );
    }

    // "X is Y" vs "X is not Y"
    const isPatternC = normConclusion.match(/^(.+?) is (.+)$/);
    const isPatternP = normPrior.match(/^(.+?) is (.+)$/);
    if (isPatternC && isPatternP && isPatternC[1] === isPatternP[1]) {
      const valC = isPatternC[2];
      const valP = isPatternP[2];
      if (valC === `not ${valP}` || valP === `not ${valC}`) {
        return makePenalty(
          "TEMPORAL_CONTRADICTION",
          `Conclusion "${conclusion.statement}" contradicts prior conclusion "${prior.statement}"`
        );
      }
    }
  }

  return null;
}

// ── Public API ──────────────────────────────────────────────────────────────

export function detectPenalties(
  premises: Proposition[],
  conclusion: Proposition,
  priorConclusions: Proposition[]
): Penalty[] {
  const penalties: Penalty[] = [];

  const contradictory = detectContradictoryPremises(premises);
  if (contradictory) penalties.push(contradictory);

  const conceptLeap = detectConceptLeap(premises, conclusion);
  if (conceptLeap) penalties.push(conceptLeap);

  const circular = detectCircularReasoning(premises, conclusion);
  if (circular) penalties.push(circular);

  const ungrounded = detectUngroundedAssumption(premises);
  if (ungrounded) penalties.push(ungrounded);

  const temporal = detectTemporalContradiction(conclusion, priorConclusions);
  if (temporal) penalties.push(temporal);

  return penalties;
}

export function calculateConfidence(penalties: Penalty[]): number {
  const totalWeight = penalties.reduce((sum, p) => sum + p.weight, 0);
  return Math.max(0, 1.0 - totalWeight);
}

export function determineVerdict(
  confidence: number
): "PASS" | "WARN" | "FAIL" {
  if (confidence >= 0.7) return "PASS";
  if (confidence >= 0.4) return "WARN";
  return "FAIL";
}
