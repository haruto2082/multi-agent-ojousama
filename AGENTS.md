# AGENTS.md

> このファイルは Claude Code 以外のCLIエージェント（Codex CLI 等）が
> 当リポジトリを開いた際の **最低限の動作規範** を提供する雛形です。
> 主軸は Claude Code（`CLAUDE.md` を参照）です。Multi-CLI 完全対応は未実装ですが、
> 将来 Codex CLI 等を併用する場合の入り口として本ファイルを置きます。

---

## 起動時手順（コンパクション後も同じ）

1. **自分のロールを確認**（必ず最初に実行）
   ```bash
   tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}'
   # フォールバック: echo "$AGENT_ROLE"
   ```
2. ロールに対応する instructions を読む
   - `ojousama` → `instructions/ojousama.md`
   - `kaseifu`  → `instructions/kaseifu.md`
   - `maid_*`   → `instructions/maid.md`
3. `forbidden_actions` を必ず確認してから作業開始。

---

## システム絶対ルール（F-RULE）

- **F-RULE-01**: キャラクター演技より「タスク遂行」と「禁止事項遵守」を優先。
- **F-RULE-02**: 通信は `queue/` 内の YAML ファイル経由のみ。
- **F-RULE-03**: tmux 通知は必ず **2 ステップ** 送信（コマンドと Enter を分ける）。
- **F-RULE-04**: ポーリング・wait loop 禁止（API 浪費）。
- **F-RULE-05**: 他ロールの pane を直接操作しない（自分の責務外）。
- **F-RULE-06**: 日本語パス・日本語変数名を作らない（英数字のみ）。
- **F-RULE-07**: 認証情報は `config/*_auth.env` 等に隔離しコミット禁止。
- **F-RULE-08**: 破壊的操作（`rm -rf`, force push, `reset --hard` 等）は事前確認必須。

---

## 通知コマンド（共通フォーマット）

```bash
tmux send-keys -t {target_pane} "メッセージ"
tmux send-keys -t {target_pane} Enter
```

`{target_pane}` は `CLAUDE.md` の `panes:` セクションの値を使う。
`tmux list-panes` で都度調査しない。

---

## 設計思想

`docs/philosophy.md` を参照（5原則・F-RULE 詳細・各ロール責務）。
迷ったら philosophy.md → instructions/<role>.md → CLAUDE.md の順で確認する。

---

## CLI 別補足

| CLI         | 状態         | 備考                                                       |
|-------------|--------------|------------------------------------------------------------|
| Claude Code | 主軸（公式） | `CLAUDE.md` が一次情報源。本ファイルは代替時のみ参照。     |
| Codex CLI   | 雛形のみ     | 本ファイルを読んで起動手順と F-RULE に従う。動作未保証。   |
| その他      | 未対応       | 本ファイルの規範に従う限りで自己責任。                     |

Multi-CLI 切替（capability_tiers/ルーティング機構等）は現フェーズでは未導入。
将来導入時は `config/settings.yaml` 等で宣言し、本ファイルを更新する。
