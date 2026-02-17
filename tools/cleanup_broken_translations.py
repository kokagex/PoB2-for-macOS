#!/usr/bin/env python3
"""
Cleanup broken Japanese translations in ja_mod_stat_lines.lua

Detects and removes entries with broken Japanese grammar patterns:
- Type A: Word-by-word direct translation ("あなた 持つ", "あなた 失う")
- Type B: Mixed English/Japanese with English function words remaining
- Type C: English plural 's' appended to katakana words

Removed entries fall back to original English display (better than broken Japanese).
"""

import re
import sys
from pathlib import Path

TARGET = Path("PathOfBuilding.app/Contents/Resources/src/Locales/ja_mod_stat_lines.lua")

# --- Detection patterns for BROKEN translations ---

# English function words that should NOT appear in a good Japanese translation value
# These are checked as whole words (surrounded by spaces, start/end, or adjacent to Japanese)
ENGLISH_FUNCTION_WORDS = [
    r'\bof\b', r'\bon\b', r'\bwhile\b', r'\bfrom\b', r'\byour\b',
    r'\byou\b', r'\bif\b', r'\bwith\b', r'\bper\b', r'\bduring\b',
    r'\bhave\b', r'\bhas\b', r'\bare\b', r'\bis\b', r'\bthe\b',
    r'\bGranted\b', r'\bgranted\b', r'\bcontaining\b', r'\binflicted\b',
    r'\binflict\b', r'\baffecting\b', r'\bDealt\b', r'\bdealt\b',
    r'\bRecently\b', r'\brecently\b', r'\bSocketed\b',
    r'\bEnemies\b', r'\bAllies\b', r'\bPresence\b',
    r'\bDisabled\b', r'\bPoisons\b', r'\bBlocked\b',
    r'\bstarted\b', r'\bequipped\b',
]

# Compile a single pattern for efficiency
ENGLISH_WORD_RE = re.compile('|'.join(ENGLISH_FUNCTION_WORDS), re.IGNORECASE)

# "あなた 持つ" or "あなた 失う" or "あなた 受ける" - word-by-word "You have/lose/take"
ANATA_PATTERN = re.compile(r'あなた\s+(持つ|失う|受ける|のみ)')

# Katakana followed by English plural 's' (e.g., スキルs, カースs, ジュエルs)
KATAKANA_PLURAL_S = re.compile(r'[\u30A0-\u30FF]s(?:\b|[がをにはでと])')

# "Effect of" remaining literally in translation
EFFECT_OF = re.compile(r'Effect of\b')

# English words that indicate structural grammar issues (not just terminology)
ENGLISH_GRAMMAR_FRAGMENTS = [
    r"you've",
    r"you'",
    r"\bcan\b",  # "できる" should be used
    r"\bdo not\b",
    r"\bnot\b(?!\s*[ぁ-ん\u30A0-\u30FF])",  # "not" not followed by Japanese
]
ENGLISH_GRAMMAR_RE = re.compile('|'.join(ENGLISH_GRAMMAR_FRAGMENTS), re.IGNORECASE)

# --- Allowlist: patterns that look like English but are OK ---
# Proper nouns / game terms that legitimately appear in Japanese translations
ALLOWED_TERMS = {
    'Vaal', 'Pact', 'DPS', 'DoT', 'ES', 'HP', 'MP',
}


def strip_placeholders(text: str) -> str:
    """Remove {0}, {1} etc. placeholders before checking for English."""
    return re.sub(r'\{[0-9]+\}', '', text)


def is_broken(en_key: str, ja_value: str) -> tuple[bool, str]:
    """
    Check if a Japanese translation value is broken.
    Returns (is_broken, reason).
    """
    # Strip placeholders so they don't trigger false positives
    cleaned = strip_placeholders(ja_value)

    # Check Type A: "あなた 持つ" word-by-word pattern
    if ANATA_PATTERN.search(cleaned):
        return True, "Type A: word-by-word あなた+verb"

    # Check: "Effect of" literally in translation
    if EFFECT_OF.search(cleaned):
        return True, "Type B: literal 'Effect of'"

    # Check Type C: katakana + plural s
    if KATAKANA_PLURAL_S.search(cleaned):
        return True, "Type C: katakana+plural-s"

    # Check Type B: English function words
    if ENGLISH_WORD_RE.search(cleaned):
        return True, "Type B: English function words"

    # Check English grammar fragments
    if ENGLISH_GRAMMAR_RE.search(cleaned):
        return True, "Type B: English grammar fragments"

    return False, ""


