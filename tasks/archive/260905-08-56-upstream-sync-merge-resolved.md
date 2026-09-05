---
kind: context-keeper-scratch
date: 2026-09-05
topic: upstream sync phase 13 (3887ae68a) — merge conflicts fully resolved
---
# 状態
- worktree `.worktrees/upstream-sync-phase13` branch `sync/upstream-dev-3887ae68a`、全 conflict 解消済み、`luajit -bl` 全 src PASS、`git add -A src` 済み (未 commit)
# 今セグメントの解決
- Main.lua: 全 hunk ours (fork 単列 options popup / screenScale / i18n / POESESSID / About)。unique 読込 pcall を `pcall(function() return new("Item"):Item(raw,"UNIQUE",true) end)` に。`count += 1` を標準 Lua 化
- ItemsTab.lua: 計画通り。buildModSortList は upstream (sortTransforms 廃止) + i18n label。selectorsXOffset 採用。compare block は upstream 丸ごと + i18n header (statCompare.removingItem / equippingItemInSlot / tipDisableStatDiff)。upstream の Draw 内 "Toggle mods" click 処理は `ItemsTabClass:ProcessDisplayItemTooltipModToggle(inputEvents)` に切り出し、Build.lua の deferred tooltip 描画直後から呼ぶ (Metal z-order 対応)
- Build.lua: fork prologue (InitMinimal/OnFrameMinimal) 維持 + `---@class Build` 注釈。upstream sidebar breakdown pin 機能 (CalcBreakdownControl in sidebar, SetDisplayStat/ClearDisplayStat, statBox.onClick, AddDisplayStatList actorName) を採用。SetDisplayStat/ClearDisplayStat は fork の OnFrame 末尾 (tooltip 描画) の後ろへ移動。statSet dropdown は fork 通り無し。spectre library popup は fork 簡易版のまま。InsertItemWarnings に augmentLimitWarning 追加
- LuaJIT 拡張の標準 Lua 化: Tooltip.lua (+=), Item.lua (continue×3→goto continue_affix/continue_magnitude/continue_mod, -=), CalcSetup.lua (+=), BuildExportPoE2.lua (`?.`→`(x or {}).y`, inline continue→goto continue_group), CalcOffence.lua (lambda `|_,key| ->`→function)
- Tooltip.lua: Fractured icon を fork の `Assets/fracturedicon.png` に戻す。fork の _descFrame else 分岐の閉じ `end` 復元
# 残り
- mcp/server npm test (golden 53) / TreeData 0_5 sync / build-app + smoke-test / .app 起動 / UPSTREAM.md Phase 13 / changelog / commit / brain_save
