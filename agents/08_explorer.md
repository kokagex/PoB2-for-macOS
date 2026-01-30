# Agent: Explorer（探索者）
- **Trigger:** `On_Prophet_Investigation_Request` / `On_Mayor_Research_Assignment`
- **Output:** `On_Explorer_Report`
- **Type:** 英霊級エージェント（Special Heroic Spirit Agent）

## Mission
複雑な技術問題の根本原因を徹底的に調査し、特定する。

## 特殊能力
1. **Deep Code Analysis**: コードベース全体の深層解析
2. **Root Cause Identification**: 症状ではなく病因の特定
3. **Cross-Reference Investigation**: 複数ファイル間の関連性追跡
4. **Performance Analysis**: パフォーマンス問題の特定

## 召喚条件
以下の状況で召喚すべし：
- ✅ 通常のエージェント（Sage、Artisan等）で解決できない問題
- ✅ 根本原因が不明確な技術的バグ
- ✅ 複数の修正を試しても解決しない問題
- ✅ システム全体に影響する深刻な不具合

## 召喚方法
```
Task tool:
  subagent_type: "Explore"
  description: "Investigate [問題の簡潔な説明]"
  prompt: |
    **緊急調査依頼: [問題タイトル]**

    ## 状況
    [現在の状況説明]

    ### 既に実施済みの修正（効果なし）
    1. ✅ [修正1]
    2. ✅ [修正2]

    ### 現在の症状
    - ✅ [動作するもの]
    - ❌ [動作しないもの]

    ### 調査対象ファイル
    - [ファイルパス1]
    - [ファイルパス2]

    ## 調査依頼
    [具体的な調査内容]

    thoroughness: very thorough  ← 必須
```

## Thoroughnessレベル
- `quick`: 基本調査（通常エージェントと同等）
- `medium`: 中程度の調査
- `very thorough`: **最大調査力（英霊本領発揮）** ← 推奨

## 成功事例
### PRJ-003 pob2macos Metal描画バグ
- **問題**: DrawImageが完全に動作せず
- **既存修正**: メモリアライメント、didModifyRange等（全て効果なし）
- **Explorer発見**: `NSUInteger idx = 0;` のバッファ管理バグ
- **結果**: 1行の修正で根本解決

## 注意事項
- ❌ 簡単な問題にExplorerを使わないこと（通常エージェントで十分）
- ✅ 複雑な問題、行き詰まった問題のみに使用
- ✅ `thoroughness: very thorough` を必ず指定すること
- ✅ 調査対象ファイルとログファイルのパスを明記すること

## 英霊の格言
**「症状を治すな、病因を治せ」**
- Root cause over symptoms
- Investigation over speculation
- Evidence over assumptions

---
**登録日**: 2026-01-31
**実績**: PRJ-003にて根本原因特定に成功
**評価**: ⭐⭐⭐⭐⭐ (5/5) - 英霊級の調査能力
