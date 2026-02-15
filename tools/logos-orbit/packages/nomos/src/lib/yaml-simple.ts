/**
 * Minimal YAML serializer for flat/nested objects.
 * No external dependencies. Handles strings, numbers, booleans, null, arrays, nested objects.
 */

function indent(level: number): string {
  return "  ".repeat(level);
}

function quoteString(value: string): string {
  // Quote strings that contain special YAML characters or are empty
  if (
    value === "" ||
    value.includes(":") ||
    value.includes("#") ||
    value.includes("\n") ||
    value.includes("'") ||
    value.includes('"') ||
    value.startsWith(" ") ||
    value.endsWith(" ") ||
    value === "true" ||
    value === "false" ||
    value === "null" ||
    /^\d/.test(value)
  ) {
    // Use double quotes, escape internal double quotes and backslashes
    const escaped = value
      .replace(/\\/g, "\\\\")
      .replace(/"/g, '\\"')
      .replace(/\n/g, "\\n");
    return `"${escaped}"`;
  }
  return value;
}

function serializeValue(value: unknown, level: number): string {
  if (value === null || value === undefined) {
    return "null";
  }
  if (typeof value === "boolean") {
    return value ? "true" : "false";
  }
  if (typeof value === "number") {
    return String(value);
  }
  if (typeof value === "string") {
    return quoteString(value);
  }
  if (Array.isArray(value)) {
    if (value.length === 0) {
      return "[]";
    }
    const lines: string[] = [];
    for (const item of value) {
      if (typeof item === "object" && item !== null && !Array.isArray(item)) {
        // Nested object in array
        const entries = Object.entries(item as Record<string, unknown>);
        if (entries.length === 0) {
          lines.push(`${indent(level)}- {}`);
        } else {
          const [firstKey, firstVal] = entries[0]!;
          lines.push(
            `${indent(level)}- ${firstKey}: ${serializeValue(firstVal, level + 2)}`
          );
          for (let i = 1; i < entries.length; i++) {
            const [key, val] = entries[i]!;
            lines.push(
              `${indent(level + 1)}${key}: ${serializeValue(val, level + 2)}`
            );
          }
        }
      } else {
        lines.push(`${indent(level)}- ${serializeValue(item, level + 1)}`);
      }
    }
    return "\n" + lines.join("\n");
  }
  if (typeof value === "object") {
    const entries = Object.entries(value as Record<string, unknown>);
    if (entries.length === 0) {
      return "{}";
    }
    const lines: string[] = [];
    for (const [key, val] of entries) {
      const serialized = serializeValue(val, level + 1);
      if (serialized.startsWith("\n")) {
        lines.push(`${indent(level)}${key}:${serialized}`);
      } else {
        lines.push(`${indent(level)}${key}: ${serialized}`);
      }
    }
    return "\n" + lines.join("\n");
  }
  return String(value);
}

/**
 * Serialize a JavaScript object to a YAML string.
 */
export function toYaml(obj: Record<string, unknown>): string {
  const lines: string[] = [];
  for (const [key, value] of Object.entries(obj)) {
    const serialized = serializeValue(value, 1);
    if (serialized.startsWith("\n")) {
      lines.push(`${key}:${serialized}`);
    } else {
      lines.push(`${key}: ${serialized}`);
    }
  }
  return lines.join("\n") + "\n";
}
