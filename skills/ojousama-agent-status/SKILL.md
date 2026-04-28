---
name: ojousama-agent-status
description: お嬢様屋敷の各エージェント（お嬢様・家政婦・各メイド）の稼働状況を点呼する。「稼働確認」「点呼」「みんな何してる」等の依頼で発動し、scripts/agent_status.sh を実行して結果を整形して表示する。
---

# ojousama-agent-status

屋敷の各pane（お嬢様・家政婦・maid_01〜maid_08）の稼働状況を一覧で点呼するスキル。

## 起動条件

ユーザー（あなた）またはお嬢様が以下のような依頼をしたとき:

- 「稼働確認して」「点呼」「全員の状況を見せて」
- 「いまメイドたちは何をしている？」
- 「誰が手空き？」
- 特定ロール: 「maid_03 の状況だけ見せて」

## 実行手順

1. プロジェクトルートで `scripts/agent_status.sh` を実行する。
   - 全ロール: `bash scripts/agent_status.sh`
   - 特定ロール: `bash scripts/agent_status.sh --role maid_03`
2. 出力（role / pane / state / last_active / current_task / report_status の表）をそのまま表示する。
3. 表示後、状態の要約を 1〜2 文で添える（例: 「現在 maid_02 が稼働中、他は待機中でございます」）。

## 出力フォーマット

```
role       pane               state   last_active       current_task                   report_status
----       ----               -----   -----------       ------------                   -------------
ojousama   ojousama:0.0       idle    2026-04-28 03:10  -                              -
kaseifu    ojousama:1.1       busy    2026-04-28 03:12  task_004_phase2_kaseifu        in_progress
maid_07    ojousama:2.6       idle    2026-04-28 03:11  task_004_phase2_maid_07        completed
...
```

## 注意

- ポーリングはしない（F-RULE-04）。1回の呼び出しでスナップショットを取って終わり。
- 他pane の中身を改変する操作は行わない。`tmux capture-pane -p` の読み取りのみ。
- pane が存在しない場合は `state=absent` として表示する。
