import type { StatusStore } from "@logos-orbit/shared";

export interface IntegrityStatusResult {
  totalVerifications: number;
  lastConfidence: number;
  lastVerdict: "PASS" | "WARN" | "FAIL" | "NONE";
  contradictions: number;
  decayPending: boolean;
  actionsSinceLastVerification: number;
}

function verdictFromScore(score: number): "PASS" | "WARN" | "FAIL" {
  if (score >= 0.7) return "PASS";
  if (score >= 0.4) return "WARN";
  return "FAIL";
}

export async function getIntegrityStatus(
  store: StatusStore
): Promise<IntegrityStatusResult> {
  const status = await store.read();

  const totalVerifications = status.integrity.penalties.length;
  const lastConfidence = status.integrity.score;
  const lastVerdict =
    totalVerifications > 0 ? verdictFromScore(lastConfidence) : "NONE";

  const contradictions = status.integrity.contradictions.filter(
    (c) => !c.resolved
  ).length;

  const actionsSinceLastVerification = status.chronos.actions.length;

  // Decay is pending if there have been verifications AND actions have accumulated
  const decayPending =
    totalVerifications > 0 && status.chronos.actions.length > 10;

  return {
    totalVerifications,
    lastConfidence,
    lastVerdict,
    contradictions,
    decayPending,
    actionsSinceLastVerification,
  };
}
