#!/usr/bin/env python3
"""
Strict second-pass cleanup: remove entries with broken word-by-word Japanese grammar.
Detects spacing patterns typical of word-by-word translation.
"""

import re
import sys
from pathlib import Path

TARGET = Path("PathOfBuilding.app/Contents/Resources/src/Locales/ja_mod_stat_lines.lua")


def is_broken_strict(ja_value: str) -> tuple[bool, str]:
    """Strict check for broken Japanese translations."""
    cleaned = re.sub(r'\{[0-9]+\}', '', ja_value)

    # Any remaining English words (not just function words)
    # Good translations use only: katakana, hiragana, kanji, numbers, symbols, {placeholders}
    # Check for sequences of 3+ ASCII alpha chars (likely untranslated English)
    english_words = re.findall(r'[a-zA-Z]{3,}', cleaned)
    # Filter out accepted terms
    accepted = {'DPS', 'DoT', 'ES', 'HP', 'MP', 'Mod', 'Id'}
    remaining_english = [w for w in english_words if w not in accepted]
    if remaining_english:
        return True, f"English words: {', '.join(remaining_english[:3])}"

    # Word-by-word spacing: Japanese text with excessive spaces between CJK words
    # e.g., "ダメージ で ヒット から ソケットされた"
    # Count spaces between CJK characters/katakana
    cjk_space_count = len(re.findall(
        r'[\u3000-\u9FFF\u30A0-\u30FF]\s+[\u3000-\u9FFF\u30A0-\u30FF]',
        cleaned
    ))
    # More than 3 CJK-space-CJK patterns suggests word-by-word translation
    if cjk_space_count > 3:
        return True, f"Excessive CJK spacing ({cjk_space_count})"

    return False, ""


def main():
    content = TARGET.read_text(encoding='utf-8')

    entry_re = re.compile(
        r'^(\s*)\[(["\'])(.*?)\2\]\s*=\s*(["\'])(.*?)\4\s*,?\s*(--.*)?$'
    )

    lines = content.split('\n')
    output_lines = []
    removed = 0
    total = 0

    for line in lines:
        m = entry_re.match(line)
        if m:
            total += 1
            value = m.group(5).replace('\\"', '"').replace("\\'", "'")
            is_bad, reason = is_broken_strict(value)
            if is_bad:
                removed += 1
                continue  # Skip this line
        output_lines.append(line)

    # Clean up consecutive blank lines
    cleaned = []
    prev_blank = False
    for line in output_lines:
        is_blank = line.strip() == ""
        if is_blank and prev_blank:
            continue
        cleaned.append(line)
        prev_blank = is_blank

    new_content = '\n'.join(cleaned)
    TARGET.write_text(new_content, encoding='utf-8')

    remaining = total - removed
    print(f"=== Strict Cleanup Pass ===")
    print(f"Entries checked: {total}")
    print(f"Removed (still broken): {removed}")
    print(f"Remaining (good): {remaining}")
    print(f"File written: {TARGET}")


if __name__ == "__main__":
    main()
