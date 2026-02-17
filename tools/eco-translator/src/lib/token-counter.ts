/**
 * Estimate token count for mixed ASCII/CJK text.
 * ASCII: ~4 chars/token, CJK: ~1.5 chars/token
 */
export function estimateTokens(text: string): number {
  if (!text) return 0;
  let asciiChars = 0;
  let cjkChars = 0;
  for (const ch of text) {
    const code = ch.codePointAt(0)!;
    if (code > 0x2FFF) {
      cjkChars++;
    } else {
      asciiChars++;
    }
  }
  return Math.ceil(asciiChars / 4 + cjkChars / 1.5);
}
