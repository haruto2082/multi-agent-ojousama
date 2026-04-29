---
scope: common
applies_to: [ojousama, kaseifu, shitsuji, maid]
version: "0.1"
---

# 通信プロトコル

全ロール共通の通信規約。逸脱は F-RULE-02 / F-RULE-03 違反となる。

## 1. 通信媒体

- **正規経路**: `queue/` 配下のYAMLファイル（永続ログ・監査可能）
- **起床通知**: tmux `send-keys`（揮発・ペイロードは持たせない）
- 起床通知のメッセージは「対象YAMLのパスのみ」を含める。指示本体はYAMLに書く。

## 2. tmux 2ステップ通知（必須）

```bash
tmux send-keys -t {target_pane} "メッセージ"
tmux send-keys -t {target_pane} Enter
```

- `{target_pane}` は各ロール instructions の `panes:` セクション値を使用
- `tmux list-panes` 等の調査コマンドで宛先を探さない（F-RULE-05 違反扱い）
- 同時通知禁止。前の通知から最低 `sleep 0.3` を空ける（フレンドリーファイア防止）

## 3. YAMLファイル命名規約

| 経路 | ファイル名 |
|------|-----------|
| あなた → お嬢様 | (口頭/プロンプト) |
| お嬢様 → 家政婦 | `queue/ojousama_to_kaseifu.yaml` |
| 家政婦 → メイド NN | `queue/kaseifu_to_maid_{NN}.yaml` |
| メイド NN → 家政婦 | `queue/maid_{NN}_report.yaml` |
| 家政婦 → 執事 | `queue/kaseifu_to_shitsuji_{NN}.yaml` |
| 執事 → 家政婦 (QC結果) | `queue/shitsuji_report.yaml` |
| 家政婦 → お嬢様 | `queue/kaseifu_to_ojousama.yaml` |

`{NN}` は 2桁ゼロ詰め（`maid_01`, `maid_02`, …）。

## 4. 報告YAML 共通スキーマ

```yaml
task_id: "{元タスクIDに連動}"
from: "{自ロール}"
to: "{宛先ロール}"
status: "completed"        # completed / partial / failed / needs_review
summary: "実施内容を 2〜3 文"
files_created: []
files_modified: []
errors: null               # 失敗時は文字列で原因
notify_status:             # 完了通知の送信結果 (improvement_1_c / gap_1_1+1_2 対応)
  sent: yes                # yes/no: 通知を送信したかどうか
  mailbox_rc: 0            # int: scripts/inbox_write.sh の終了コード (0 = 成功)
  tmux_rc: -1              # int: tmux fallback の終了コード (mailbox_rc != 0 時のみ / 未使用は -1)
  fallback_used: no        # yes/no: tmux fallback を使ったか (mailbox 失敗時)
skill_candidate:           # task_flow.md 参照
  found: false
  description: ""
```

ロール固有の追加フィールド（例: 執事の `acceptance_check`）は spec 側で定義。

**`notify_status` の意図**: executor が自分の通知 rc を report に明示記録することで、
家政婦は report Read 時点で「メイドは送ったが届いていない」を判断できる
(tmux 通知が揮発で起床失敗しても mailbox_rc=0 なら正規経路として完了扱い)。
mailbox_rc != 0 のときに tmux fallback を試した場合は `fallback_used: yes` と
`tmux_rc` を記録する。両方失敗なら `sent: no` で needs_review に切替。

## 5. 通知タイミング規約

- **起床**: 自分宛の YAML が更新された/作成された時のみ起床
- **応答**: タスク完了直後に 1 度だけ通知
- **再通知禁止**: 上位ロールが応答しない場合もポーリングしない（F-RULE-04）
- **ブロードキャスト禁止**: 1回の send-keys で複数 pane に通知しない

## 6. 起動時の手順（コンパクション後も同じ）

1. `tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}'` で自分のロール確認
2. 該当 instructions を読む（`instructions/{role}.md`）
3. `instructions/common/forbidden_actions.md` の F-RULE と禁止事項を確認
4. 自分宛の `queue/*.yaml` を読み、`constraints` / `acceptance_criteria` を確認
5. 着手
