 あなたは /Users/kokage/national-operations/pob2macos の PoB2 macOS
  移植を担当します。
  目的は「パッシブツリーの機能を段階的にWindows版から移植する」です。

  現状 (2026-02-04 23:50更新):
  - アプリは Finder から PathOfBuilding.app を起動すると動作する。
  - ログは `PathOfBuilding.app/Contents/Resources/pob2macos/codex/
  passive_tree_app.log` に出る。
  - 最小テスト起動は `pob2macos/codex/
  run_passive_tree_test.command`（ログは `codex/
  passive_tree_test.log`）。
  - TreeData は PoE2 Windows 版を反映済み、DDS表示は正常。
  - ホバーは動作済み（動的半径で近傍フォールバック）。
  - Data/Misc.lua からデータロード成功（エラーなし）。

  重要変更:
  - `PathOfBuilding.app/Contents/Resources/pob2macos/src/Launch.lua`
    - `_G.MINIMAL_PASSIVE_TEST = true` を維持。
    - `LoadModule("Data/Misc", data)` でPoE2のcharacterConstants/
  gameConstants取得。
    - Windows版 Modules/Data, Modules/ModTools はPoE1/PoE2非互換のた
  めロード保留。
    - `main:SetWindowTitleSubtext` のスタブ追加。
    - `build.buildName` 追加。
    - 起動時にクラス開始ノード割当と `BuildAllDependsAndPaths` 実行。
  - `PathOfBuilding.app/Contents/Resources/pob2macos/src/Classes/
  PassiveSpec.lua`
    - MINIMAL用 ModList スタブ関数 `getMinimalModList()` 追加。
    - MINIMAL時の `SelectClass`/`SelectAscendClass` が開始ノード割当
  と `BuildAllDependsAndPaths` 実行。
    - `ReplaceNode` が MINIMAL時は ModList を作らないように変更。
  - `PathOfBuilding.app/Contents/Resources/pob2macos/src/Classes/
  PassiveTreeView.lua`
    - hover判定のフォールバック半径を動的化（40〜160px）。
    - debugテキストはサイズ48、y+110で表示。
    - MINIMAL時の traceMode で path nil を安全化。

  新発見 (2026-02-04):
  - Windows版のModules/DataとModules/ModToolsはPoE1用でPoE2とは非互換。
  - フィールド名の違い:
    * PoE1: mana_regeneration_rate_per_minute_%
    * PoE2: character_inherent_mana_regeneration_rate_per_minute_%
  - 詳細: `codex/POE1_POE2_MODULE_INCOMPATIBILITY.md`

  既知の問題:
  - modLib 未ロード（PoE1/PoE2非互換のため保留）。
  - 統計計算は動作しない（ModList.Sum/Moreが未実装）。
  - クラス/アセンダンシー切替の実機確認が必要。

  フェーズ3の状態 (2026-02-04 23:58):
  ✅ クラス/アセンダンシー切替は既に実装完了
  - PassiveTreeView.lua 行397-481に完全実装済み
  - main:OpenConfirmPopup()スタブ追加（MINIMAL mode対応）
  - アセンダンシー開始ノードをクリックすることで切替可能
  - ClassStartノードは視覚的な目印のみ（クリック不可）

  次にやること:
  手動テスト: クラス/アセンダンシー切替の動作確認
  1) アプリを起動（PathOfBuilding.app または run_passive_tree_test.command）
  2) 異なるクラスのアセンダンシー開始ノードを左クリック
  3) 中央背景画像が切り替わることを確認
  4) ログ出力（SelectClass/SelectAscendClass）を確認

  その後:
  フェーズ4: ノード割当/解除の実装
  - 通常ノードの左クリックで割当/解除
  - パス計算の視覚的フィードバック

  参考資料:
  - クラス切替ガイド: `codex/CLASS_SWITCHING_GUIDE.md` ★NEW
  - 移行計画: `codex/PASSIVE_TREE_MIGRATION_PLAN.md`
  - 非互換性レポート: `codex/POE1_POE2_MODULE_INCOMPATIBILITY.md`