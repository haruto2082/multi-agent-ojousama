---
scope: common
applies_to: [ojousama, kaseifu, shitsuji, maid]
version: "0.1"
---

# PostCompact 自動再開プロトコル

## 概要

`/compact` 実行直後の idle 状態から、PostCompact hook と tmux nudge を組み合わせて自動的に作業を再開させる仕組み。全ロール (kaseifu / maid_NN / shitsuji) を対象とし、コンパクション完了直後に自分の inbox 未読件数を数え、1 件以上なら自分の pane に `inbox{N}` nudge を送って起床トリガーとする。会話履歴が圧縮されても一次データソースである `queue/inbox/{role}.yaml` と `queue/*.yaml` を Read すれば作業継続可能であり、本機構はその Read を促す起床信号を自動投入する役割を担う。

unread=0 で /compact が発火した場合、PostCompact hook は通常 nudge を skip するが、
PreCompact hook が直前に scripts/hooks/.compaction_in_progress flag を touch しているため、
PostCompact hook はこの flag を検知して 'resume' nudge を送信し、その後 flag を削除する。
この 2-hook 連携により、作業中 /compact 発火時の idle 停止を防止する。

## 発火経路

PostCompact hook は次の 2 経路で発火する。`.claude/settings.json` の `hooks.PostCompact` に `matcher=auto` と `matcher=manual` の 2 定義が登録されており、いずれの場合も同じ `postcompact_resume.sh` が起動する。

- (a) Claude Code session 内のユーザー入力 `/compact` (matcher=manual)
- (b) tmux からの自己発火 `tmux send-keys -t "$TMUX_PANE" "/compact" && tmux send-keys -t "$TMUX_PANE" Enter` (F-RULE-03 の 2 ステップ送信に整合)

(b) は PreCompact hook の自動 /compact 送信 (`PRECOMPACT_AUTO_COMPACT=1` opt-in) からも誘発されうる。デフォルトでは無効化されている (自己 /compact ループ防止のため `PRECOMPACT_AUTO_COMPACT=0`)。

PreCompact hook は発火時に scripts/hooks/.compaction_in_progress flag (touch) を作成する。
PostCompact hook はこの flag を検知して unread=0 でも 'resume' nudge を送信し、必ず削除する。

## 自動起床後の責務

nudge body `inbox{N}` を受信したロールは、CLAUDE.md「起動時手順」に従い以下を順に実施する。

1. `tmux display-message -t "$TMUX_PANE" -p '#{@agent_id}'` で自分のロールを確認 (フォールバック: `echo $AGENT_ROLE`)
2. ロールに対応する `instructions/{role}.md` を Read
3. `instructions/common/forbidden_actions.md` の F-RULE と D-RULE を確認
4. 自分の inbox `queue/inbox/{role}.yaml` を Read し、`read: false` のメッセージを処理
5. 中断前 task の継続 (`queue/kaseifu_to_{role}.yaml` 等の指示 YAML を再読、未報告なら作業再開)

nudge body は単なる起床信号であり、指示本体は YAML 側に格納される (F-RULE-02 と整合)。

## 実装参照

挙動の正典は以下のコードであり、本ドキュメントは概念整理である。挙動詳細を判断する際は実装側を直接参照すること。

- `scripts/hooks/postcompact_resume.sh` (commit f0ae849): PPID から TMUX_PANE を解決 → `tmux display-message` でロール解決 → `queue/inbox/{role}.yaml` の `read: false` を `grep -c` でカウント → unread > 0 なら `tmux send-keys` 2 ステップで `inbox{N}` 送信 → `.postcompact_history.log` に 1 行追記。`exit 0` を必ず維持する INVARIANT (非ゼロ exit は compaction 自体を阻害するため)。
- `.claude/settings.json` の `hooks.PostCompact`: `matcher=auto` と `matcher=manual` の 2 定義を登録、いずれも `timeout: 30` 秒。
- `scripts/hooks/precompact_notify.sh`: PreCompact 側の対応 hook。お嬢様 pane への通知と `.precompact_history.log` への記録を行い、`PRECOMPACT_AUTO_COMPACT` 環境変数 (デフォルト 0) で自動 /compact 送信を opt-in 化。デフォルト 0 化は task_056_followup_01 で自己 /compact ループ阻止のため確定。

## 失敗時 fallback

PostCompact hook が起動しない・nudge 送信が失敗するなどで自動再開できない場合、ロールは idle のまま停止する。この場合 `scripts/watchdog.sh` (launchd 5 分間隔) が cmd YAML の `timestamp:` 不更新を検知し、既定 `WATCHDOG_THRESHOLD_SECONDS=600` (10 分) 経過時点でお嬢様 pane へ催促を送信する。閾値変更は環境変数 `WATCHDOG_THRESHOLD_SECONDS` で可能。F-RULE-04 (polling 禁止) との整合は launchd 側にポーリングを閉じることで保たれている (Claude 側は wait しない)。

## 実証 evidence

`scripts/hooks/.postcompact_history.log` に記録された全ロール経路の実環境立証 3 records:

- `2026-04-29T09:23:35Z | role=kaseifu | matcher=manual | pane=%113 | unread=0` — unread=0 + flag 不在のため skip (option_C 導入前の挙動 / task_066a 以降は flag 検知時 'resume' nudge 送信)
- `2026-04-29T09:27:55Z | role=maid_05 | matcher=manual | pane=%118 | unread=1` — unread=1 のため `inbox1` nudge 送信
- `2026-04-29T09:38:31Z | role=shitsuji | matcher=manual | pane=%125 | unread=1` — unread=1 のため `inbox1` nudge 送信

3 ロール全経路で hook 発火・ロール解決・unread カウント・条件分岐が実環境で正しく動作したことを立証 (お嬢様承認 task_058 集約時)。

<!-- task_059 / task_065 / task_066a -->
