#!/usr/bin/env python3
"""
Fix salvageable translations that were removed only due to katakana+plural-s.
These can be fixed by simply removing the English plural 's' after katakana.

Also fixes other minor patterns that are easily correctable:
- "スペルs" → "スペル"
- "アタックs" → "アタック"
- "ヒットs" → "ヒット"
etc.

Run AFTER cleanup_broken_translations.py to re-add fixed versions.
"""

import re
import sys
from pathlib import Path

TARGET = Path("PathOfBuilding.app/Contents/Resources/src/Locales/ja_mod_stat_lines.lua")
# Read the ORIGINAL file from git to get removed entries
ORIGINAL_BACKUP = None  # We'll use git show


def get_original_content() -> str:
    """Get the original file content from git."""
    import subprocess
    result = subprocess.run(
        ["git", "show", "HEAD:PathOfBuilding.app/Contents/Resources/src/Locales/ja_mod_stat_lines.lua"],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print(f"ERROR: git show failed: {result.stderr}")
        sys.exit(1)
    return result.stdout


def parse_entries(content: str) -> dict[str, str]:
    """Parse lua file into {key: value} dict."""
    entry_re = re.compile(
        r'^\s*\[(["\'])(.*?)\1\]\s*=\s*(["\'])(.*?)\3\s*,?\s*(--.*)?$'
    )
    entries = {}
    for line in content.split('\n'):
        m = entry_re.match(line)
        if m:
            key = m.group(2).replace('\\"', '"').replace("\\'", "'")
            value = m.group(4).replace('\\"', '"').replace("\\'", "'")
            entries[key] = value
    return entries


def fix_plural_s(text: str) -> str:
    """Remove English plural 's' after katakana words."""
    # Pattern: katakana char followed by 's' then word boundary or Japanese particle
    fixed = re.sub(r'([\u30A0-\u30FF])s\b', r'\1', text)
    return fixed


def has_remaining_english_issues(text: str) -> bool:
    """Check if text still has English problems after plural-s fix."""
    cleaned = re.sub(r'\{[0-9]+\}', '', text)
    # English function words
    english_words = re.compile(
        r'\b(of|on|while|from|your|you|if|with|per|during|have|has|are|is|the'
        r'|containing|inflicted|inflict|affecting|Granted|granted|Enemies'
        r'|Allies|Presence|Disabled|Poisons|Blocked|started|equipped'
        r'|Recently|recently|Socketed|Maximum|Unarmed|Retaliation)\b',
        re.IGNORECASE
    )
    if english_words.search(cleaned):
        return True
    # "あなた 持つ" pattern
    if re.search(r'あなた\s+(持つ|失う|受ける|のみ)', cleaned):
        return True
    # "Effect of"
    if re.search(r'Effect of\b', cleaned):
        return True
    # English grammar
    if re.search(r"you've|you'|\bcan\b|\bdo not\b", cleaned, re.IGNORECASE):
        return True
    return False


def main():
    # Get original entries (before cleanup)
    original_content = get_original_content()
    original_entries = parse_entries(original_content)

    # Get current entries (after cleanup)
    current_content = TARGET.read_text(encoding='utf-8')
    current_entries = parse_entries(current_content)

    # Find entries that were removed
    removed_keys = set(original_entries.keys()) - set(current_entries.keys())

    # Try to fix removed entries
    salvaged = {}
    still_broken = []
    for key in sorted(removed_keys):
        original_value = original_entries[key]
        fixed_value = fix_plural_s(original_value)

        if fixed_value != original_value and not has_remaining_english_issues(fixed_value):
            salvaged[key] = fixed_value
        else:
            still_broken.append((key, original_value))

    print(f"=== Salvage Report ===")
    print(f"Removed entries: {len(removed_keys)}")
    print(f"Salvageable (plural-s fix only): {len(salvaged)}")
    print(f"Still broken (left as English): {len(still_broken)}")
    print()

    if salvaged:
        print("Salvaged entries (first 20):")
        for i, (key, value) in enumerate(list(salvaged.items())[:20]):
            print(f"  EN: {key[:80]}")
            print(f"  JA: {value[:80]}")
            print()

    # Now add salvaged entries back into the file
    if salvaged:
        # Find the line before the closing "}" to insert entries
        lines = current_content.split('\n')
        # Find last entry line or closing brace
        insert_idx = None
        for i in range(len(lines) - 1, -1, -1):
            if lines[i].strip() == '}':
                insert_idx = i
                break

        if insert_idx is None:
            print("ERROR: Could not find closing brace in lua file")
            sys.exit(1)

        # Generate new entry lines
        new_lines = ["\t-- Salvaged entries (plural-s fix applied)"]
        for key, value in sorted(salvaged.items()):
            # Escape quotes in key and value
            escaped_key = key.replace('"', '\\"')
            escaped_value = value.replace('"', '\\"')
            new_lines.append(f'\t["{escaped_key}"] = "{escaped_value}",')

        # Insert before closing brace
        for j, new_line in enumerate(new_lines):
            lines.insert(insert_idx + j, new_line)

        new_content = '\n'.join(lines)
        TARGET.write_text(new_content, encoding='utf-8')
        print(f"Added {len(salvaged)} salvaged entries back to {TARGET}")

    print(f"\nFinal tally:")
    print(f"  Good (original): {len(current_entries)}")
    print(f"  Salvaged: {len(salvaged)}")
    print(f"  Total kept: {len(current_entries) + len(salvaged)}")
    print(f"  Removed (English fallback): {len(still_broken)}")


if __name__ == "__main__":
    main()
