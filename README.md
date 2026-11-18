# Construction Altitude Tooltip (Transport Fever 3)

[日本語は下にあります](#日本語)

While you place a building (stations, depots and other constructions,
templates included), the cursor tooltip shows the altitude of the placement
point, below the cost.

## Features

- Altitude of the placement point, one decimal, in the game's own altitude
  format.
- Follows the **Height** slider: raising or lowering the building changes
  the value.
- The tooltip label is translated into all 13 languages of the game, and the
  mod description has a section for each.

## Where it shows, and where it doesn't

- Shows while placing buildings: stations, depots and other constructions,
  templates included. Single-object asset brush placement may show it too.
- For a template with several buildings, the position of one of them is
  used.
- Roads, tracks, terrain and the other tools are not changed. Station modules
  and the town builder show no altitude.

## Compatibility

- GUI only: it changes no save data, so it can be added to or removed from a
  running save at any time.
- Adds one line to the tooltip; lines that the game or other mods add (for
  example the reputation line) stay.

## Install

- mod.io: <https://mod.io/g/transportfever3/m/construction-altitude-tooltip> (or subscribe in the game's mod hub).
- Manually: the game loads a local mod only from a folder named exactly
  `hummer_construction_altitude_tooltip_1` inside
  `<Steam>/userdata/<your id>/3493540/local/mods/`.
  - From the release zip: create that folder and extract the zip **into**
    it (the zip has no top folder of its own).
  - From GitHub: `git clone https://github.com/hummer98/tpf3-construction-altitude-tooltip.git hummer_construction_altitude_tooltip_1`
    inside `local/mods/` (a different folder name will not load).
  - Then enable the mod in the game.

## Development

The code is plain Lua (`content/gui/`):

| File | Role |
|---|---|
| `cht_core.lua` | Pure helpers (which origin, text), no engine access |
| `cht.script.lua` | Wraps `construction_react_util.getActionParams` and adds the line through the action's `getProposalStringsFn` |
| `cht.res.lua` | Hook run at UI start-up |
| `_metadata/modinfo.json` | Name, summary and description for the game's mod list and the in-game mod.io upload. The game shows one text for all languages, so the name is "English / 日本語" and the description has a section per language |
| `_metadata/0.png` | Cover image (required by the in-game uploader, also shown in the mod list) |
| `docs/modio_description.md` | The same description for the mod.io web page |

Tests run offline with LuaJIT and stub the game API:

```sh
luajit tests/run.lua
```

`python3 tools/package.py` runs the tests and builds
`dist/hummer_construction_altitude_tooltip_1.zip` with only the files the
game needs (no `.git`, tests or tools). LICENSE stays out too: the game's mod
validation rejects files without an allowed extension, so the mod
description states the licence and links here instead.

To publish an update, raise `revision` in `mod.json`, commit, then run
`python3 tools/stage.py`. It runs the same checks, refuses uncommitted
changes or an unraised revision, and rebuilds the game's staging copy
(`local/staging_area/hummer_construction_altitude_tooltip_1`) while keeping
the `_metadata/mod.io_fileid.txt` the game wrote at the first upload, which is
what makes the upload update this mod instead of creating a new one. Then in
the game: MOD hub > My mods > Revalidate > Update. `--keep-revision` allows
a metadata-only update; `--first-upload` stages a mod not yet on mod.io.
Tool tests: `python3 -m unittest discover -s tests`.

## License

[MIT](LICENSE) © 2026 hummer

---

## 日本語

# 建設時の標高表示（Transport Fever 3）

建造物（駅などの建物やテンプレート）を配置するとき、マウスのヒントのコストの下に、配置する場所の標高を表示します。

### 機能

- 配置する場所の標高を、ゲームの標高の書式で小数1桁で表示します。
- 「高度」スライダーに従います。建物を上げ下げすると値も変わります。
- ツールチップのラベルはゲームの全13言語に翻訳済みで、Modの説明文も言語ごとの段落があります。

### 表示される場面・されない場面

- 表示される：建造物（駅などの建物やテンプレート）の配置。アセットブラシの単体配置でも表示されることがあります。
- 複数の建物を含むテンプレートでは、そのうち1つの位置を使います。
- 道路・線路・地形などのツールは変わりません。駅モジュールと町ビルダーでは表示されません。

### 互換性

- GUI だけの Mod で、セーブデータを変更しません。プレイ中のセーブにいつでも追加・削除できます。
- ヒントに1行足すだけで、ゲームや他の Mod が足す行（評判の行など）はそのまま残ります。

### 導入

- mod.io：<https://mod.io/g/transportfever3/m/construction-altitude-tooltip>（ゲーム内の MODハブからも購読できます）
- 手動：ゲームは `<Steam>/userdata/<ID>/3493540/local/mods/` の中の、
  名前がちょうど `hummer_construction_altitude_tooltip_1` のフォルダからだけ読み込みます。
  - リリースの zip から：そのフォルダを作り、その**中に** zip を展開します（zip には外側のフォルダがありません）。
  - GitHub から：`local/mods/` の中で `git clone https://github.com/hummer98/tpf3-construction-altitude-tooltip.git hummer_construction_altitude_tooltip_1` とします（別のフォルダ名では読み込まれません）。
  - そのあとゲーム内で有効にします。

### ライセンス

[MIT](LICENSE) © 2026 hummer
