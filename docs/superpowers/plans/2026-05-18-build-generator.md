# Build Generator (PoE2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** PoB-PoE2 fork のデータと headless 計算を外部から駆動して、メインスキル + サブスキル + key item を入力すると残り (passive tree / gem links / gear / jewel) を最適補完する Tauri アプリ (Rust + React) の MVP を完成させる。

**Architecture:** Tauri アプリ (Rust backend + React frontend) として実装。データは PoB に JSON dump させて Rust が読む (single source of truth)。重い calc は long-lived luajit subprocess (pob_worker.lua) に xml ↔ stats を流す。Greedy optimizer は Rust 側で fast approximate fitness を使い、checkpoint と最終確定だけ PoB headless で実計算する。

**Tech Stack:** Tauri 2.x / Rust (tokio, serde) / React 18 + TypeScript / Vite / LuaJIT (PoB と同じ) / mlua crate (cache parse 用)

**Reference Spec:** [docs/superpowers/specs/2026-05-18-build-generator-design.md](../specs/2026-05-18-build-generator-design.md)

**実装方針:**
- **Walking skeleton 戦略**: Phase 1 で stub だけの end-to-end が動く。以降の phase で stub を実装に置換していく
- **TDD**: 各 task は failing test → impl → passing test → commit のサイクル
- **frequent commit**: task 単位で commit
- **lean**: spec の MVP done line を満たす最小実装に集中。preset 切替 / GA / worker pool / cluster jewel 等は phase 外
- **作業場所**: 全 task は新リポ `~/pob2-build-generator/` (Phase 0 で作成) 内で実施。本 plan ファイルは `national-operations` に置いてあるので参照は cross-repo

---

## File Structure (新リポ `pob2-build-generator/`)

```
pob2-build-generator/
├── README.md
├── .gitignore
├── package.json                    # React (Vite)
├── vite.config.ts
├── tsconfig.json
├── index.html
├── src/                            # React frontend
│   ├── main.tsx
│   ├── App.tsx
│   ├── api/
│   │   └── tauri.ts                # Tauri command wrapper
│   ├── components/
│   │   ├── ClassPicker.tsx
│   │   ├── SkillPicker.tsx
│   │   ├── KeyItemPicker.tsx
│   │   ├── GenerateButton.tsx
│   │   └── ResultPanel.tsx
│   ├── stores/
│   │   └── buildStore.ts           # zustand state
│   └── types/
│       └── build.ts                # TypeScript mirror of Rust types
├── src-tauri/
│   ├── Cargo.toml
│   ├── tauri.conf.json
│   ├── build.rs
│   ├── src/
│   │   ├── main.rs                 # Tauri app entry
│   │   ├── lib.rs                  # re-exports
│   │   ├── commands.rs             # Tauri command handlers
│   │   ├── settings.rs             # PoB install path 等
│   │   ├── core/
│   │   │   ├── mod.rs
│   │   │   ├── model.rs            # BuildModel, Slot, ItemRef, etc.
│   │   │   ├── intent.rs           # BuildIntent
│   │   │   ├── fitness.rs          # Rust-side approximate fitness
│   │   │   ├── optimizer.rs        # Greedy
│   │   │   └── pob_xml.rs          # PoB build code (xml) serialize
│   │   ├── pob_bridge/
│   │   │   ├── mod.rs
│   │   │   ├── data_reader.rs      # JSON cache loader
│   │   │   ├── data_dumper.rs      # data_export.lua の subprocess 実行
│   │   │   └── worker.rs           # pob_worker.lua subprocess 管理
│   │   └── types.rs                # serde 型 (UI と共有)
│   ├── data/cache/                 # JSON dump (gitignored)
│   └── tests/
│       └── smoke.rs                # end-to-end smoke test
├── scripts/
│   ├── data_export.lua             # PoB データ JSON dumper
│   └── pob_worker.lua              # 長時間 worker
└── docs/
    └── DESIGN.md                   # spec へのリンクと開発メモ
```

---

## Phase 0: Bootstrap (新リポ + Tauri scaffold)

### Task 0.1: 新リポ作成と Tauri 雛形 init

**Files:**
- Create: `~/pob2-build-generator/` (全ファイル)

- [ ] **Step 1: 新ディレクトリ作成と git init**

```bash
mkdir -p ~/pob2-build-generator
cd ~/pob2-build-generator
git init
gh repo create kokagex/pob2-build-generator --private --source=. --remote=origin
```

- [ ] **Step 2: Tauri + React + TypeScript scaffold**

```bash
cd ~/pob2-build-generator
npm create tauri-app@latest -- \
  --template react-ts \
  --identifier com.kokagex.pob2bg \
  --name pob2-build-generator \
  --manager npm \
  --yes \
  .
```

選択肢でも以下相当:
- App name: `pob2-build-generator`
- Frontend: React + TypeScript
- Bundler: Vite
- Package manager: npm

- [ ] **Step 3: 依存追加 (Rust 側)**

`src-tauri/Cargo.toml` の `[dependencies]` セクションに以下を追記:

```toml
serde = { version = "1", features = ["derive"] }
serde_json = "1"
tokio = { version = "1", features = ["full"] }
thiserror = "1"
anyhow = "1"
mlua = { version = "0.9", features = ["luajit", "vendored"] }
```

- [ ] **Step 4: 依存追加 (フロント側)**

```bash
cd ~/pob2-build-generator
npm install zustand
```

- [ ] **Step 5: build が通ることを確認**

```bash
cd ~/pob2-build-generator
npm run tauri dev
```

Expected: Tauri app が起動して default 画面 (Vite + React + Tauri ロゴ) が表示される。動作確認したら `Ctrl-C` で停止。

- [ ] **Step 6: .gitignore 追加**

`.gitignore` に以下を追加 (Tauri scaffold が既に含む `node_modules`, `target` などに追加):

```
src-tauri/data/cache/
.DS_Store
```

- [ ] **Step 7: 初回 commit + push**

```bash
cd ~/pob2-build-generator
git add .
git commit -m "chore: tauri + react + typescript scaffold via create-tauri-app"
git push -u origin main
```

---

## Phase 1: Walking Skeleton (全 stub で end-to-end が動く)

stub 内容:
- Rust 側に固定の "DPS = 12345" を返す `generate` Tauri command
- フロント側に「Generate」ボタンと結果表示
- これだけで「ボタン押す → Rust 呼ぶ → 結果表示」の経路が通る

### Task 1.1: Rust 側 stub Tauri command

**Files:**
- Create: `src-tauri/src/types.rs`
- Create: `src-tauri/src/commands.rs`
- Modify: `src-tauri/src/main.rs` (or `lib.rs`)
- Test: `src-tauri/src/commands.rs` (inline `#[cfg(test)]`)

- [ ] **Step 1: failing test を書く (commands.rs)**

`src-tauri/src/commands.rs` を新規作成:

```rust
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize, PartialEq)]
pub struct GenerateRequest {
    pub class: String,
    pub main_skill: String,
}

#[derive(Debug, Serialize, Deserialize, PartialEq)]
pub struct GenerateResponse {
    pub dps: f64,
    pub build_code: String,
}

#[tauri::command]
pub fn generate(req: GenerateRequest) -> Result<GenerateResponse, String> {
    Ok(GenerateResponse {
        dps: 12345.0,
        build_code: format!("STUB-BUILD-{}-{}", req.class, req.main_skill),
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn generate_returns_stub_dps_and_build_code() {
        let req = GenerateRequest {
            class: "Ranger".to_string(),
            main_skill: "Lightning Arrow".to_string(),
        };
        let resp = generate(req).unwrap();
        assert_eq!(resp.dps, 12345.0);
        assert_eq!(resp.build_code, "STUB-BUILD-Ranger-Lightning Arrow");
    }
}
```

- [ ] **Step 2: types.rs を空で作成 (mod 宣言用)**

`src-tauri/src/types.rs`:

```rust
// 共通型は後続 task で追加。Phase 1 では commands.rs にインライン定義。
```

- [ ] **Step 3: main.rs / lib.rs に mod 追加と command 登録**

`src-tauri/src/lib.rs` (Tauri 2.x の typical な構成、scaffold した結果に合わせる) に:

```rust
mod commands;
mod types;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![commands::generate])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
```

- [ ] **Step 4: test を走らせて PASS 確認**

```bash
cd ~/pob2-build-generator/src-tauri
cargo test commands::tests::generate_returns_stub_dps_and_build_code
```

Expected: `test result: ok. 1 passed`

- [ ] **Step 5: commit**

```bash
cd ~/pob2-build-generator
git add src-tauri/src/commands.rs src-tauri/src/types.rs src-tauri/src/lib.rs
git commit -m "feat(commands): stub generate command returns fixed DPS for walking skeleton"
```

### Task 1.2: フロント側 stub UI (Generate ボタン + 結果表示)

**Files:**
- Create: `src/api/tauri.ts`
- Create: `src/types/build.ts`
- Modify: `src/App.tsx`

- [ ] **Step 1: TypeScript 型定義 (Rust と mirror)**

`src/types/build.ts`:

```typescript
export interface GenerateRequest {
  class: string;
  main_skill: string;
}

export interface GenerateResponse {
  dps: number;
  build_code: string;
}
```

- [ ] **Step 2: Tauri command wrapper**

`src/api/tauri.ts`:

```typescript
import { invoke } from '@tauri-apps/api/core';
import type { GenerateRequest, GenerateResponse } from '../types/build';

export async function generate(req: GenerateRequest): Promise<GenerateResponse> {
  return await invoke<GenerateResponse>('generate', { req });
}
```

- [ ] **Step 3: App.tsx を skeleton UI に置換**

`src/App.tsx` を以下で全置換:

```tsx
import { useState } from 'react';
import { generate } from './api/tauri';
import type { GenerateResponse } from './types/build';

export default function App() {
  const [result, setResult] = useState<GenerateResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const onGenerate = async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await generate({
        class: 'Ranger',
        main_skill: 'Lightning Arrow',
      });
      setResult(res);
    } catch (e) {
      setError(String(e));
    } finally {
      setLoading(false);
    }
  };

  return (
    <main style={{ padding: 24, fontFamily: 'sans-serif' }}>
      <h1>PoB2 Build Generator</h1>
      <p>Class: Ranger / Main Skill: Lightning Arrow (Phase 1 hardcoded)</p>
      <button onClick={onGenerate} disabled={loading}>
        {loading ? 'Generating…' : 'Generate'}
      </button>
      {error && <p style={{ color: 'red' }}>{error}</p>}
      {result && (
        <section style={{ marginTop: 24 }}>
          <h2>Result</h2>
          <p>DPS: {result.dps.toLocaleString()}</p>
          <pre>{result.build_code}</pre>
        </section>
      )}
    </main>
  );
}
```

- [ ] **Step 4: 動作確認**

```bash
cd ~/pob2-build-generator
npm run tauri dev
```

Expected: "Generate" ボタンを押すと "DPS: 12,345" と "STUB-BUILD-Ranger-Lightning Arrow" が表示される。動作確認後 Ctrl-C。

- [ ] **Step 5: commit**

```bash
cd ~/pob2-build-generator
git add src/App.tsx src/api/tauri.ts src/types/build.ts
git commit -m "feat(ui): walking skeleton UI - generate button calls stub command"
```

---

## Phase 2: PoB データ層 (real data, 部分のみ)

stub 値を捨てて、PoB から実データを JSON dump し Rust で読み込む。MVP では Skill 一覧と Unique 一覧だけ load する (mod / passive tree は Phase 3 以降)。

### Task 2.1: data_export.lua 雛形 (skill 一覧のみ JSON 出力)

**Files:**
- Create: `scripts/data_export.lua`
- Test: 手動コマンド実行 + Rust 側 integration test (Task 2.3)

- [ ] **Step 1: lua script 作成**

`scripts/data_export.lua` を新規作成:

