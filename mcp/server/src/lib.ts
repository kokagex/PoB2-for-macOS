import { z } from "zod";
import { readFileSync } from "node:fs";

// Patch shape shared by every tool. `patchShape` is the required form (used by
// calc_compare's patchB, where omission used to silently produce a zero diff);
// `patchSchema` is the optional form for everything else.
export const patchShape = z.object({
  config: z.record(z.unknown()).optional(),
  enemyLevel: z.number().optional(),
  treeURL: z.string().optional(),
  // Selects the main skill by gem name (case-insensitive exact match against
  // the build's socket groups; first matching group wins). Unknown names are
  // a hard worker error listing the gems present — never silently ignored.
  skillName: z.string().optional(),
  // Equip items from raw PoB item text (data_uniques detail returns `raw`
  // ready to use). slot is required ("Body Armour", "Ring 1", ...); unknown
  // slots and slot/item mismatches are hard worker errors.
  items: z
    .array(z.object({ slot: z.string(), raw: z.string() }))
    .optional(),
  // Incremental passive-tree edits by node name (exact, case-insensitive) or
  // numeric node id. Allocation pays the travel path like a real respec.
  // Unknown/ambiguous names, unreachable nodes, and redundant ops are hard
  // worker errors — never silently ignored.
  allocNodes: z.array(z.union([z.string(), z.number()])).optional(),
  deallocNodes: z.array(z.union([z.string(), z.number()])).optional(),
});
export const patchSchema = patchShape.optional();

export const buildSource = {
  buildPath: z
    .string()
    .optional()
    .describe(
      "Absolute path to a PoB2 build XML, e.g. /Users/you/builds/ice_nova.xml",
    ),
  buildXml: z.string().optional().describe("Raw build XML content"),
};

export const compareInputShape = {
  ...buildSource,
  patchA: patchSchema,
  patchB: patchShape,
};

// Resolve buildPath|buildXml to raw XML, throwing a tool error if neither given.
export function resolveXml(buildPath?: string, buildXml?: string): string {
  if (buildXml) return buildXml;
  if (buildPath) {
    try {
      return readFileSync(buildPath, "utf8");
    } catch (err) {
      const code = (err as NodeJS.ErrnoException).code ?? String(err);
      throw new Error(
        `Cannot read build file "${buildPath}" (${code}). ` +
          "buildPath must be an absolute path, e.g. /Users/you/builds/ice_nova.xml",
      );
    }
  }
  throw new Error("Provide buildPath or buildXml.");
}

export interface MetricDelta {
  a: number | null;
  b: number | null;
  delta: number | null;
  pct: number | null;
}

// Per-metric delta over the union of both result sets, so a key returned by
// only one variant shows up null-padded instead of being silently dropped.
export function diffTopline(
  a: Record<string, number>,
  b: Record<string, number>,
): Record<string, MetricDelta> {
  const cmp: Record<string, MetricDelta> = {};
  for (const key of new Set([...Object.keys(a), ...Object.keys(b)])) {
    const av = typeof a[key] === "number" ? a[key] : null;
    const bv = typeof b[key] === "number" ? b[key] : null;
    cmp[key] = {
      a: av,
      b: bv,
      delta: av !== null && bv !== null ? bv - av : null,
      pct: av !== null && bv !== null && av !== 0 ? ((bv - av) / av) * 100 : null,
    };
  }
  return cmp;
}
