/**
 * Spec writer: Writes rule YAML files and reads existing rule IDs from disk.
 *
 * C-N2: No delete/disable API — rules are immutable once written.
 */

import { readdir, writeFile, mkdir } from "node:fs/promises";
import { join } from "node:path";
import { toYaml } from "./yaml-simple.js";

export interface RuleYaml {
  id: string;
  createdAt: string;
  createdFrom: string;
  condition: string;
  severity: string;
  message: string;
  evidence: string;
  tags: string[];
}

/**
 * Write a rule as a YAML file. Returns the file path.
 */
export async function writeRuleYaml(
  rulesDir: string,
  rule: RuleYaml
): Promise<string> {
  await mkdir(rulesDir, { recursive: true });

  const filePath = join(rulesDir, `${rule.id}.yaml`);
  const content = toYaml({
    id: rule.id,
    createdAt: rule.createdAt,
    createdFrom: rule.createdFrom,
    condition: rule.condition,
    severity: rule.severity,
    message: rule.message,
    evidence: rule.evidence,
    tags: rule.tags,
  });

  await writeFile(filePath, content, "utf-8");
  return filePath;
}

/**
 * Read existing rule IDs from filenames in the rules directory.
 */
export async function readExistingRuleIds(
  rulesDir: string
): Promise<Set<string>> {
  try {
    const files = await readdir(rulesDir);
    const ids = new Set<string>();
    for (const file of files) {
      if (file.endsWith(".yaml") || file.endsWith(".yml")) {
        // Strip extension to get rule ID
        ids.add(file.replace(/\.(yaml|yml)$/, ""));
      }
    }
    return ids;
  } catch (err: unknown) {
    if (isNodeError(err) && err.code === "ENOENT") {
      return new Set();
    }
    throw err;
  }
}

function isNodeError(err: unknown): err is NodeJS.ErrnoException {
  return err instanceof Error && "code" in err;
}