```lua
-- data_export.lua
-- 使い方: luajit data_export.lua <pob-install-path> <output-path>
-- PoB の HeadlessWrapper をロードして skill/unique を JSON で dump する

local pobPath = arg[1] or error("usage: luajit data_export.lua <pob-path> <output-path>")
local outputPath = arg[2] or error("usage: luajit data_export.lua <pob-path> <output-path>")

-- PoB の src/ にディレクトリを移動 (HeadlessWrapper.lua が相対 require するため)
local lfs_ok = pcall(require, "lfs")
local origDir
if lfs_ok then
    local lfs = require("lfs")
    origDir = lfs.currentdir()
    lfs.chdir(pobPath .. "/src")
end

-- HeadlessWrapper の callback hook より先に環境変数で CI モード抑止 (ModCache 使う)
os.setenv = os.setenv or function() end  -- 互換 stub

dofile("HeadlessWrapper.lua")

-- ここに来た時点で PoB の data モジュール群がロード済み
-- data モジュールは PoB の `data` global table (data.skills, data.uniques, ...) に存在することを想定

local out = {
    skills = {},
    uniques = {},
}

-- Skill 一覧 (act_* / sup_*)
for skillId, skill in pairs(data.skills or {}) do
    out.skills[skillId] = {
        id = skillId,
        name = skill.name,
        baseFlags = skill.baseFlags,
        gemTags = skill.gemTags,
    }
end

-- Unique 一覧 (slot → list)
for slot, uniques in pairs(data.uniques or {}) do
    out.uniques[slot] = {}
    for _, u in ipairs(uniques) do
        table.insert(out.uniques[slot], {
            name = u.title or u[1],
            baseName = u.baseName,
            -- 詳細 mod は Phase 3 で
        })
    end
end

-- JSON encode (PoB に dkjson が同梱されていると想定、なければ minimal encoder を入れる)
local json_ok, json = pcall(require, "dkjson")
if not json_ok then
    -- minimal encoder fallback
    json = {}
    function json.encode(t)
        local function enc(v)
            if type(v) == "string" then return string.format("%q", v) end
            if type(v) == "number" then return tostring(v) end
            if type(v) == "boolean" then return tostring(v) end
            if type(v) == "nil" then return "null" end
            if type(v) == "table" then
                local parts = {}
                local isArray = #v > 0
                if isArray then
                    for _, x in ipairs(v) do table.insert(parts, enc(x)) end
                    return "[" .. table.concat(parts, ",") .. "]"
                else
                    for k, x in pairs(v) do
                        table.insert(parts, string.format("%q:%s", tostring(k), enc(x)))
                    end
                    return "{" .. table.concat(parts, ",") .. "}"
                end
            end
            return "null"
        end
        return enc(t)
    end
end

local f = io.open(outputPath, "w")
if not f then error("cannot write to " .. outputPath) end
f:write(json.encode(out))
f:close()

print("OK: dumped " .. outputPath)
```

**注意**: 上記スクリプトの「PoB の `data` global table」へのアクセス方法は **PoB 実装に依存**。実際に動かしてみて `data.skills` がそのままの形で取れるか確認、もし違う構造なら `mainObject.main.data` などに探りを入れる。最初の実行で構造を print して確認 → スクリプト調整。

- [ ] **Step 2: 手動で実行して動作確認**

```bash
cd ~/pob2-build-generator
luajit scripts/data_export.lua /Users/kokage/national-operations /tmp/pob_data.json
```

Expected: `OK: dumped /tmp/pob_data.json` が表示され、`/tmp/pob_data.json` に skill / unique の JSON が書き出される。

うまく行かなければ:
1. PoB の data global の構造を確認 — `scripts/data_export.lua` 内に一時的に `for k in pairs(_G) do print(k) end` を入れて global 一覧を見る
2. `data` がない場合は `mainObject.main.data` や `data` の require 元 (`src/Data/` 下の Lua) を直接 dofile する
3. JSON にしたい構造に合わせて adapt

- [ ] **Step 3: commit (動いた版)**

```bash
cd ~/pob2-build-generator
git add scripts/data_export.lua
git commit -m "feat(scripts): data_export.lua dumps PoB skill/unique to JSON"
```

### Task 2.2: Rust の data_dumper サブプロセスランナー

**Files:**
- Create: `src-tauri/src/pob_bridge/mod.rs`
- Create: `src-tauri/src/pob_bridge/data_dumper.rs`
- Test: `src-tauri/src/pob_bridge/data_dumper.rs` (inline test)

- [ ] **Step 1: mod.rs を作成**

`src-tauri/src/pob_bridge/mod.rs`:

```rust
pub mod data_dumper;
pub mod data_reader;
pub mod worker;
```

- [ ] **Step 2: failing test を書く**

`src-tauri/src/pob_bridge/data_dumper.rs`:

```rust
use std::path::{Path, PathBuf};
use std::process::Command;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum DumpError {
    #[error("luajit not found in PATH")]
    LuajitNotFound,
    #[error("data export script failed: {0}")]
    ScriptFailed(String),
    #[error("io error: {0}")]
    Io(#[from] std::io::Error),
}

pub struct DataDumper {
    script_path: PathBuf,
    pob_install_path: PathBuf,
}

impl DataDumper {
    pub fn new(script_path: PathBuf, pob_install_path: PathBuf) -> Self {
        Self { script_path, pob_install_path }
    }

    pub fn dump(&self, output_path: &Path) -> Result<(), DumpError> {
        let out = Command::new("luajit")
            .arg(&self.script_path)
            .arg(&self.pob_install_path)
            .arg(output_path)
            .output()?;
        if !out.status.success() {
            return Err(DumpError::ScriptFailed(
                String::from_utf8_lossy(&out.stderr).to_string(),
            ));
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::env;

    #[test]
    #[ignore]  // requires luajit + PoB install, run via `cargo test -- --ignored`
    fn dump_produces_valid_json() {
        let repo_root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).parent().unwrap().to_path_buf();
        let script = repo_root.join("scripts/data_export.lua");
        let pob = PathBuf::from(env::var("POB_PATH").unwrap_or_else(|_| {
            "/Users/kokage/national-operations".to_string()
        }));
        let out = tempfile::NamedTempFile::new().unwrap();
        let dumper = DataDumper::new(script, pob);
        dumper.dump(out.path()).expect("dump should succeed");
        let json: serde_json::Value = serde_json::from_str(
            &std::fs::read_to_string(out.path()).unwrap()
        ).expect("output should be valid JSON");
        assert!(json.get("skills").is_some());
        assert!(json.get("uniques").is_some());
    }
}
```

- [ ] **Step 3: tempfile を dev-dep に追加**

`src-tauri/Cargo.toml` の `[dev-dependencies]`:

```toml
tempfile = "3"
```

- [ ] **Step 4: ignored test を走らせて PASS 確認 (PoB が install 済み前提)**

```bash
cd ~/pob2-build-generator/src-tauri
cargo test --test=- -- --ignored pob_bridge::data_dumper::tests::dump_produces_valid_json
```

Expected: PASS (luajit + PoB install path が正しい前提)。fail する場合は `data_export.lua` の修正を Task 2.1 に戻って実施。

- [ ] **Step 5: commit**

```bash
cd ~/pob2-build-generator
git add src-tauri/src/pob_bridge/mod.rs src-tauri/src/pob_bridge/data_dumper.rs src-tauri/Cargo.toml
git commit -m "feat(pob_bridge): DataDumper spawns luajit data_export.lua subprocess"
```

### Task 2.3: Rust 側 JSON cache reader (型付き structs)

**Files:**
- Create: `src-tauri/src/pob_bridge/data_reader.rs`
- Test: inline test

- [ ] **Step 1: failing test を書く**

`src-tauri/src/pob_bridge/data_reader.rs`:

```rust
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::Path;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum ReadError {
    #[error("io: {0}")]
    Io(#[from] std::io::Error),
    #[error("json: {0}")]
    Json(#[from] serde_json::Error),
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Skill {
    pub id: String,
    pub name: String,
    #[serde(default)]
    pub gem_tags: HashMap<String, bool>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Unique {
    pub name: String,
    #[serde(rename = "baseName")]
    pub base_name: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PobData {
    pub skills: HashMap<String, Skill>,
    pub uniques: HashMap<String, Vec<Unique>>,
}

impl PobData {
    pub fn load_from(path: &Path) -> Result<Self, ReadError> {
        let data = std::fs::read_to_string(path)?;
        let parsed: PobData = serde_json::from_str(&data)?;
        Ok(parsed)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;

    #[test]
    fn load_from_parses_minimal_json() {
        let mut f = tempfile::NamedTempFile::new().unwrap();
        f.write_all(br#"{
            "skills": {
                "LightningArrow": { "id": "LightningArrow", "name": "Lightning Arrow", "gem_tags": {} }
            },
            "uniques": {
                "Weapon": [{ "name": "Quill Rain", "baseName": "Short Bow" }]
            }
        }"#).unwrap();
        let data = PobData::load_from(f.path()).unwrap();
        assert_eq!(data.skills.len(), 1);
        assert_eq!(data.uniques.get("Weapon").unwrap().len(), 1);
        assert_eq!(data.uniques["Weapon"][0].name, "Quill Rain");
    }
}
```

- [ ] **Step 2: test PASS 確認**

```bash
cd ~/pob2-build-generator/src-tauri
cargo test pob_bridge::data_reader::tests::load_from_parses_minimal_json
```

Expected: PASS

- [ ] **Step 3: commit**

```bash
cd ~/pob2-build-generator
git add src-tauri/src/pob_bridge/data_reader.rs
git commit -m "feat(pob_bridge): PobData reader with Skill/Unique typed structs"
```

### Task 2.4: settings 永続化 (PoB install path)

**Files:**
- Create: `src-tauri/src/settings.rs`
- Modify: `src-tauri/src/lib.rs` (mod 追加)
- Test: inline

- [ ] **Step 1: failing test を書く**

`src-tauri/src/settings.rs`:

```rust
use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, Serialize, Deserialize, Default, PartialEq)]
pub struct Settings {
    pub pob_install_path: Option<PathBuf>,
}

impl Settings {
    pub fn load(path: &Path) -> Self {
        std::fs::read_to_string(path)
            .ok()
            .and_then(|s| serde_json::from_str(&s).ok())
            .unwrap_or_default()
    }

    pub fn save(&self, path: &Path) -> std::io::Result<()> {
        let s = serde_json::to_string_pretty(self).unwrap();
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent)?;
        }
        std::fs::write(path, s)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn save_then_load_roundtrip() {
        let tmp = tempfile::NamedTempFile::new().unwrap();
        let s = Settings {
            pob_install_path: Some(PathBuf::from("/foo/pob")),
        };
        s.save(tmp.path()).unwrap();
        let loaded = Settings::load(tmp.path());
        assert_eq!(loaded, s);
    }

    #[test]
    fn load_returns_default_when_missing() {
        let path = PathBuf::from("/nonexistent/path/settings.json");
        let loaded = Settings::load(&path);
        assert_eq!(loaded, Settings::default());
    }
}
```

- [ ] **Step 2: lib.rs に mod 追加**

```rust
mod commands;
mod settings;
mod types;
mod pob_bridge;
```

- [ ] **Step 3: test PASS 確認**

```bash
cd ~/pob2-build-generator/src-tauri
cargo test settings::tests
```

Expected: 2 passed.

- [ ] **Step 4: commit**

```bash
cd ~/pob2-build-generator
git add src-tauri/src/settings.rs src-tauri/src/lib.rs
git commit -m "feat(settings): persist pob install path with json file"
```

### Task 2.5: 起動時データロード Tauri command と UI 側 PoB path 設定

**Files:**
- Modify: `src-tauri/src/commands.rs`
- Modify: `src/App.tsx`
- Modify: `src/api/tauri.ts`
- Modify: `src/types/build.ts`

- [ ] **Step 1: Rust 側 command 追加**

`src-tauri/src/commands.rs` に追記:

```rust
use crate::pob_bridge::data_dumper::DataDumper;
use crate::pob_bridge::data_reader::PobData;
use crate::settings::Settings;
use std::path::PathBuf;
use std::sync::Mutex;

pub struct AppState {
    pub settings_path: PathBuf,
    pub cache_path: PathBuf,
    pub script_path: PathBuf,
    pub data: Mutex<Option<PobData>>,
}

#[tauri::command]
pub fn get_settings(state: tauri::State<AppState>) -> Settings {
    Settings::load(&state.settings_path)
}

#[tauri::command]
pub fn set_pob_path(path: String, state: tauri::State<AppState>) -> Result<(), String> {
    let mut s = Settings::load(&state.settings_path);
    s.pob_install_path = Some(PathBuf::from(path));
    s.save(&state.settings_path).map_err(|e| e.to_string())
}

#[tauri::command]
pub fn load_pob_data(state: tauri::State<AppState>) -> Result<usize, String> {
    let s = Settings::load(&state.settings_path);
    let pob = s.pob_install_path.ok_or_else(|| "PoB path not set".to_string())?;
    let dumper = DataDumper::new(state.script_path.clone(), pob);
    dumper.dump(&state.cache_path).map_err(|e| e.to_string())?;
    let data = PobData::load_from(&state.cache_path).map_err(|e| e.to_string())?;
    let skill_count = data.skills.len();
    *state.data.lock().unwrap() = Some(data);
    Ok(skill_count)
}
```

