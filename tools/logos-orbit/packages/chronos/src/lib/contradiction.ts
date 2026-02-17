/**
 * Rationale contradiction detection.
 *
 * Scans a window of actions for contradictory rationale patterns:
 * - "not X" vs "X" on the same target
 * - "revert" patterns on the same target
 */

import type { ActionRecord } from "@logos-orbit/shared";

export interface ContradictionPair {
  actionA: string; // action ID
  actionB: string; // action ID
  contradiction: string; // description
}

/**
 * Detect rationale contradictions within a list of actions.
 *
 * Checks for:
 * 1. "not X" vs "X" patterns: one action's rationale negates another's on the same target
 * 2. "revert" patterns: an action explicitly reverts a previous change to the same target
 */
export function detectRationaleContradictions(
  actions: ActionRecord[]
): ContradictionPair[] {
  const contradictions: ContradictionPair[] = [];

  for (let i = 0; i < actions.length; i++) {
    for (let j = i + 1; j < actions.length; j++) {
      const a = actions[i];
      const b = actions[j];

      // Only compare actions on the same target
      if (a.target !== b.target) continue;

      const aRationale = a.rationale.toLowerCase();
      const bRationale = b.rationale.toLowerCase();

      // Check "not X" vs "X" pattern
      const negationResult = checkNegationPattern(a, b, aRationale, bRationale);
      if (negationResult) {
        contradictions.push(negationResult);
        continue;
      }

      // Check "revert" pattern
      const revertResult = checkRevertPattern(a, b, aRationale, bRationale);
      if (revertResult) {
        contradictions.push(revertResult);
      }
    }
  }

  return contradictions;
}

function checkNegationPattern(
  a: ActionRecord,
  b: ActionRecord,
  aLower: string,
  bLower: string
): ContradictionPair | null {
  // Extract key phrases and check if one negates the other
  const negationPrefixes = ["not ", "don't ", "do not ", "should not ", "shouldn't ", "never "];

  for (const prefix of negationPrefixes) {
    // Check if A says "not X" and B says "X" (or vice versa)
    if (aLower.includes(prefix)) {
      const negatedPart = extractAfterPrefix(aLower, prefix);
      if (negatedPart && bLower.includes(negatedPart)) {
        return {
          actionA: a.id,
          actionB: b.id,
          contradiction: `Negation conflict on "${a.target}": "${a.rationale}" vs "${b.rationale}"`,
        };
      }
    }

    if (bLower.includes(prefix)) {
      const negatedPart = extractAfterPrefix(bLower, prefix);
      if (negatedPart && aLower.includes(negatedPart)) {
        return {
          actionA: a.id,
          actionB: b.id,
          contradiction: `Negation conflict on "${a.target}": "${a.rationale}" vs "${b.rationale}"`,
        };
      }
    }
  }

  return null;
}

function checkRevertPattern(
  a: ActionRecord,
  b: ActionRecord,
  aLower: string,
  bLower: string
): ContradictionPair | null {
  const revertKeywords = ["revert", "undo", "rollback", "roll back", "restore previous"];

  for (const keyword of revertKeywords) {
    if (bLower.includes(keyword)) {
      return {
        actionA: a.id,
        actionB: b.id,
        contradiction: `Revert pattern on "${a.target}": "${b.rationale}" appears to revert "${a.rationale}"`,
      };
    }
    if (aLower.includes(keyword)) {
      return {
        actionA: a.id,
        actionB: b.id,
        contradiction: `Revert pattern on "${b.target}": "${a.rationale}" appears to revert "${b.rationale}"`,
      };
    }
  }

  return null;
}

/**
 * Extract a meaningful phrase after a negation prefix.
 * Returns at least 4 chars to avoid false positives on short words.
 */
function extractAfterPrefix(text: string, prefix: string): string | null {
  const idx = text.indexOf(prefix);
  if (idx === -1) return null;

  const after = text.slice(idx + prefix.length).trim();
  // Take the first phrase (up to punctuation or end)
  const phrase = after.split(/[.,;!?]/, 1)[0].trim();

  // Require minimum length to avoid false positives
  return phrase.length >= 4 ? phrase : null;
}
