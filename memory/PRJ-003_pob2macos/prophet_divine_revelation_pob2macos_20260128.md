# 神託 - PoB2macOS移植プロジェクト

**発行日時**: 2026-01-28T22:30:00Z
**発行者**: Prophet（預言者）
**プロジェクト**: PRJ-003 PoB2macOS
**対象**: Mayor（村長）

---

## 神の御言葉

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    Path of Building 2 を macOS で動作させよ
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## 1. 背景

Path of Building 2（PoB2）は Path of Exile 2 のビルドプランニングツールである。
現在 Windows 専用であり、macOS ユーザーは利用できない状況にある。

**ソースの所在**: `~/Downloads/PathOfBuilding-PoE2-dev/`

---

## 2. 解析結果（預言者による初期調査）

### 2.1 アーキテクチャ

```
PoB2 構成:
├── src/           # Luaソースコード
│   ├── Launch.lua      # エントリーポイント (#@ SimpleGraphic)
│   ├── HeadlessWrapper.lua  # SimpleGraphic APIスタブ（重要）
│   └── ...
├── runtime/       # Windows DLL群
│   ├── lua51.dll
│   ├── SimpleGraphic.dll  ← 最重要依存
│   ├── glfw3.dll
│   ├── libGLESv2.dll
│   └── ...
├── docs/          # ドキュメント
└── Dockerfile     # Linux環境定義（参考）
```

### 2.2 核心的課題: SimpleGraphic.dll

`SimpleGraphic.dll` はカスタムグラフィックスライブラリであり、以下のAPIを提供:

| カテゴリ | 主要関数 |
|----------|----------|
| 初期化 | RenderInit, GetScreenSize, SetWindowTitle |
| 描画 | SetDrawColor, DrawImage, DrawString, DrawImageQuad |
| 入力 | IsKeyDown, GetCursorPos, SetCursorPos |
| リソース | NewImage, LoadModule, LoadFont |
| スクリプト | LaunchSubScript, SetSubScript |
| その他 | Copy, Paste, OpenURL, SetClipboard |

**HeadlessWrapper.lua** にすべてのAPIスタブが定義されている（移植の設計図）。

### 2.3 移植アプローチ

**選択されたアプローチ**: ソースからビルド（ネイティブ移植）

必要な作業:
1. SimpleGraphic.dll の macOS 代替実装
2. Lua/LuaJIT のmacOS版セットアップ
3. GLFW + OpenGL バックエンドの統合
4. ビルドシステムの構築

---

## 3. 村長への命令

### Phase 1: 詳細調査（Sage担当）

| タスク | 内容 |
|--------|------|
| T1-1 | SimpleGraphic全API（約50関数）の詳細仕様調査 |
| T1-2 | HeadlessWrapper.luaの完全分析 |
| T1-3 | 既存のLua+OpenGLバインディング調査（LÖVE, SDL2等） |
| T1-4 | 類似プロジェクトの移植事例調査 |

### Phase 2: 実装計画（Mayor + Sage）

| タスク | 内容 |
|--------|------|
| T2-1 | SimpleGraphic代替ライブラリの設計 |
| T2-2 | 段階的実装計画の策定 |
| T2-3 | 最小動作確認（MVP）の定義 |

### Phase 3: 実装（Artisan担当）

| タスク | 内容 |
|--------|------|
| T3-1 | macOS用SimpleGraphic互換レイヤー実装 |
| T3-2 | ビルドスクリプト作成 |
| T3-3 | 動作テスト |

### Phase 4: 検証（Paladin + Merchant）

| タスク | 内容 |
|--------|------|
| T4-1 | 動作確認・パフォーマンス検証 |
| T4-2 | 元Windows版との互換性確認 |

### Phase 5: 文書化（Bard担当）

| タスク | 内容 |
|--------|------|
| T5-1 | ビルド手順書作成 |
| T5-2 | ユーザーガイド作成 |

---

## 4. 制約条件

- **git push禁止**: このプロジェクトはローカルのみで作業する
- **ライセンス遵守**: PoB2のライセンスを確認し遵守すること
- **元機能維持**: Windows版と同等の機能を目指す

---

## 5. 優先度

**Phase 1（詳細調査）を最優先で実行せよ**

SimpleGraphicの全API仕様が判明しなければ、実装計画は立てられない。

---

## 神託終了

村長よ、この神託を受け取り、村人たちに適切にタスクを配分せよ。

**預言者（Prophet）**
2026-01-28T22:30:00Z