- [ ] **Step 2: lib.rs で AppState を Tauri Builder に渡す**

`src-tauri/src/lib.rs`:

```rust
mod commands;
mod settings;
mod types;
mod pob_bridge;

use commands::AppState;
use std::path::PathBuf;
use std::sync::Mutex;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .setup(|app| {
            let app_data = app.path().app_data_dir().expect("app data dir");
            let resource_dir = app.path().resource_dir().expect("resource dir");
            let state = AppState {
                settings_path: app_data.join("settings.json"),
                cache_path: app_data.join("cache/pob_data.json"),
                script_path: resource_dir.join("scripts/data_export.lua"),
                data: Mutex::new(None),
            };
            app.manage(state);
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            commands::generate,
            commands::get_settings,
            commands::set_pob_path,
            commands::load_pob_data,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
```

- [ ] **Step 3: tauri.conf.json でリソース宣言**

`src-tauri/tauri.conf.json` の `bundle.resources` に `scripts/` を追加 (path は `..` で上に出る):

```json
{
  "bundle": {
    "resources": ["../scripts/*"]
  }
}
```

- [ ] **Step 4: フロント側 type & API 追加**

`src/types/build.ts` に追記:

```typescript
export interface Settings {
  pob_install_path: string | null;
}
```

`src/api/tauri.ts` に追記:

```typescript
import type { Settings } from '../types/build';

export async function getSettings(): Promise<Settings> {
  return await invoke<Settings>('get_settings');
}

export async function setPobPath(path: string): Promise<void> {
  return await invoke<void>('set_pob_path', { path });
}

export async function loadPobData(): Promise<number> {
  return await invoke<number>('load_pob_data');
}
```

- [ ] **Step 5: App.tsx に PoB path 設定 UI と load 呼び出し追加**

`src/App.tsx`:

```tsx
import { useEffect, useState } from 'react';
import { generate, getSettings, setPobPath, loadPobData } from './api/tauri';
import type { GenerateResponse } from './types/build';

export default function App() {
  const [pobPath, setPobPathState] = useState('');
  const [skillCount, setSkillCount] = useState<number | null>(null);
  const [result, setResult] = useState<GenerateResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    getSettings().then(s => {
      if (s.pob_install_path) setPobPathState(s.pob_install_path);
    });
  }, []);

  const onSavePath = async () => {
    await setPobPath(pobPath);
  };

  const onLoadData = async () => {
    setLoading(true);
    setError(null);
    try {
      const n = await loadPobData();
      setSkillCount(n);
    } catch (e) {
      setError(String(e));
    } finally {
      setLoading(false);
    }
  };

  const onGenerate = async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await generate({ class: 'Ranger', main_skill: 'Lightning Arrow' });
      setResult(res);
    } catch (e) {
      setError(String(e));
    } finally {
      setLoading(false);
    }
  };

  return (
    <main style={{ padding: 24, fontFamily: 'sans-serif' }}>
      <h1>PoB2 Build Generator</h1>

      <section>
        <h2>Settings</h2>
        <label>
          PoB Install Path:
          <input value={pobPath} onChange={e => setPobPathState(e.target.value)} style={{ width: 400 }} />
        </label>
        <button onClick={onSavePath}>Save</button>
        <button onClick={onLoadData} disabled={loading}>Load PoB Data</button>
        {skillCount !== null && <span> Loaded {skillCount} skills.</span>}
      </section>

      <section style={{ marginTop: 16 }}>
        <h2>Generate</h2>
        <button onClick={onGenerate} disabled={loading || skillCount === null}>
          {loading ? 'Generating…' : 'Generate'}
        </button>
        {error && <p style={{ color: 'red' }}>{error}</p>}
        {result && (
          <div>
            <p>DPS: {result.dps.toLocaleString()}</p>
            <pre>{result.build_code}</pre>
          </div>
        )}
      </section>
    </main>
  );
}
```

- [ ] **Step 6: 動作確認**

```bash
cd ~/pob2-build-generator
npm run tauri dev
```

- PoB path に `/Users/kokage/national-operations` を入れて Save
- Load PoB Data を押す
- skill count が表示されることを確認
- Generate ボタンで stub DPS が出る

- [ ] **Step 7: commit**

```bash
cd ~/pob2-build-generator
git add src-tauri/src/commands.rs src-tauri/src/lib.rs src-tauri/tauri.conf.json \
        src/App.tsx src/api/tauri.ts src/types/build.ts
git commit -m "feat: load PoB data via dumper, expose to UI via tauri commands"
```

---

## Phase 3: PoB Worker (long-lived luajit subprocess for calc)

実 PoB calc を呼べるようにする。stub の固定 DPS を捨てる。

### Task 3.1: pob_worker.lua の REPL skeleton

**Files:**
- Create: `scripts/pob_worker.lua`

- [ ] **Step 1: worker script 作成**

`scripts/pob_worker.lua`:

```lua
-- pob_worker.lua
-- 使い方: luajit pob_worker.lua <pob-install-path>
-- stdin に "BUILD <length>\n<xml>" を流すと stdout に stats JSON が返る
-- "EXIT" で終了

local pobPath = arg[1] or error("usage: luajit pob_worker.lua <pob-path>")

local lfs_ok, lfs = pcall(require, "lfs")
if lfs_ok then lfs.chdir(pobPath .. "/src") end

dofile("HeadlessWrapper.lua")

-- Stats 抽出 (最低限の MVP: DPS と Life)
local function extractStats(build)
    local out = build.calcsTab and build.calcsTab.mainOutput or {}
    local stats = {
        dps = out.CombinedDPS or out.TotalDPS or 0,
        ehp = out.TotalEHP or out.Life or 0,
        life = out.Life or 0,
    }
    return stats
end

-- JSON encode (dkjson or fallback)
local json_ok, json = pcall(require, "dkjson")
if not json_ok then
    json = require("scripts.minimal_json") or error("install dkjson or provide fallback")
end

-- REPL loop
io.stdout:setvbuf("line")
while true do
    local line = io.read("*l")
    if not line then break end
    if line == "EXIT" then break end
    if line:sub(1, 6) == "BUILD " then
        local length = tonumber(line:sub(7))
        if not length then
            io.stdout:write('{"error":"bad BUILD command"}\n')
        else
            local xml = io.read(length)
            local ok, err = pcall(loadBuildFromXML, xml, "tmp")
            if not ok then
                io.stdout:write('{"error":' .. string.format("%q", tostring(err)) .. '}\n')
            else
                runCallback("OnFrame")  -- ensure calc tab refreshes
                local stats = extractStats(build)
                io.stdout:write(json.encode(stats) .. "\n")
            end
        end
        io.stdout:flush()
    end
end
```

- [ ] **Step 2: 手動テスト (stdin から build xml を流す)**

サンプル build xml を `/tmp/sample_build.xml` に手で作る (最小限の PoB build xml、例えば PoB から新規 build を作って Export → XML)。

```bash
LEN=$(wc -c < /tmp/sample_build.xml | tr -d ' ')
{
  echo "BUILD $LEN"
  cat /tmp/sample_build.xml
  echo "EXIT"
} | luajit ~/pob2-build-generator/scripts/pob_worker.lua /Users/kokage/national-operations
```

Expected: 1 行の JSON が返る (例: `{"dps":0,"ehp":0,"life":50}`)。エラーが出る場合は `extractStats` の path や HeadlessWrapper の表示を調整。

- [ ] **Step 3: commit (worker が動いた版)**

```bash
cd ~/pob2-build-generator
git add scripts/pob_worker.lua
git commit -m "feat(scripts): pob_worker.lua - long-lived luajit REPL for build calc"
```

### Task 3.2: Rust 側 worker bridge

**Files:**
- Create: `src-tauri/src/pob_bridge/worker.rs`
- Test: inline (ignored, manual)

- [ ] **Step 1: failing test を書く**

`src-tauri/src/pob_bridge/worker.rs`:

```rust
use serde::{Deserialize, Serialize};
use std::io::{BufRead, BufReader, Write};
use std::path::PathBuf;
use std::process::{Child, ChildStdin, ChildStdout, Command, Stdio};
use thiserror::Error;

#[derive(Debug, Error)]
pub enum WorkerError {
    #[error("io: {0}")]
    Io(#[from] std::io::Error),
    #[error("json: {0}")]
    Json(#[from] serde_json::Error),
    #[error("worker error: {0}")]
    Worker(String),
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CalcStats {
    pub dps: f64,
    pub ehp: f64,
    pub life: f64,
}

pub struct PobWorker {
    child: Child,
    stdin: ChildStdin,
    stdout: BufReader<ChildStdout>,
}

impl PobWorker {
    pub fn spawn(script_path: &std::path::Path, pob_install_path: &std::path::Path) -> Result<Self, WorkerError> {
        let mut child = Command::new("luajit")
            .arg(script_path)
            .arg(pob_install_path)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::inherit())
            .spawn()?;
        let stdin = child.stdin.take().unwrap();
        let stdout = BufReader::new(child.stdout.take().unwrap());
        Ok(Self { child, stdin, stdout })
    }

    pub fn calc(&mut self, build_xml: &str) -> Result<CalcStats, WorkerError> {
        let len = build_xml.len();
        writeln!(self.stdin, "BUILD {}", len)?;
        self.stdin.write_all(build_xml.as_bytes())?;
        self.stdin.flush()?;

        let mut line = String::new();
        self.stdout.read_line(&mut line)?;
        let parsed: serde_json::Value = serde_json::from_str(line.trim())?;
        if let Some(err) = parsed.get("error") {
            return Err(WorkerError::Worker(err.to_string()));
        }
        let stats: CalcStats = serde_json::from_value(parsed)?;
        Ok(stats)
    }

    pub fn shutdown(mut self) -> Result<(), WorkerError> {
        writeln!(self.stdin, "EXIT")?;
        self.stdin.flush()?;
        self.child.wait()?;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    #[ignore]  // requires luajit + PoB
    fn worker_calc_returns_stats() {
        let repo_root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).parent().unwrap().to_path_buf();
        let script = repo_root.join("scripts/pob_worker.lua");
        let pob = PathBuf::from(std::env::var("POB_PATH").unwrap_or_else(|_| {
            "/Users/kokage/national-operations".to_string()
        }));
        let sample = std::fs::read_to_string(std::env::var("POB_SAMPLE_XML").unwrap_or_else(|_| {
            "/tmp/sample_build.xml".to_string()
        })).expect("provide sample build xml");
        let mut w = PobWorker::spawn(&script, &pob).unwrap();
        let stats = w.calc(&sample).unwrap();
        // sample build によるが、少なくとも life > 0 のはず
        assert!(stats.life > 0.0);
        w.shutdown().unwrap();
    }
}
```

- [ ] **Step 2: ignored test を走らせて PASS 確認**

```bash
cd ~/pob2-build-generator/src-tauri
cargo test pob_bridge::worker::tests::worker_calc_returns_stats -- --ignored
```

Expected: PASS (sample xml と PoB path が正しい前提)。

- [ ] **Step 3: commit**

```bash
cd ~/pob2-build-generator
git add src-tauri/src/pob_bridge/worker.rs
git commit -m "feat(pob_bridge): PobWorker - long-lived luajit subprocess bridge"
```

### Task 3.3: AppState に worker 持たせる + generate から calc 呼ぶ

**Files:**
- Modify: `src-tauri/src/commands.rs`
- Modify: `src-tauri/src/lib.rs`

- [ ] **Step 1: AppState に worker 追加 + generate 修正**

`src-tauri/src/commands.rs` を以下に置換:

