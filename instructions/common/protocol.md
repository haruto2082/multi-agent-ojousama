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

### 3.1 cmd lifecycle / critical 通知用ファイル <!-- task_064e -->

| ファイル | 用途 / 制約 |
|----------|-----------|
| `queue/cmd_log.yaml` | cmd lifecycle event log。**append-only**。`scripts/cmd_log_append.sh` 経由で 6 event_type (`cmd_issued` / `cmd_acknowledged` / `cmd_dispatched` / `cmd_qc_started` / `cmd_aggregated` / `cmd_completed`) を記録 (task_064a Phase-1)。`>>` 演算子のみで書込み既存 events を改変しない。`.gitignore` 対象 (run-time 生成物 / コミット不可)。 |
| `queue/inbox/ojousama_critical.yaml` | critical 通知永続キュー。Mailbox v0.3 互換 (`role: ojousama_critical` / `messages:` 配列)。**accepted: severity=critical のみ** (task_064d Phase-3)。`scripts/notify_human.sh --severity critical --category <id>` 経由でのみ append。`.gitignore` 例外パターンで永続化 (track 対象)。 |

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

### 4.1 cmd_log event schema <!-- task_064e -->

`queue/cmd_log.yaml` の `events:` 配列要素は以下の構造を取る (task_064a / `scripts/cmd_log_append.sh` 出力フォーマット):

```yaml
events:
  - event_id: "evt_NNNN_<task_id>_<event_type>"   # NNNN は 4桁ゼロ詰め (count + 1)
    ts: "<ISO8601 UTC>"                            # 例: 2026-04-30T08:30:00Z
    event_type: cmd_issued                         # cmd_issued | cmd_acknowledged | cmd_dispatched
                                                   # | cmd_qc_started | cmd_aggregated | cmd_completed
    task_id: "<task_id>"                           # 対象 task の id
    parent_cmd: "<parent task_id>"                 # 親 cmd の id / 親無しは null
    actor: kaseifu                                 # ojousama | kaseifu | shitsuji | maid_NN
    payload: {}                                    # 1 行 inline mapping (任意拡張 / 空は {})
    severity: low                                  # low | medium | high | critical (default: low)
```

**append-only 制約**: 既存 events の編集・削除は禁止。新 event 追加は `scripts/cmd_log_append.sh` 経由でのみ実施 (mkdir lock + `>>` 演算子)。

### 4.2 ojousama_critical message schema <!-- task_064e -->

`queue/inbox/ojousama_critical.yaml` の `messages:` 配列要素は Mailbox v0.3 互換 schema を拡張した以下の構造を取る (task_064d / `scripts/notify_human.sh --severity critical` 経由):

```yaml
role: ojousama_critical
messages:
  - from: <role>                                   # kaseifu | shitsuji | maid_NN
    ts: "<ISO8601 UTC>"
    severity: critical                             # 固定値 (本 inbox の唯一許容)
    category: d_rule                               # d_rule | f_rule_09 | acceptance_unparseable | system_failure
    body: "<本文>"
    related_yaml: "<報告 YAML パス>"               # 参照 YAML / 任意 / 未指定時 null
    read: false                                    # true | false
```

**category 発火基準 (4 種)**:

| category | 発火条件 |
|----------|----------|
| `d_rule` | D-RULE-001〜008 抵触兆候 (rm -rf / force push / sudo / SIGKILL / dd / `.git/` 直接編集 等) |
| `f_rule_09` | F-RULE-09 違反兆候 (D-RULE 抵触の前段 / 破壊的操作の入口) |
| `acceptance_unparseable` | task YAML の `acceptance_criteria` 解釈不能 (前提矛盾 / 参照先消失) |
| `system_failure` | queue/ プロトコル破綻 / Mailbox System 故障 / watchdog 永続停止 |

**互換性**: 旧 signature (`bash scripts/notify_human.sh <role> <context>` の 2 引数形式) は `severity=low` default で引き続き動作 (既存 callers 無改変動作 / `--severity` 未指定で従来経路)。

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
