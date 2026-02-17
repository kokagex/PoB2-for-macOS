/**
 * Entropy and stutter detection for Chronos drift monitoring.
 *
 * C-C2: Thresholds are frozen constants.
 */

import type { ActionRecord } from "@logos-orbit/shared";

/** C-C2: Fixed entropy thresholds — never modified at runtime. */
export const ENTROPY_THRESHOLDS = Object.freeze({
  HARD_STOP: 0.8,
  WARNING: 0.6,
} as const);

/**
 * Shannon entropy of action-type distribution, normalized to [0, 1].
 *
 * - Empty array -> 0
 * - Single type -> 0
 * - Uniform distribution across all types -> ~1.0
 *
 * H = -Sum( p(type) * log2(p(type)) ), normalized by log2(uniqueTypes)
 */
export function calculateEntropy(actions: ActionRecord[]): number {
  if (actions.length === 0) return 0;

  const counts = new Map<string, number>();
  for (const action of actions) {
    counts.set(action.actionType, (counts.get(action.actionType) || 0) + 1);
  }

  const uniqueTypes = counts.size;
  if (uniqueTypes <= 1) return 0;

  const total = actions.length;
  let entropy = 0;
  for (const count of counts.values()) {
    const p = count / total;
    if (p > 0) {
      entropy -= p * Math.log2(p);
    }
  }

  // Normalize by log2(uniqueTypes) to get [0, 1]
  return entropy / Math.log2(uniqueTypes);
}

export interface StutterResult {
  detected: boolean;
  pattern: {
    intent: string;
    target: string;
    count: number;
  } | null;
}

/**
 * Stutter detection: 3+ of the last `windowSize` actions share intent+target.
 */
export function detectStutter(
  actions: ActionRecord[],
  windowSize = 5,
  threshold = 3
): StutterResult {
  if (actions.length === 0) {
    return { detected: false, pattern: null };
  }

  const window = actions.slice(-windowSize);
  const keyCounts = new Map<string, { intent: string; target: string; count: number }>();

  for (const action of window) {
    const key = `${action.intent}::${action.target}`;
    const existing = keyCounts.get(key);
    if (existing) {
      existing.count++;
    } else {
      keyCounts.set(key, { intent: action.intent, target: action.target, count: 1 });
    }
  }

  for (const entry of keyCounts.values()) {
    if (entry.count >= threshold) {
      return {
        detected: true,
        pattern: {
          intent: entry.intent,
          target: entry.target,
          count: entry.count,
        },
      };
    }
  }

  return { detected: false, pattern: null };
}