```rust
use crate::pob_bridge::data_dumper::DataDumper;
use crate::pob_bridge::data_reader::PobData;
use crate::pob_bridge::worker::{CalcStats, PobWorker};
use crate::settings::Settings;
use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use std::sync::Mutex;

pub struct AppState {
    pub settings_path: PathBuf,
    pub cache_path: PathBuf,
    pub data_script_path: PathBuf,
    pub worker_script_path: PathBuf,
    pub data: Mutex<Option<PobData>>,
    pub worker: Mutex<Option<PobWorker>>,
}

#[derive(Debug, Serialize, Deserialize, PartialEq)]
pub struct GenerateRequest {
    pub class: String,
    pub main_skill: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct GenerateResponse {
    pub dps: f64,
    pub ehp: f64,
    pub build_code: String,
}

#[tauri::command]
pub fn get_settings(state: tauri::State<AppState>) -> Settings {
    Settings::load(&state.settings_path)
}

#[tauri::command]
pub fn set_pob_path(path: String, state: tauri::State<AppState>) -> Result<(), String> {
    let mut s = Settings::load(&state.settings_path);
    s.pob_install_path = Some(PathBuf::from(path));
    s.save(&state.settings_path).map_err(|e| e.to_string())
}

#[tauri::command]
pub fn load_pob_data(state: tauri::State<AppState>) -> Result<usize, String> {
    let s = Settings::load(&state.settings_path);
    let pob = s.pob_install_path.ok_or_else(|| "PoB path not set".to_string())?;
    let dumper = DataDumper::new(state.data_script_path.clone(), pob.clone());
    dumper.dump(&state.cache_path).map_err(|e| e.to_string())?;
    let data = PobData::load_from(&state.cache_path).map_err(|e| e.to_string())?;
    let skill_count = data.skills.len();
    *state.data.lock().unwrap() = Some(data);

    // worker も起動
    let mut wlock = state.worker.lock().unwrap();
    if wlock.is_none() {
        let w = PobWorker::spawn(&state.worker_script_path, &pob).map_err(|e| e.to_string())?;
        *wlock = Some(w);
    }
    Ok(skill_count)
}

#[tauri::command]
pub fn generate(req: GenerateRequest, state: tauri::State<AppState>) -> Result<GenerateResponse, String> {
    // Phase 3 stub: PoB がデフォルト build をそのまま load した結果を返す
    // 後続 phase で optimizer に置換
    let stub_xml = include_str!("../../docs/sample_build.xml");
    let mut wlock = state.worker.lock().unwrap();
    let w = wlock.as_mut().ok_or_else(|| "worker not initialized; call load_pob_data first".to_string())?;
    let stats: CalcStats = w.calc(stub_xml).map_err(|e| e.to_string())?;
    Ok(GenerateResponse {
        dps: stats.dps,
        ehp: stats.ehp,
        build_code: format!("STUB-{}-{}", req.class, req.main_skill),
    })
}
```

- [ ] **Step 2: sample_build.xml をリポに用意**

```bash
mkdir -p ~/pob2-build-generator/src-tauri/../docs
# PoB から新規 build (例えば Ranger / Lightning Arrow) を作って Export -> XML
# Export 内容を以下に保存
cp /tmp/sample_build.xml ~/pob2-build-generator/docs/sample_build.xml
```

- [ ] **Step 3: lib.rs を worker 対応に更新**

`src-tauri/src/lib.rs`:

```rust
mod commands;
mod settings;
mod types;
mod pob_bridge;

use commands::AppState;
use std::sync::Mutex;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .setup(|app| {
            let app_data = app.path().app_data_dir().expect("app data dir");
            let resource_dir = app.path().resource_dir().expect("resource dir");
            let state = AppState {
                settings_path: app_data.join("settings.json"),
                cache_path: app_data.join("cache/pob_data.json"),
                data_script_path: resource_dir.join("scripts/data_export.lua"),
                worker_script_path: resource_dir.join("scripts/pob_worker.lua"),
                data: Mutex::new(None),
                worker: Mutex::new(None),
            };
            app.manage(state);
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            commands::generate,
            commands::get_settings,
            commands::set_pob_path,
            commands::load_pob_data,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
```

- [ ] **Step 4: フロント側 type 更新**

`src/types/build.ts`:

```typescript
export interface GenerateRequest {
  class: string;
  main_skill: string;
}

export interface GenerateResponse {
  dps: number;
  ehp: number;
  build_code: string;
}

export interface Settings {
  pob_install_path: string | null;
}
```

`src/App.tsx` の result 表示部分に EHP も追加:

```tsx
{result && (
  <div>
    <p>DPS: {result.dps.toLocaleString()}  EHP: {result.ehp.toLocaleString()}</p>
    <pre>{result.build_code}</pre>
  </div>
)}
```

- [ ] **Step 5: 動作確認**

```bash
cd ~/pob2-build-generator
npm run tauri dev
```

PoB path Save → Load PoB Data → Generate → DPS と EHP が実数値で表示される。stub の固定 12345 ではなく PoB の実計算結果。

- [ ] **Step 6: commit**

```bash
cd ~/pob2-build-generator
git add src-tauri/src/commands.rs src-tauri/src/lib.rs docs/sample_build.xml \
        src/App.tsx src/types/build.ts
git commit -m "feat: route generate through PoB worker to get real DPS/EHP from stub build"
```

---

## Phase 4: Core Models & Build XML

BuildModel と PoB build code (xml) シリアライザを Rust に作る。これで optimizer の出力を PoB に渡せるようになる。

### Task 4.1: BuildModel & 関連 enum 定義

**Files:**
- Create: `src-tauri/src/core/mod.rs`
- Create: `src-tauri/src/core/model.rs`
- Modify: `src-tauri/src/lib.rs`
- Test: inline

- [ ] **Step 1: mod.rs**

`src-tauri/src/core/mod.rs`:

```rust
pub mod model;
pub mod intent;
pub mod fitness;
pub mod optimizer;
pub mod pob_xml;
```

- [ ] **Step 2: model.rs を書く + test**

`src-tauri/src/core/model.rs`:

```rust
use serde::{Deserialize, Serialize};
use std::collections::{BTreeSet, HashMap};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum Class {
    Warrior, Ranger, Witch, Sorceress, Monk, Mercenary, Druid, Huntress,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum Slot {
    Weapon1, Weapon2, Helmet, Body, Gloves, Boots, Belt, Amulet, Ring1, Ring2,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum DamageType {
    Physical, Fire, Cold, Lightning, Chaos,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ItemRef {
    Unique { name: String },
    Rare { base_name: String, mods: Vec<String> },
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct BuildModel {
    pub class: Option<Class>,
    pub ascendancy: Option<String>,
    pub main_skill: Option<String>,
    pub sub_skills: Vec<String>,
    pub locked_items: HashMap<Slot, ItemRef>,
    pub candidate_items: HashMap<Slot, ItemRef>,
    pub passive_tree: BTreeSet<u32>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn build_model_serializes_roundtrip() {
        let mut m = BuildModel::default();
        m.class = Some(Class::Ranger);
        m.main_skill = Some("LightningArrow".to_string());
        m.locked_items.insert(Slot::Weapon1, ItemRef::Unique { name: "Quill Rain".to_string() });
        m.passive_tree.insert(42);
        let json = serde_json::to_string(&m).unwrap();
        let back: BuildModel = serde_json::from_str(&json).unwrap();
        assert_eq!(back.class, Some(Class::Ranger));
        assert!(back.passive_tree.contains(&42));
    }
}
```

- [ ] **Step 3: lib.rs に mod 追加**

```rust
mod commands;
mod core;
mod settings;
mod types;
mod pob_bridge;
```

- [ ] **Step 4: test PASS 確認**

```bash
cd ~/pob2-build-generator/src-tauri
cargo test core::model::tests::build_model_serializes_roundtrip
```

Expected: PASS

- [ ] **Step 5: commit**

```bash
cd ~/pob2-build-generator
git add src-tauri/src/core/mod.rs src-tauri/src/core/model.rs src-tauri/src/lib.rs
git commit -m "feat(core): BuildModel with class/skill/items/passive_tree fields"
```

### Task 4.2: BuildModel → PoB xml シリアライザ (最小実装)

**Files:**
- Create: `src-tauri/src/core/pob_xml.rs`
- Test: inline + 整合 test (PoB worker に投げて parse OK)

- [ ] **Step 1: PoB build code xml の最小 schema を確認**

実 PoB build code は複雑だが、最小限以下を含む xml が parse 可能:

```xml
<PathOfBuilding>
  <Build level="95" targetVersion="3_0" className="Ranger" ascendClassName="Deadeye" mainSocketGroup="1"/>
  <Skills sortGemsByDPS="true" defaultGemQuality="0">
    <SkillSet id="1">
      <Skill mainActiveSkill="1" enabled="true">
        <Gem level="20" quality="20" enabled="true" gemId="Metadata/Items/Gems/SkillGemLightningArrow" nameSpec="Lightning Arrow"/>
      </Skill>
    </SkillSet>
  </Skills>
  <Tree>
    <Spec treeVersion="3_0"><URL>https://www.pathofexile.com/passive-skill-tree/AAAAAA==</URL></Spec>
  </Tree>
  <Items/>
  <Notes/>
</PathOfBuilding>
```

**重要**: 実 PoB の最新フォーマットは `~/national-operations/src/Classes/ImportTab.lua` または `~/national-operations/src/Modules/BuildSiteTools.lua` に rendering 関数があるので、まず実 PoB が export する最小 build xml を取得して参考にする。

- [ ] **Step 2: failing test を書く**

`src-tauri/src/core/pob_xml.rs`:

```rust
use crate::core::model::{BuildModel, Class};

pub fn serialize(build: &BuildModel) -> String {
    let class_name = match build.class {
        Some(Class::Ranger) => "Ranger",
        Some(Class::Warrior) => "Warrior",
        Some(Class::Witch) => "Witch",
        Some(Class::Sorceress) => "Sorceress",
        Some(Class::Monk) => "Monk",
        Some(Class::Mercenary) => "Mercenary",
        Some(Class::Druid) => "Druid",
        Some(Class::Huntress) => "Huntress",
        None => "Ranger",
    };
    let ascendancy = build.ascendancy.as_deref().unwrap_or("");
    let main_skill_id = build.main_skill.as_deref().unwrap_or("");

    format!(
        r#"<?xml version="1.0" encoding="UTF-8"?>
<PathOfBuilding>
  <Build level="95" targetVersion="3_0" className="{class}" ascendClassName="{asc}" mainSocketGroup="1"/>
  <Skills sortGemsByDPS="true" defaultGemQuality="0">
    <SkillSet id="1">
      <Skill mainActiveSkill="1" enabled="true">
        <Gem level="20" quality="20" enabled="true" gemId="Metadata/Items/Gems/SkillGem{skill}" nameSpec="{skill}"/>
      </Skill>
    </SkillSet>
  </Skills>
  <Tree>
    <Spec treeVersion="3_0"><URL>https://www.pathofexile.com/passive-skill-tree/AAAAAA==</URL></Spec>
  </Tree>
  <Items/>
  <Notes/>
</PathOfBuilding>"#,
        class = class_name,
        asc = ascendancy,
        skill = main_skill_id,
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::core::model::BuildModel;

    #[test]
    fn serialize_includes_class_and_skill() {
        let mut m = BuildModel::default();
        m.class = Some(Class::Ranger);
        m.main_skill = Some("LightningArrow".to_string());
        m.ascendancy = Some("Deadeye".to_string());
        let xml = serialize(&m);
        assert!(xml.contains(r#"className="Ranger""#));
        assert!(xml.contains(r#"ascendClassName="Deadeye""#));
        assert!(xml.contains("LightningArrow"));
        assert!(xml.starts_with("<?xml"));
    }
}
```

- [ ] **Step 3: test PASS 確認**

```bash
cd ~/pob2-build-generator/src-tauri
cargo test core::pob_xml::tests::serialize_includes_class_and_skill
```

Expected: PASS

- [ ] **Step 4: integration test - 生成 xml を PoB worker に投げて parse OK 確認**

`src-tauri/src/core/pob_xml.rs` の test に追加:

```rust
    #[test]
    #[ignore]  // requires luajit + PoB
    fn serialized_xml_parses_in_pob_worker() {
        use crate::pob_bridge::worker::PobWorker;
        use std::path::PathBuf;

        let mut m = BuildModel::default();
        m.class = Some(Class::Ranger);
        m.main_skill = Some("LightningArrow".to_string());
        m.ascendancy = Some("Deadeye".to_string());
        let xml = serialize(&m);

        let repo_root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).parent().unwrap().to_path_buf();
        let script = repo_root.join("scripts/pob_worker.lua");
        let pob = PathBuf::from(std::env::var("POB_PATH").unwrap_or_else(|_| {
            "/Users/kokage/national-operations".to_string()
        }));
        let mut w = PobWorker::spawn(&script, &pob).unwrap();
        let stats = w.calc(&xml).expect("PoB worker should parse our xml");
        assert!(stats.life >= 0.0);  // 最低限 calc が落ちずに数値返れば OK
        w.shutdown().unwrap();
    }
```