def parse_lua_table(content: str) -> list[dict]:
    """
    Parse the lua file into a list of entries.
    Each entry is either:
      - {"type": "entry", "key": str, "value": str, "raw": str}
      - {"type": "other", "raw": str}  (comments, blank lines, etc.)
    """
    entries = []
    # Match lines like: ["key"] = "value",
    # Handle multi-line values by tracking state
    entry_re = re.compile(
        r'^(\s*)\[(["\'])(.*?)\2\]\s*=\s*(["\'])(.*?)\4\s*,?\s*(--.*)?$'
    )

    for line in content.split('\n'):
        m = entry_re.match(line)
        if m:
            indent = m.group(1)
            key = m.group(3)
            value = m.group(5)
            # Unescape lua string escapes
            key = key.replace('\\"', '"').replace("\\'", "'")
            value = value.replace('\\"', '"').replace("\\'", "'")
            entries.append({
                "type": "entry",
                "key": key,
                "value": value,
                "raw": line,
                "indent": indent,
            })
        else:
            entries.append({"type": "other", "raw": line})

    return entries


def main():
    if not TARGET.exists():
        print(f"ERROR: {TARGET} not found")
        sys.exit(1)

    content = TARGET.read_text(encoding='utf-8')
    entries = parse_lua_table(content)

    total_entries = sum(1 for e in entries if e["type"] == "entry")
    broken_entries = []
    kept_entries = []

    for e in entries:
        if e["type"] != "entry":
            continue
        is_bad, reason = is_broken(e["key"], e["value"])
        if is_bad:
            broken_entries.append((e, reason))
        else:
            kept_entries.append(e)

    # --- Report ---
    print(f"=== Translation Cleanup Report ===")
    print(f"Total entries: {total_entries}")
    print(f"Broken (removing): {len(broken_entries)}")
    print(f"Good (keeping): {len(kept_entries)}")
    print(f"Removal rate: {len(broken_entries)/total_entries*100:.1f}%")
    print()

    # Show breakdown by type
    type_counts = {}
    for _, reason in broken_entries:
        type_counts[reason] = type_counts.get(reason, 0) + 1
    print("Breakdown by type:")
    for reason, count in sorted(type_counts.items(), key=lambda x: -x[1]):
        print(f"  {reason}: {count}")
    print()

    # Show some examples of removed entries
    print("Sample removed entries (first 20):")
    for (e, reason), i in zip(broken_entries[:20], range(20)):
        print(f"  [{reason}]")
        print(f"    EN: {e['key'][:80]}")
        print(f"    JA: {e['value'][:80]}")
        print()

    # --- Rebuild file ---
    output_lines = []
    for e in entries:
        if e["type"] == "other":
            output_lines.append(e["raw"])
        else:
            is_bad, _ = is_broken(e["key"], e["value"])
            if not is_bad:
                output_lines.append(e["raw"])
            # else: skip broken entry

    # Clean up excessive blank lines (from removed entries leaving gaps)
    cleaned_output = []
    prev_blank = False
    for line in output_lines:
        is_blank = line.strip() == ""
        if is_blank and prev_blank:
            continue  # Skip consecutive blank lines
        cleaned_output.append(line)
        prev_blank = is_blank

    new_content = '\n'.join(cleaned_output)

    # Write output
    TARGET.write_text(new_content, encoding='utf-8')
    print(f"Written cleaned file to {TARGET}")
    print(f"Before: {len(content)} bytes, After: {len(new_content)} bytes")


if __name__ == "__main__":
    main()
