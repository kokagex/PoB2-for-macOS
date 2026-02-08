# Label Multiline Fix Plan V1 (2026-02-08)

## Task
Fix "Usage Tips" text in Skills tab not wrapping - all text on one line with box characters instead of newlines.

## Root Cause
The C++ `DrawString()` in `sg_text.cpp` does NOT handle `\n` characters. When it encounters newline (codepoint 0x0A), it renders it as a box glyph and continues horizontally. On Windows, the SimpleGraphic DrawString apparently handles `\n` internally.

## Affected Code
- `LabelControl.lua` - The `Draw()` method calls `DrawString()` with the full label text
- `SkillsTab.lua` line 111-119 - Creates a LabelControl with multi-line `[[...]]` text containing `\n`

## Proposed Solution
Modify `LabelControl:Draw()` to split text by `\n` and render each line separately with increasing Y offset. This is the minimal fix that handles all multiline LabelControl usage throughout the app.

### Implementation
In `LabelControl:Draw()`:
1. Get the label text
2. Split by `\n` characters
3. Draw each line with `DrawString()`, incrementing Y by `height` for each line

Also fix `width` function to return the maximum width of all lines.

## Risk Assessment
- **Risk Level**: Low
- **Impact**: Only affects LabelControl rendering
- **Rollback**: Revert the single file change

## Success Criteria
- Usage Tips text displays on multiple lines
- No box characters visible
- Other labels unaffected (single-line labels work as before)