```bash
cd ~/pob2-build-generator/src-tauri
cargo test core::pob_xml::tests::serialized_xml_parses_in_pob_worker -- --ignored
```

Expected: PASS。fail する場合は xml の schema を実 PoB の export 結果に合わせて調整 (skill gemId 形式、tree version、その他フォーマット詳細)。

- [ ] **Step 5: commit**

```bash
cd ~/pob2-build-generator
git add src-tauri/src/core/pob_xml.rs
git commit -m "feat(core): BuildModel -> PoB xml serializer (minimal schema)"
```

---

## Phase 5: BuildIntent と Fitness (Greedy の準備)

### Task 5.1: BuildIntent::infer (skill tag ベース、最小実装)

**Files:**
- Create: `src-tauri/src/core/intent.rs`
- Test: inline

- [ ] **Step 1: 型と infer skeleton + test**

`src-tauri/src/core/intent.rs`:

```rust
use crate::core::model::DamageType;
use crate::pob_bridge::data_reader::{PobData, Skill};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, Default, PartialEq)]
pub struct BuildIntent {
    pub damage_types: Vec<DamageType>,
    pub crit_oriented: bool,
}

impl BuildIntent {
    pub fn infer(main_skill: &Skill, _sub_skills: &[Skill], _key_items: &[String]) -> Self {
        let mut damage_types = Vec::new();
        for (tag, on) in &main_skill.gem_tags {
            if !*on { continue; }
            let dt = match tag.as_str() {
                "lightning" => Some(DamageType::Lightning),
                "fire" => Some(DamageType::Fire),
                "cold" => Some(DamageType::Cold),
                "physical" => Some(DamageType::Physical),
                "chaos" => Some(DamageType::Chaos),
                _ => None,
            };
            if let Some(t) = dt {
                if !damage_types.contains(&t) {
                    damage_types.push(t);
                }
            }
        }
        let crit_oriented = main_skill.gem_tags.get("critical").copied().unwrap_or(false);
        BuildIntent { damage_types, crit_oriented }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashMap;

    #[test]
    fn infers_lightning_from_skill_tag() {
        let mut tags = HashMap::new();
        tags.insert("lightning".to_string(), true);
        tags.insert("attack".to_string(), true);
        let s = Skill {
            id: "LightningArrow".to_string(),
            name: "Lightning Arrow".to_string(),
            gem_tags: tags,
        };
        let intent = BuildIntent::infer(&s, &[], &[]);
        assert_eq!(intent.damage_types, vec![DamageType::Lightning]);
        assert!(!intent.crit_oriented);
    }

    #[test]
    fn infers_crit_oriented_when_tag_present() {
        let mut tags = HashMap::new();
        tags.insert("critical".to_string(), true);
        let s = Skill {
            id: "Spark".to_string(),
            name: "Spark".to_string(),
            gem_tags: tags,
        };
        let intent = BuildIntent::infer(&s, &[], &[]);
        assert!(intent.crit_oriented);
    }
}
```

- [ ] **Step 2: data_reader.rs の Skill struct に PartialEq + gem_tags の HashMap が必要なので確認** (Task 2.3 で既に追加済み)

- [ ] **Step 3: test PASS 確認**

```bash
cd ~/pob2-build-generator/src-tauri
cargo test core::intent::tests
```

Expected: 2 passed.

- [ ] **Step 4: commit**

```bash
cd ~/pob2-build-generator
git add src-tauri/src/core/intent.rs
git commit -m "feat(core): BuildIntent::infer derives damage types and crit from skill tags"
```

### Task 5.2: Rust 概算 fitness function (Balanced preset)

**Files:**
- Create: `src-tauri/src/core/fitness.rs`
- Test: inline

- [ ] **Step 1: fitness + Balanced preset 実装 + test**

`src-tauri/src/core/fitness.rs`:

```rust
use crate::core::intent::BuildIntent;
use crate::core::model::DamageType;
use crate::pob_bridge::worker::CalcStats;

pub fn balanced_fitness(stats: &CalcStats, resists_capped: bool) -> f64 {
    if !resists_capped {
        return -1e6;
    }
    let dps = stats.dps.max(1.0);
    let ehp = stats.ehp.max(1.0);
    dps.ln() + 0.5 * ehp.ln()
}

/// 概算 fitness: mod の合計値から推定 (PoB headless 不要)。
/// 厳密ではないが greedy の相対順位に使う。
pub fn approx_dps_contribution(
    mod_tags: &[String],
    mod_value: f64,
    intent: &BuildIntent,
) -> f64 {
    let mut weight = 0.0;
    for tag in mod_tags {
        match tag.as_str() {
            "damage" => weight += 1.0,
            "lightning" if intent.damage_types.contains(&DamageType::Lightning) => weight += 1.5,
            "fire" if intent.damage_types.contains(&DamageType::Fire) => weight += 1.5,
            "cold" if intent.damage_types.contains(&DamageType::Cold) => weight += 1.5,
            "physical" if intent.damage_types.contains(&DamageType::Physical) => weight += 1.5,
            "critical" if intent.crit_oriented => weight += 1.2,
            _ => {}
        }
    }
    weight * mod_value
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashMap;

    #[test]
    fn balanced_fitness_punishes_uncapped_resists() {
        let stats = CalcStats { dps: 1_000_000.0, ehp: 8000.0, life: 5000.0 };
        let with_cap = balanced_fitness(&stats, true);
        let no_cap = balanced_fitness(&stats, false);
        assert!(with_cap > 0.0);
        assert!(no_cap < -100_000.0);
    }

    #[test]
    fn approx_dps_weights_matching_damage_type_higher() {
        let intent = BuildIntent {
            damage_types: vec![DamageType::Lightning],
            crit_oriented: false,
        };
        let lightning_mod = approx_dps_contribution(
            &["damage".to_string(), "lightning".to_string()],
            10.0,
            &intent,
        );
        let fire_mod = approx_dps_contribution(
            &["damage".to_string(), "fire".to_string()],
            10.0,
            &intent,
        );
        assert!(lightning_mod > fire_mod);
    }
}
```

- [ ] **Step 2: test PASS 確認**

```bash
cd ~/pob2-build-generator/src-tauri
cargo test core::fitness::tests
```

Expected: 2 passed.

- [ ] **Step 3: commit**

```bash
cd ~/pob2-build-generator
git add src-tauri/src/core/fitness.rs
git commit -m "feat(core): balanced_fitness + approx_dps_contribution for greedy ranking"
```

---

## Phase 6: Greedy Optimizer (最小実装)

最小限の greedy: passive tree allocation のみ (gear / gem は phase 7 で別 task)。

### Task 6.1: Greedy passive tree allocation (stub passive tree data)

**Files:**
- Create: `src-tauri/src/core/optimizer.rs`
- Test: inline

- [ ] **Step 1: PassiveNode 型と test**

`src-tauri/src/core/optimizer.rs`:

```rust
use crate::core::intent::BuildIntent;
use crate::core::model::BuildModel;
use crate::core::fitness::approx_dps_contribution;
use serde::{Deserialize, Serialize};
use std::collections::{BTreeSet, HashMap};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PassiveNode {
    pub id: u32,
    pub neighbors: Vec<u32>,
    pub mods: Vec<PassiveMod>,
    /// 開始 node (class start) なら true
    pub is_start: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PassiveMod {
    pub tags: Vec<String>,
    pub value: f64,
}

pub struct PassiveTreeData {
    pub nodes: HashMap<u32, PassiveNode>,
}

impl PassiveTreeData {
    pub fn class_start(&self, class_name: &str) -> Option<u32> {
        // 簡易: is_start が true で id が一致するもの。本実装では class → start node id mapping を持つ
        self.nodes.values().find(|n| n.is_start).map(|n| n.id)
        // class_name は phase 7 で使う
    }
}

/// node 一個の概算 fitness 寄与
fn node_value(node: &PassiveNode, intent: &BuildIntent) -> f64 {
    node.mods.iter()
        .map(|m| approx_dps_contribution(&m.tags, m.value, intent))
        .sum()
}

pub fn greedy_allocate_tree(
    tree: &PassiveTreeData,
    intent: &BuildIntent,
    class_name: &str,
    budget: usize,
) -> BTreeSet<u32> {
    let mut allocated: BTreeSet<u32> = BTreeSet::new();
    let Some(start) = tree.class_start(class_name) else { return allocated; };
    allocated.insert(start);

    for _ in 1..budget {
        // 隣接候補 (allocated に未 allocate の neighbor)
        let mut candidates: Vec<u32> = Vec::new();
        for &id in &allocated {
            if let Some(node) = tree.nodes.get(&id) {
                for &n in &node.neighbors {
                    if !allocated.contains(&n) && !candidates.contains(&n) {
                        candidates.push(n);
                    }
                }
            }
        }
        if candidates.is_empty() { break; }
        // 各候補の node_value で argmax
        let best = candidates.into_iter().max_by(|a, b| {
            let va = tree.nodes.get(a).map(|n| node_value(n, intent)).unwrap_or(0.0);
            let vb = tree.nodes.get(b).map(|n| node_value(n, intent)).unwrap_or(0.0);
            va.partial_cmp(&vb).unwrap_or(std::cmp::Ordering::Equal)
        });
        if let Some(b) = best {
            allocated.insert(b);
        } else {
            break;
        }
    }
    allocated
}

pub fn generate_build(
    class: crate::core::model::Class,
    main_skill_id: String,
    intent: &BuildIntent,
    tree: &PassiveTreeData,
) -> BuildModel {
    let mut m = BuildModel::default();
    m.class = Some(class);
    m.main_skill = Some(main_skill_id);
    m.passive_tree = greedy_allocate_tree(tree, intent, "Ranger", 95);
    m
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::core::model::DamageType;

    fn tiny_tree() -> PassiveTreeData {
        let mut nodes = HashMap::new();
        nodes.insert(1, PassiveNode {
            id: 1, neighbors: vec![2, 3], mods: vec![], is_start: true,
        });
        nodes.insert(2, PassiveNode {
            id: 2, neighbors: vec![1], is_start: false,
            mods: vec![PassiveMod { tags: vec!["damage".into(), "lightning".into()], value: 10.0 }],
        });
        nodes.insert(3, PassiveNode {
            id: 3, neighbors: vec![1], is_start: false,
            mods: vec![PassiveMod { tags: vec!["damage".into(), "fire".into()], value: 10.0 }],
        });
        PassiveTreeData { nodes }
    }

    #[test]
    fn greedy_picks_lightning_node_for_lightning_intent() {
        let tree = tiny_tree();
        let intent = BuildIntent {
            damage_types: vec![DamageType::Lightning],
            crit_oriented: false,
        };
        let allocated = greedy_allocate_tree(&tree, &intent, "Ranger", 2);
        assert!(allocated.contains(&1));  // start
        assert!(allocated.contains(&2));  // lightning node
        assert!(!allocated.contains(&3)); // fire node, skipped
    }

    #[test]
    fn greedy_budget_limits_allocation() {
        let tree = tiny_tree();
        let intent = BuildIntent::default();
        let allocated = greedy_allocate_tree(&tree, &intent, "Ranger", 1);
        assert_eq!(allocated.len(), 1); // start only
    }
}
```

- [ ] **Step 2: test PASS 確認**

```bash
cd ~/pob2-build-generator/src-tauri
cargo test core::optimizer::tests
```

Expected: 2 passed.

- [ ] **Step 3: commit**

```bash
cd ~/pob2-build-generator
git add src-tauri/src/core/optimizer.rs
git commit -m "feat(core): greedy passive tree allocation with intent-weighted node values"
```

### Task 6.2: passive tree data ロード (tree-data から)

**Files:**
- Modify: `src-tauri/src/pob_bridge/data_reader.rs`
- Modify: `scripts/data_export.lua` (passive tree も export)

- [ ] **Step 1: data_export.lua に passive tree 追加**

`scripts/data_export.lua` の `local out = {...}` 後に追加:

