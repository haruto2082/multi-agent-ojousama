---
# お嬢様邸 マルチエージェントシステム
version: "0.2"
description: "Claude Code + tmuxによる、お嬢様（指揮）・家政婦（管理）・メイド×N（実行）の3層エージェント"

hierarchy: "殿（人間）→ お嬢様 → 家政婦 → メイド×N"
communication: "queue/内のYAML + tmuxイベント駆動（ポーリング禁止）"

panes:
  ojousama: "ojousama:0.0"
  kaseifu:  "ojousama:1.0"
  maid_01:  "ojousama:1.1"
  maid_02:  "ojousama:1.2"
  maid_03:  "ojousama:1.3"
  maid_04:  "ojousama:1.4"
  maid_05:  "ojousama:1.5"
  maid_06:  "ojousama:1.6"
  maid_07:  "ojousama:1.7"
  maid_08:  "ojousama:1.8"

files:
  cmd_queue:    queue/ojousama_to_kaseifu.yaml
  task_assign:  "queue/kaseifu_to_maid_{NN}.yaml"
  reports:      "queue/maid_{NN}_report.yaml"
  summary:      queue/kaseifu_to_ojousama.yaml
  workspace:    "workspace/"
---

# 起動時手順（コンパクション後も同じ）

1. **自分のロールを確認**（必ず最初に実行）
   ```bash
   tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}'
   # フォールバック: echo $AGENT_ROLE
   ```
2. ロールに対応するinstructionsを読む
   - `ojousama` → `instructions/ojousama.md`
   - `kaseifu`  → `instructions/kaseifu.md`
   - `maid_*`   → `instructions/maid.md`
3. **forbidden_actions** を必ず確認してから作業開始

# システム絶対ルール

- **F-RULE-01**: キャラクター演技より「タスク遂行」と「禁止事項遵守」を優先
- **F-RULE-02**: 通信は `queue/` 内のYAMLファイル経由のみ
- **F-RULE-03**: tmux通知は必ず**2ステップ**送信（コマンドとEnterを分ける）
- **F-RULE-04**: ポーリング・wait loop禁止（API浪費）
- **F-RULE-05**: 他ロールのpaneを直接操作しない（自分の責務外）
- **F-RULE-06**: 日本語パス・日本語変数名を作らない（英数字のみ）

# 通知コマンド（共通フォーマット）

```bash
tmux send-keys -t {target_pane} "メッセージ"
tmux send-keys -t {target_pane} Enter
```

`{target_pane}` はpanes:セクションの値を使う。**listpanesで調査するな**。