```lua
-- Passive tree (latest 0_X tree-data から)
-- PoB は通常 build.spec.tree.nodes に load 済みの node 構造を持つ
-- ここではアプローチを 2 つ示す:
-- (a) build.spec.tree.nodes を読む (build を 1 個 load してから)
-- (b) tree-data/0_X/*.lua を直接 dofile (PoB の tree 内部表現)

-- (a) 簡易版: 新規 build を作って tree 取り出す
newBuild()
local tree = build.spec and build.spec.tree
if tree and tree.nodes then
    out.tree = {
        nodes = {},
    }
    for nid, node in pairs(tree.nodes) do
        local nodeOut = {
            id = nid,
            neighbors = {},
            mods = {},
            is_start = node.isAscendancyStart or node.classStartIndex ~= nil,
        }
        for _, conn in ipairs(node.linked or {}) do
            table.insert(nodeOut.neighbors, conn.id)
        end
        -- mods 一覧: node.modList (list of Mod object) を tag + value に
        for _, mod in ipairs(node.modList or {}) do
            local tags = {}
            for tag in pairs(mod.tagTypes or {}) do
                table.insert(tags, tag)
            end
            local value = mod.value or (mod[1] and mod[1].value) or 0
            table.insert(nodeOut.mods, { tags = tags, value = value })
        end
        out.tree.nodes[tostring(nid)] = nodeOut
    end
end
```

注意: PoB の tree 内部表現は版による変化が大きい。実 PoB データで `build.spec.tree.nodes[X]` の構造を 1 個 print して確認、上記が動かなければ field 名を修正。

- [ ] **Step 2: Rust data_reader に Tree 追加**

`src-tauri/src/pob_bridge/data_reader.rs` の `PobData` を拡張:

```rust
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct TreeData {
    pub nodes: HashMap<String, TreeNode>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TreeNode {
    pub id: u32,
    #[serde(default)]
    pub neighbors: Vec<u32>,
    #[serde(default)]
    pub mods: Vec<TreeNodeMod>,
    #[serde(default)]
    pub is_start: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TreeNodeMod {
    #[serde(default)]
    pub tags: Vec<String>,
    #[serde(default)]
    pub value: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct PobData {
    pub skills: HashMap<String, Skill>,
    pub uniques: HashMap<String, Vec<Unique>>,
    #[serde(default)]
    pub tree: TreeData,
}
```

- [ ] **Step 3: optimizer の PassiveTreeData を data_reader の TreeData から変換**

`src-tauri/src/core/optimizer.rs` の最後に追加:

```rust
impl From<&crate::pob_bridge::data_reader::TreeData> for PassiveTreeData {
    fn from(t: &crate::pob_bridge::data_reader::TreeData) -> Self {
        let mut nodes = HashMap::new();
        for (_k, n) in &t.nodes {
            nodes.insert(n.id, PassiveNode {
                id: n.id,
                neighbors: n.neighbors.clone(),
                mods: n.mods.iter().map(|m| PassiveMod {
                    tags: m.tags.clone(),
                    value: m.value,
                }).collect(),
                is_start: n.is_start,
            });
        }
        PassiveTreeData { nodes }
    }
}
```

- [ ] **Step 4: 既存 test がまだ通ることを確認**

```bash
cd ~/pob2-build-generator/src-tauri
cargo test
```

Expected: 既存 test 全 PASS。

- [ ] **Step 5: manual: data_export を再走させて tree が dump される確認**

```bash
luajit ~/pob2-build-generator/scripts/data_export.lua /Users/kokage/national-operations /tmp/pob_data.json
python3 -c "import json; d=json.load(open('/tmp/pob_data.json')); print('tree nodes:', len(d.get('tree',{}).get('nodes',{})))"
```

Expected: `tree nodes: N` で N > 0。tree 構造 dump に失敗してたら data_export.lua の (a) アプローチを (b) tree-data 直 dofile に切り替える。

- [ ] **Step 6: commit**

```bash
cd ~/pob2-build-generator
git add scripts/data_export.lua src-tauri/src/pob_bridge/data_reader.rs \
        src-tauri/src/core/optimizer.rs
git commit -m "feat: passive tree data export/load wiring into optimizer"
```

### Task 6.3: generate Tauri command を greedy optimizer に置換

**Files:**
- Modify: `src-tauri/src/commands.rs`

- [ ] **Step 1: generate を optimizer 経由に書き換え**

`src-tauri/src/commands.rs` の `generate` を以下に置換:

```rust
use crate::core::intent::BuildIntent;
use crate::core::model::Class;
use crate::core::optimizer::{generate_build, PassiveTreeData};
use crate::core::pob_xml;

#[tauri::command]
pub fn generate(req: GenerateRequest, state: tauri::State<AppState>) -> Result<GenerateResponse, String> {
    let data_lock = state.data.lock().unwrap();
    let data = data_lock.as_ref().ok_or_else(|| "PoB data not loaded".to_string())?;

    // skill を data から取得
    let skill = data.skills.get(&req.main_skill)
        .ok_or_else(|| format!("skill not found: {}", req.main_skill))?;

    let intent = BuildIntent::infer(skill, &[], &[]);

    // tree convert
    let tree: PassiveTreeData = (&data.tree).into();

    // class enum
    let class = match req.class.as_str() {
        "Ranger" => Class::Ranger,
        "Warrior" => Class::Warrior,
        "Witch" => Class::Witch,
        "Sorceress" => Class::Sorceress,
        "Monk" => Class::Monk,
        "Mercenary" => Class::Mercenary,
        "Druid" => Class::Druid,
        "Huntress" => Class::Huntress,
        _ => return Err(format!("unknown class: {}", req.class)),
    };

    let build = generate_build(class, req.main_skill.clone(), &intent, &tree);
    let xml = pob_xml::serialize(&build);

    drop(data_lock);  // worker lock 取る前に release

    let mut wlock = state.worker.lock().unwrap();
    let w = wlock.as_mut().ok_or_else(|| "worker not initialized".to_string())?;
    let stats = w.calc(&xml).map_err(|e| e.to_string())?;

    Ok(GenerateResponse {
        dps: stats.dps,
        ehp: stats.ehp,
        build_code: xml,
    })
}
```

- [ ] **Step 2: 動作確認**

```bash
cd ~/pob2-build-generator
npm run tauri dev
```

PoB path Save → Load PoB Data → Generate → DPS / EHP が出る + build_code に greedy allocated tree を含む実 PoB xml が表示される。

- [ ] **Step 3: 生成 build code を PoB に手動 import して動作確認**

UI 表示の `build_code` をコピーして、別ウィンドウの PoB-PoE2 fork (`./scripts/build-app.sh` で起動した GUI) で "Import from text" → 貼り付け → build が読み込まれて allocated tree が表示される。

- [ ] **Step 4: commit**

```bash
cd ~/pob2-build-generator
git add src-tauri/src/commands.rs
git commit -m "feat: generate command runs greedy optimizer + PoB calc end-to-end"
```

---

## Phase 7: Minimum picker UI (class + skill のみ)

key item picker は MVP 範囲外 (空きスロットは全部 optimizer 任せ)。class と main skill だけ user 選択できれば MVP done line に到達。

### Task 7.1: Class / Skill picker components

**Files:**
- Create: `src/components/ClassPicker.tsx`
- Create: `src/components/SkillPicker.tsx`
- Modify: `src/App.tsx`
- Modify: `src-tauri/src/commands.rs` (list_skills command 追加)
- Modify: `src/api/tauri.ts`
- Modify: `src/types/build.ts`

- [ ] **Step 1: Rust 側 list_skills command**

`src-tauri/src/commands.rs` に追加:

```rust
use crate::pob_bridge::data_reader::Skill;

#[tauri::command]
pub fn list_skills(state: tauri::State<AppState>) -> Result<Vec<Skill>, String> {
    let data = state.data.lock().unwrap();
    let data = data.as_ref().ok_or_else(|| "PoB data not loaded".to_string())?;
    let mut out: Vec<Skill> = data.skills.values().cloned().collect();
    out.sort_by(|a, b| a.name.cmp(&b.name));
    Ok(out)
}
```

`src-tauri/src/lib.rs` の invoke_handler に `commands::list_skills` を追加。

- [ ] **Step 2: フロント側 type + API**

`src/types/build.ts` に追加:

```typescript
export interface Skill {
  id: string;
  name: string;
  gem_tags?: Record<string, boolean>;
}
```

`src/api/tauri.ts` に追加:

```typescript
import type { Skill } from '../types/build';

export async function listSkills(): Promise<Skill[]> {
  return await invoke<Skill[]>('list_skills');
}
```

- [ ] **Step 3: ClassPicker component**

`src/components/ClassPicker.tsx`:

```tsx
const CLASSES = ['Warrior', 'Ranger', 'Witch', 'Sorceress', 'Monk', 'Mercenary', 'Druid', 'Huntress'];

interface Props {
  value: string;
  onChange: (v: string) => void;
}

export function ClassPicker({ value, onChange }: Props) {
  return (
    <label>
      Class:{' '}
      <select value={value} onChange={e => onChange(e.target.value)}>
        {CLASSES.map(c => <option key={c} value={c}>{c}</option>)}
      </select>
    </label>
  );
}
```

- [ ] **Step 4: SkillPicker component (fuzzy filter)**

`src/components/SkillPicker.tsx`:

```tsx
import { useState } from 'react';
import type { Skill } from '../types/build';

interface Props {
  skills: Skill[];
  value: string;
  onChange: (skillId: string) => void;
}

export function SkillPicker({ skills, value, onChange }: Props) {
  const [filter, setFilter] = useState('');
  const filtered = skills.filter(s =>
    s.name.toLowerCase().includes(filter.toLowerCase())
  ).slice(0, 50);
  return (
    <div>
      <label>
        Main Skill:{' '}
        <input
          placeholder="filter..."
          value={filter}
          onChange={e => setFilter(e.target.value)}
        />
      </label>
      <select value={value} onChange={e => onChange(e.target.value)} size={10} style={{ width: '100%' }}>
        {filtered.map(s => <option key={s.id} value={s.id}>{s.name}</option>)}
      </select>
    </div>
  );
}
```

- [ ] **Step 5: App.tsx で picker を使う**

`src/App.tsx`:

```tsx
import { useEffect, useState } from 'react';
import { generate, getSettings, setPobPath, loadPobData, listSkills } from './api/tauri';
import type { GenerateResponse, Skill } from './types/build';
import { ClassPicker } from './components/ClassPicker';
import { SkillPicker } from './components/SkillPicker';

export default function App() {
  const [pobPath, setPobPathState] = useState('');
  const [skills, setSkills] = useState<Skill[]>([]);
  const [klass, setKlass] = useState('Ranger');
  const [mainSkill, setMainSkill] = useState('');
  const [result, setResult] = useState<GenerateResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    getSettings().then(s => {
      if (s.pob_install_path) setPobPathState(s.pob_install_path);
    });
  }, []);

  const onLoadData = async () => {
    setLoading(true);
    setError(null);
    try {
      await loadPobData();
      const ss = await listSkills();
      setSkills(ss);
      if (ss[0]) setMainSkill(ss[0].id);
    } catch (e) {
      setError(String(e));
    } finally {
      setLoading(false);
    }
  };

  const onGenerate = async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await generate({ class: klass, main_skill: mainSkill });
      setResult(res);
    } catch (e) {
      setError(String(e));
    } finally {
      setLoading(false);
    }
  };

  return (
    <main style={{ padding: 24, fontFamily: 'sans-serif' }}>
      <h1>PoB2 Build Generator</h1>

      <section>
        <h2>Settings</h2>
        <input value={pobPath} onChange={e => setPobPathState(e.target.value)} style={{ width: 400 }} />
        <button onClick={() => setPobPath(pobPath)}>Save</button>
        <button onClick={onLoadData} disabled={loading}>Load PoB Data</button>
        <span> {skills.length} skills loaded.</span>
      </section>

      {skills.length > 0 && (
        <section style={{ marginTop: 16 }}>
          <h2>Configure</h2>
          <ClassPicker value={klass} onChange={setKlass} />
          <SkillPicker skills={skills} value={mainSkill} onChange={setMainSkill} />
        </section>
      )}

      <section style={{ marginTop: 16 }}>
        <h2>Generate</h2>
        <button onClick={onGenerate} disabled={loading || !mainSkill}>
          {loading ? 'Generating…' : 'Generate'}
        </button>
        {error && <p style={{ color: 'red' }}>{error}</p>}
        {result && (
          <div>
            <p>DPS: {result.dps.toLocaleString()}  EHP: {result.ehp.toLocaleString()}</p>
            <textarea readOnly value={result.build_code} style={{ width: '100%', height: 200 }} />
            <button onClick={() => navigator.clipboard.writeText(result.build_code)}>Copy build code</button>
          </div>
        )}
      </section>
    </main>
  );
}
```

- [ ] **Step 6: 動作確認**

```bash
cd ~/pob2-build-generator
npm run tauri dev
```

PoB path Save → Load PoB Data → Class 選択 → Skill filter で "Lightning" → "Lightning Arrow" 選択 → Generate → DPS/EHP 表示 → build code を Copy → PoB に Import で動作確認。

- [ ] **Step 7: commit**

```bash
cd ~/pob2-build-generator
git add src-tauri/src/commands.rs src-tauri/src/lib.rs \
        src/App.tsx src/components/ClassPicker.tsx src/components/SkillPicker.tsx \
        src/api/tauri.ts src/types/build.ts
git commit -m "feat(ui): class + skill picker + copy build code button"
```

### Task 7.2: KeyItemPicker (Weapon1 unique 限定、lean)

MVP に key item picker を入れる (spec §9 準拠)。lean 縛りで:
- 対応 slot は **Weapon1 のみ** (他 slot は Phase 9)
- 対応 item は **unique のみ** (rare 入力は Phase 9)
- UI は単純な `<select>`、fuzzy 検索や icon 表示なし
- optimizer は locked item を BuildModel に格納するだけ、tree allocation には影響させない (Phase 9 で intent inference に key item 反映)
- xml serializer は locked unique を `<Items>` + `<Slots>` で出力 (PoB の auto-mod populate に任せる)

**Files:**
- Create: `src/components/KeyItemPicker.tsx`
- Modify: `src/types/build.ts`
- Modify: `src/api/tauri.ts`
- Modify: `src/App.tsx`
- Modify: `src-tauri/src/commands.rs`
- Modify: `src-tauri/src/core/pob_xml.rs`
- Modify: `src-tauri/src/core/optimizer.rs`

- [ ] **Step 1: failing test - pob_xml が locked unique を出力する**

`src-tauri/src/core/pob_xml.rs` の test に追加:

```rust
    #[test]
    fn serialize_includes_locked_unique_weapon() {
        use crate::core::model::{ItemRef, Slot};
        let mut m = BuildModel::default();
        m.class = Some(Class::Ranger);
        m.main_skill = Some("LightningArrow".to_string());
        m.locked_items.insert(Slot::Weapon1, ItemRef::Unique {
            name: "Quill Rain".to_string(),
        });
        let xml = serialize(&m);
        assert!(xml.contains("Quill Rain"), "xml should contain unique name");
        assert!(xml.contains(r#"slot="Weapon 1""#) || xml.contains(r#"name="Weapon 1""#),
                "xml should reference Weapon 1 slot");
    }
```

- [ ] **Step 2: serialize を locked_items 対応に拡張**

`src-tauri/src/core/pob_xml.rs` の `serialize` を以下に置換:

```rust
use crate::core::model::{BuildModel, Class, ItemRef, Slot};

fn slot_name(slot: Slot) -> &'static str {
    match slot {
        Slot::Weapon1 => "Weapon 1",
        Slot::Weapon2 => "Weapon 2",
        Slot::Helmet => "Helmet",
        Slot::Body => "Body Armour",
        Slot::Gloves => "Gloves",
        Slot::Boots => "Boots",
        Slot::Belt => "Belt",
        Slot::Amulet => "Amulet",
        Slot::Ring1 => "Ring 1",
        Slot::Ring2 => "Ring 2",
    }
}

fn render_items_and_slots(build: &BuildModel) -> (String, String) {
    let mut items_xml = String::new();
    let mut slots_xml = String::new();
    let mut next_id = 1u32;
    for (slot, item) in &build.locked_items {
        match item {
            ItemRef::Unique { name } => {
                items_xml.push_str(&format!(
                    "    <Item id=\"{id}\">\nRarity: UNIQUE\n{name}\n</Item>\n",
                    id = next_id,
                    name = name,
                ));
                slots_xml.push_str(&format!(
                    "    <Slot name=\"{slot}\" itemId=\"{id}\"/>\n",
                    slot = slot_name(*slot),
                    id = next_id,
                ));
                next_id += 1;
            }
            ItemRef::Rare { .. } => {
                // Phase 9 で対応
            }
        }
    }
    (items_xml, slots_xml)
}

pub fn serialize(build: &BuildModel) -> String {
    let class_name = match build.class {
        Some(Class::Ranger) => "Ranger",
        Some(Class::Warrior) => "Warrior",
        Some(Class::Witch) => "Witch",
        Some(Class::Sorceress) => "Sorceress",
        Some(Class::Monk) => "Monk",
        Some(Class::Mercenary) => "Mercenary",
        Some(Class::Druid) => "Druid",
        Some(Class::Huntress) => "Huntress",
        None => "Ranger",
    };
    let ascendancy = build.ascendancy.as_deref().unwrap_or("");
    let main_skill_id = build.main_skill.as_deref().unwrap_or("");
    let (items_xml, slots_xml) = render_items_and_slots(build);

    format!(
        r#"<?xml version="1.0" encoding="UTF-8"?>
<PathOfBuilding>
  <Build level="95" targetVersion="3_0" className="{class}" ascendClassName="{asc}" mainSocketGroup="1"/>
  <Skills sortGemsByDPS="true" defaultGemQuality="0">
    <SkillSet id="1">
      <Skill mainActiveSkill="1" enabled="true">
        <Gem level="20" quality="20" enabled="true" gemId="Metadata/Items/Gems/SkillGem{skill}" nameSpec="{skill}"/>
      </Skill>
    </SkillSet>
  </Skills>
  <Tree>
    <Spec treeVersion="3_0"><URL>https://www.pathofexile.com/passive-skill-tree/AAAAAA==</URL></Spec>
  </Tree>
  <Items>
{items}  </Items>
  <ItemSets>
    <ItemSet id="1">
{slots}    </ItemSet>
  </ItemSets>
  <Notes/>
</PathOfBuilding>"#,
        class = class_name,
        asc = ascendancy,
        skill = main_skill_id,
        items = items_xml,
        slots = slots_xml,
    )
}
```

- [ ] **Step 3: test PASS 確認 (新 test + 既存 test 両方)**

```bash
cd ~/pob2-build-generator/src-tauri
cargo test core::pob_xml::tests
```

Expected: 2 passed (`serialize_includes_class_and_skill` と `serialize_includes_locked_unique_weapon`)。

- [ ] **Step 4: generate_build と Tauri command を locked_items 対応に**

`src-tauri/src/core/optimizer.rs` の `generate_build` を以下に置換:

```rust
pub fn generate_build(
    class: crate::core::model::Class,
    main_skill_id: String,
    locked_items: std::collections::HashMap<crate::core::model::Slot, crate::core::model::ItemRef>,
    intent: &BuildIntent,
    tree: &PassiveTreeData,
) -> BuildModel {
    let mut m = BuildModel::default();
    m.class = Some(class);
    m.main_skill = Some(main_skill_id);
    m.locked_items = locked_items;
    m.passive_tree = greedy_allocate_tree(tree, intent, "Ranger", 95);
    m
}
```

- [ ] **Step 5: GenerateRequest に locked_unique_weapon 追加**

`src-tauri/src/commands.rs` の `GenerateRequest` と `generate` を以下に置換:

```rust
#[derive(Debug, Serialize, Deserialize, PartialEq)]
pub struct GenerateRequest {
    pub class: String,
    pub main_skill: String,
    #[serde(default)]
    pub locked_unique_weapon: Option<String>,
}

#[tauri::command]
pub fn generate(req: GenerateRequest, state: tauri::State<AppState>) -> Result<GenerateResponse, String> {
    use crate::core::model::{ItemRef, Slot};
    use std::collections::HashMap;

    let data_lock = state.data.lock().unwrap();
    let data = data_lock.as_ref().ok_or_else(|| "PoB data not loaded".to_string())?;

    let skill = data.skills.get(&req.main_skill)
        .ok_or_else(|| format!("skill not found: {}", req.main_skill))?;
    let intent = BuildIntent::infer(skill, &[], &[]);
    let tree: PassiveTreeData = (&data.tree).into();

    let class = match req.class.as_str() {
        "Ranger" => Class::Ranger,
        "Warrior" => Class::Warrior,
        "Witch" => Class::Witch,
        "Sorceress" => Class::Sorceress,
        "Monk" => Class::Monk,
        "Mercenary" => Class::Mercenary,
        "Druid" => Class::Druid,
        "Huntress" => Class::Huntress,
        _ => return Err(format!("unknown class: {}", req.class)),
    };

    let mut locked_items: HashMap<Slot, ItemRef> = HashMap::new();
    if let Some(name) = &req.locked_unique_weapon {
        locked_items.insert(Slot::Weapon1, ItemRef::Unique { name: name.clone() });
    }

    let build = generate_build(class, req.main_skill.clone(), locked_items, &intent, &tree);
    let xml = pob_xml::serialize(&build);

    drop(data_lock);

    let mut wlock = state.worker.lock().unwrap();
    let w = wlock.as_mut().ok_or_else(|| "worker not initialized".to_string())?;
    let stats = w.calc(&xml).map_err(|e| e.to_string())?;

    Ok(GenerateResponse {
        dps: stats.dps,
        ehp: stats.ehp,
        build_code: xml,
    })
}
```

- [ ] **Step 6: list_uniques command 追加**

`src-tauri/src/commands.rs` に追加:

```rust
use crate::pob_bridge::data_reader::Unique;

#[tauri::command]
pub fn list_uniques_for_slot(slot: String, state: tauri::State<AppState>) -> Result<Vec<Unique>, String> {
    let data = state.data.lock().unwrap();
    let data = data.as_ref().ok_or_else(|| "PoB data not loaded".to_string())?;
    let mut out = data.uniques.get(&slot).cloned().unwrap_or_default();
    out.sort_by(|a, b| a.name.cmp(&b.name));
    Ok(out)
}
```

`src-tauri/src/lib.rs` の invoke_handler に `commands::list_uniques_for_slot` を追加。

- [ ] **Step 7: フロント types + API**

`src/types/build.ts` を以下に置換:

```typescript
export interface GenerateRequest {
  class: string;
  main_skill: string;
  locked_unique_weapon: string | null;
}

export interface GenerateResponse {
  dps: number;
  ehp: number;
  build_code: string;
}

export interface Settings {
  pob_install_path: string | null;
}

export interface Skill {
  id: string;
  name: string;
  gem_tags?: Record<string, boolean>;
}

export interface Unique {
  name: string;
  baseName?: string;
}
```

`src/api/tauri.ts` に追加:

```typescript
import type { Unique } from '../types/build';

export async function listUniquesForSlot(slot: string): Promise<Unique[]> {
  return await invoke<Unique[]>('list_uniques_for_slot', { slot });
}
```

- [ ] **Step 8: KeyItemPicker component (Weapon1 限定 lean 版)**

`src/components/KeyItemPicker.tsx`:

```tsx
import { useEffect, useState } from 'react';
import { listUniquesForSlot } from '../api/tauri';
import type { Unique } from '../types/build';

interface Props {
  value: string | null;
  onChange: (uniqueName: string | null) => void;
}

export function KeyItemPicker({ value, onChange }: Props) {
  const [uniques, setUniques] = useState<Unique[]>([]);

  useEffect(() => {
    listUniquesForSlot('Weapon').then(setUniques).catch(() => setUniques([]));
  }, []);

  return (
    <label>
      Key Weapon (unique, optional):{' '}
      <select
        value={value ?? ''}
        onChange={e => onChange(e.target.value || null)}
      >
        <option value="">(none — optimizer に任せる)</option>
        {uniques.map(u => (
          <option key={u.name} value={u.name}>{u.name}</option>
        ))}
      </select>
    </label>
  );
}
```

- [ ] **Step 9: App.tsx に KeyItemPicker 統合**

`src/App.tsx` の `Configure` セクションを以下に置換 (state と generate request も更新):

```tsx
// state 追加
const [lockedUniqueWeapon, setLockedUniqueWeapon] = useState<string | null>(null);

// onGenerate 内
const res = await generate({
  class: klass,
  main_skill: mainSkill,
  locked_unique_weapon: lockedUniqueWeapon,
});

// Configure section
{skills.length > 0 && (
  <section style={{ marginTop: 16 }}>
    <h2>Configure</h2>
    <ClassPicker value={klass} onChange={setKlass} />
    <SkillPicker skills={skills} value={mainSkill} onChange={setMainSkill} />
    <KeyItemPicker value={lockedUniqueWeapon} onChange={setLockedUniqueWeapon} />
  </section>
)}
```

`src/App.tsx` の import に `KeyItemPicker` を追加。

- [ ] **Step 10: 動作確認**

```bash
cd ~/pob2-build-generator
npm run tauri dev
```

- Load PoB Data → unique 一覧が KeyItemPicker に並ぶ
- Quill Rain など選択 → Generate
- 結果の build_code に `Quill Rain` が含まれる
- build_code を PoB に Import → 武器スロットに Quill Rain が装備された build が開く

- [ ] **Step 11: commit**

```bash
cd ~/pob2-build-generator
git add src-tauri/src/commands.rs src-tauri/src/lib.rs \
        src-tauri/src/core/pob_xml.rs src-tauri/src/core/optimizer.rs \
        src/App.tsx src/components/KeyItemPicker.tsx \
        src/api/tauri.ts src/types/build.ts
git commit -m "feat(ui): KeyItemPicker for Weapon1 unique - MVP key item input"
```

---

## Phase 8: End-to-end smoke test + README

### Task 8.1: smoke test

**Files:**
- Create: `src-tauri/tests/smoke.rs`
- Modify: `src-tauri/Cargo.toml` (`[[test]]` entry if needed)

- [ ] **Step 1: integration test を書く**

`src-tauri/tests/smoke.rs`:

```rust
use pob2_build_generator::{
    core::{intent::BuildIntent, model::Class, optimizer::{generate_build, PassiveTreeData}, pob_xml},
    pob_bridge::{
        data_dumper::DataDumper,
        data_reader::PobData,
        worker::PobWorker,
    },
};
use std::path::PathBuf;

#[test]
#[ignore]
fn end_to_end_smoke() {
    let repo_root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).parent().unwrap().to_path_buf();
    let pob = PathBuf::from(std::env::var("POB_PATH").unwrap_or_else(|_| {
        "/Users/kokage/national-operations".to_string()
    }));
    let cache = tempfile::NamedTempFile::new().unwrap();

    // 1. データを dump
    let dumper = DataDumper::new(repo_root.join("scripts/data_export.lua"), pob.clone());
    dumper.dump(cache.path()).expect("dump");
    let data = PobData::load_from(cache.path()).expect("load json");
    assert!(!data.skills.is_empty(), "skills should be loaded");

    // 2. 最初に見つかった skill で build 生成
    let skill = data.skills.values().next().expect("at least one skill");
    let intent = BuildIntent::infer(skill, &[], &[]);
    let tree: PassiveTreeData = (&data.tree).into();
    let build = generate_build(Class::Ranger, skill.id.clone(), &intent, &tree);
    let xml = pob_xml::serialize(&build);

    // 3. PoB worker に投げて calc
    let mut w = PobWorker::spawn(&repo_root.join("scripts/pob_worker.lua"), &pob).expect("spawn");
    let stats = w.calc(&xml).expect("calc");
    w.shutdown().expect("shutdown");

    // 4. 受入条件: parse 通って life > 0
    assert!(stats.life > 0.0, "life should be > 0 (sanity)");
}
```

- [ ] **Step 2: lib.rs を test 側から見えるよう pub に**

`src-tauri/src/lib.rs` の `mod` を `pub mod` に変更:

```rust
pub mod commands;
pub mod core;
pub mod settings;
pub mod types;
pub mod pob_bridge;
```

- [ ] **Step 3: Cargo.toml の package name 確認**

`src-tauri/Cargo.toml` の `[package].name` が `pob2-build-generator` であることを確認 (tauri scaffold は他の名前の可能性、その場合 test の use を合わせる)。

- [ ] **Step 4: smoke test を走らせる**

```bash
cd ~/pob2-build-generator/src-tauri
cargo test --test smoke -- --ignored
```

Expected: `1 passed`。失敗時は phase ごと戻って原因切り分け。

- [ ] **Step 5: commit**

```bash
cd ~/pob2-build-generator
git add src-tauri/tests/smoke.rs src-tauri/src/lib.rs
git commit -m "test(smoke): end-to-end dump -> generate -> PoB calc"
```

### Task 8.2: README + DESIGN.md リンク

**Files:**
- Modify: `README.md`
- Create: `docs/DESIGN.md`

- [ ] **Step 1: README.md を書く**

`README.md`:

```markdown
# pob2-build-generator

PoB-PoE2 fork を計算カーネルとして使う build generator (Tauri app)。

## Status

MVP (Phase 8 done): class + main skill を選んで Generate ボタンで greedy 最適化の
build を生成、PoB calc で DPS/EHP 確認、build code を PoB に import 可能。

## Requirements

- macOS (将来 Windows / Linux 対応)
- Node.js 20+, Rust 1.80+
- luajit (`brew install luajit`)
- PoB-PoE2 fork が install されている (https://github.com/kokagex/national-operations)

## Dev

```bash
npm install
npm run tauri dev
```

設定画面で PoB install path を指定 → Load PoB Data → Class + Skill 選択 → Generate。

## Test

```bash
cd src-tauri
cargo test                           # 単体 test (PoB 不要)
POB_PATH=<...> cargo test -- --ignored   # PoB 連携テスト
```

## Design

[docs/DESIGN.md](./docs/DESIGN.md) を参照。spec 全文は親リポジトリ
`national-operations/docs/superpowers/specs/2026-05-18-build-generator-design.md` にある。
```

- [ ] **Step 2: docs/DESIGN.md**

```bash
mkdir -p ~/pob2-build-generator/docs
```

`docs/DESIGN.md`:

```markdown
# Build Generator - Design

詳細 spec: `national-operations/docs/superpowers/specs/2026-05-18-build-generator-design.md`

## 設計の柱

1. **Lean first**: MVP 範囲外の機能は明確に外す (preset 切替, GA, worker pool, cluster jewel 等)
2. **PoB を single source of truth**: 独自 DB を持たない、`data_export.lua` で JSON dump
3. **上流変更耐性**: PoE2 content を hardcode しない、月末アプデも自動反映
4. **Fail loudly**: schema 変更は load 時に loud error
5. **Walking skeleton**: 各 phase で end-to-end が動く、stub を段階的に実装に置換

## アーキ概要

- React UI (frontend, src/)
- Rust core (src-tauri/src/core/) — BuildModel, BuildIntent, Greedy, fitness, pob_xml
- PoB bridge (src-tauri/src/pob_bridge/) — JSON cache reader + luajit subprocess 管理
- scripts/data_export.lua — PoB データ JSON dumper
- scripts/pob_worker.lua — 長時間 luajit worker (build xml → stats JSON)

## MVP done line

Phase 8 task 8.1 smoke test が PASS。
```

- [ ] **Step 3: commit + push**

```bash
cd ~/pob2-build-generator
git add README.md docs/DESIGN.md
git commit -m "docs: README + DESIGN.md with arch summary and dev guide"
git push origin main
```

---

## Phase 9: フィードバック loop (MVP 完了後の iteration entry point)

MVP 完成後、以下を実測して spec の Open Questions に答えていく:

- OQ-2 「Greedy が Rust 概算でずれて bad build を返す頻度」: 自分で build 10 個生成 → 結果を目視 / PoB 上で詳細 calc → どの skill / class でずれが顕著か記録
- OQ-3 「passive tree 0.5 フォーマット変更」: 月末アプデ来たら PoB upstream 対応待ち、tree loader 修正 (data_export.lua の (a) → (b) 切替 or field 修正)
- OQ-5 「PoB text parser API surface」: gear / unique の詳細 mod を扱うために `src/Classes/ImportTab.lua` を grep

これらは plan の外 (next iteration 用)。spec を update して新 plan を起こす。

---

## Self-Review (writing-plans skill 必須)

### 1. Spec coverage check

| Spec section | 対応 task |
|---|---|
| §2 設計原則 1 Lean | Phase 8 まで MVP 範囲外明確化 ✅ |
| §2 設計原則 2 上流変更耐性 | data_export.lua が PoB データ直読 ✅ |
| §2 設計原則 3 Single source of truth | Task 2.1-2.3 ✅ |
| §2 設計原則 4 Fail loudly | DataDumper の ScriptFailed error ✅ |
| §2 設計原則 5 Progressive output | MVP では未対応 (spec 明示で OK) |
| §2 設計原則 6 Distribution stage | Phase 0 で macOS dev 完結 ✅ |
| §3 React UI | Phase 1, 5, 7 ✅ |
| §3 Rust core | Phase 4, 5, 6 ✅ |
| §3 PoB JSON Reader | Task 2.3 ✅ |
| §3 PoB headless worker | Phase 3 ✅ |
| §3 data_export.lua | Task 2.1, 6.2 ✅ |
| §3 pob_worker.lua | Task 3.1 ✅ |
| §4.1 Mods / Uniques / Skills / Tree | Tasks 2.1, 6.2 (mod 詳細は MVP 後) |
| §4.2 データ更新フロー | Task 2.5 (起動時 load), 手動再 dump は実装後ボタンで追加 |
| §4.3 月末 0.5 対応 | Phase 9 で iteration |
| §5.1 BuildModel | Task 4.1 ✅ |
| §5.2 BuildIntent | Task 5.1 ✅ |
| §5.3 Fitness | Task 5.2 ✅ |
| §5.4 Greedy | Task 6.1, 6.2 ✅ (gem links / gear は MVP 外、Phase 9) |
| §5.5 計算コスト | Task 6.1 で実測する |
| §6 PoB 連携 | Phase 2, 3 ✅ |
| §7 UI / UX | Phase 7 (KeyItemPicker は Task 7.2、Weapon1 unique 限定 lean) ✅ |
| §8 プロジェクト構成 | Phase 0 で雛形 ✅ |
| §9 MVP done line | Phase 8 task 8.1 smoke test ✅ |
| §10 Open Questions | Phase 9 iteration ✅ |
| §11 検証戦略 | Task 8.1 ✅ |

**Gap**: spec §5.4 で Greedy の Gem links / Gear synth / Jewel 部分を MVP に入れる/外す明示が曖昧 → 本 plan では「Phase 6 = tree allocation のみ」「gem / gear / jewel は Phase 9」と明確に絞り MVP 軽量化。Key item picker は spec §9 通り MVP に含める (Task 7.2、Weapon1 unique 限定の lean 版)。

### 2. Placeholder scan

- "TBD" / "TODO": 検出なし
- "implement later" / "fill in details": 検出なし
- "適切なエラーハンドリング": なし
- 全 step が code block を持っている: 確認 ✅
- "Similar to Task N": なし、各 task 完全独立 ✅

### 3. Type consistency

- `GenerateRequest` / `GenerateResponse`: Phase 1 から Phase 7 まで通して `class`, `main_skill`, `dps`, `ehp`, `build_code` で統一 ✅
- `PobData` / `Skill` / `Unique`: data_reader.rs で 1 度定義、Tauri command と smoke test で再利用 ✅
- `BuildModel` / `Slot` / `Class`: core/model.rs で定義、optimizer / pob_xml で参照 ✅
- `CalcStats`: worker.rs で定義、commands.rs で参照 ✅
- 命名 collision なし

### 4. MVP scope (確定)

Spec §9 MVP done line 通り `class + main skill + key item 1 個 (Weapon1 unique limited) + greedy passive tree → PoB import` を MVP に含む。`gear synth` `gem links` `jewel` `preset 切替` `progressive output` `cluster jewel` 等は Phase 9 iteration。

---

## Execution: Subagent-Driven (確定)

User goal で **B (key item picker を MVP に含む、Task 7.2 追加) + 1 (subagent-driven 実行)** を確定。

実行手順 (subagent-driven-development skill 経由):
1. 各 task は fresh subagent (Sonnet) に dispatch
2. subagent は failing test → impl → passing test → commit までを 1 task で完結
3. main agent (Opus) は task 間で diff レビュー + 次 task の context を準備
4. Phase 0 → 1 → 2 → ... → 8 の順序、各 phase 内で task 順序通り
5. Phase 完了時に smoke check (主要動作確認)
