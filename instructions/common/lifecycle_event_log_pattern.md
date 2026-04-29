---
scope: common
applies_to: [ojousama, kaseifu, shitsuji, maid]
version: "1.0"
pattern_name: "append-only event log + 単一ファイル並走 cut-over"
reference_implementation: "queue/cmd_log.yaml lifecycle (commits 87fee82 〜 1c6d0fd)"
---

# Lifecycle Event Log Pattern

## 1. 概要

multi-agent system において既存の単一ファイル運用 (cmd YAML / status field 等) を破壊せず、並走で append-only event log を導入し、段階的に主経路へ切替えるための汎用パターン。

**適用シナリオ**:

- 既存運用: `queue/ojousama_to_kaseifu.yaml` のように 1 task = 1 ファイル / 上書き運用で並走 task の追跡が困難な状態
- 課題: watchdog / 監視機構が「最新 1 件」しか追跡できず、並走 cmd の漏れ検知が発生しうる
- 解: append-only event log を新設し、各 task の lifecycle event (発生・遷移・終了) を独立イベントとして追記 → 監視機構を walk ベースに切替

**期待効果**:

- 並走 task の個別追跡が可能 (構造的脆弱性 gap_2_3 を解消)
- lifecycle 各遷移点のタイムスタンプを永続化 (事後監査 / KPI 取得 / ホウレンソウ 4 ポイントの機械検証が容易)
- Phase 別 cut-over により revert 1 commit で旧運用へ戻せる (rollback 容易性)
- 並走中は旧経路と新経路の差分監視で false-negative が減る (二重監視期間)

## 2. event schema (本パターンの 6 段 lifecycle reference 実装)

`queue/cmd_log.yaml` の cmd lifecycle を典型例とする。各 event は append-only で 1 マップ要素として追記される。

| event_type | actor | trigger | dedupe key | severity 例 |
| --- | --- | --- | --- | --- |
| `cmd_issued` | ojousama | cmd YAML Write 直後 | task_id | low / medium / high |
| `cmd_acknowledged` | kaseifu | cmd Read + 受領通知直後 | task_id + ts | low |
| `cmd_dispatched` | kaseifu | 全子 task の発注 + nudge 完了直後 | task_id + ts | low |
| `cmd_qc_started` | kaseifu | 執事 QC 発注時 (任意) | task_id + ts | low |
| `cmd_aggregated` | kaseifu | 集約報告 Write 直後 | task_id + ts | low / medium / high |
| `cmd_completed` | ojousama | 集約報告確認 + ユーザ伝達直後 | task_id (terminal) | low / medium / high |

各 event の payload schema は **適用先プロトコルが定義する**。本パターンとしての必須フィールドは `event_id` / `ts` / `event_type` / `task_id` / `actor` / `payload` の 6 項目で、optional に `parent_cmd` / `severity` / `notes` を持つ。

詳細スキーマは `instructions/common/protocol.md` Section 4.1 (cmd_log event schema) を参照する。append-only 制約 (既存 events 改変禁止) は本パターンの根幹であり、protocol.md にも明記される。

## 3. Phase 別 roll-out 戦略 (汎用テンプレート)

**Philosophy**: cut-over 一括変更を避け、Phase-1 〜 4 で並走させ、各 Phase 完了時点で revert 可能 (1 commit で戻せる) を維持する。Phase 間は手動 promotion (家政婦判断 + 各 Phase 末で smoke test) で進める。

### Phase-1: 基盤新設 (read-only / 既存運用無改変)

- **deliverable**: event log ファイル新設 (空 events:) + helper script (mkdir lock + `>>` 演算子) + instructions に呼出手順を追記
- **risk**: low — 読まれない側のファイル増設のみ。既存監視機構は無変更で並走
- **rollback**: ファイル削除 + instructions revert (1 commit)
- **exit_criteria**: 1 サイクル分の events が全 lifecycle 段階で記録される (各 actor の手順履行確認)

### Phase-2: 監視機構の cut-over 拡張 (旧経路と二重監視)

- **deliverable**: watchdog / 監視 script を event log walk ベースに改造 + state file を YAML 化 (per-task dedupe key) + 旧経路は維持 (二重監視で漏れ検知)
- **risk**: medium — ロジック改造 / 二重監視で false-positive リスクは増えるが false-negative は減る
- **rollback**: 監視 script 旧版へ revert (1 commit) / event log は read-only 残置
- **exit_criteria**: 並走 task 2 件で両方の terminal event を確認 / 旧経路 alert と新経路 alert の差分ゼロ

### Phase-3: 拡張 schema + 例外規範導入 (severity / category / 永続 critical キュー等)

- **deliverable**: severity / category 別の例外通知経路 (例: 永続 critical inbox) + helper script への opt-in 引数追加 + 旧 signature 互換維持 + instructions の例外節文言化
- **risk**: low-medium — 既存 callers 無改変 / 新 signature は opt-in
- **rollback**: 拡張インボックス削除 + helper script 旧版 revert (1 commit)
- **exit_criteria**: fixture 投函で全経路 (例: inbox / tmux / ntfy 3 経路) 到達 + nudge 表示

### Phase-4: 旧経路廃止 + 文言確定

- **deliverable**: 旧監視経路コードを削除 + 関連規範を確定文言に書換 (緩和 → 確定 / 再導入 → 例外規範 等)
- **risk**: medium — 旧経路廃止後の不整合リスク / Phase-2 / 3 の安定運用証拠を要求
- **rollback**: Phase-2 状態に戻す (二重監視復活)
- **exit_criteria**: 1 週間以上 / 5 サイクル以上の安定運用証拠 + お嬢様 (= ユーザ判断主体) 承認

各 Phase は **1 commit = 1 Phase** を原則とし、commit message に `Phase-N` を明記する。並走 deliverables は parallel_safe / target_files 重複なしであれば同 Phase 内で同時 commit してよい。

## 4. cross_phase_invariants (全 Phase 共通の不変条件)

本パターン適用中は全 Phase で以下を満たすこと。違反は実装 task の差戻し条件となる。

- **F-RULE-04 整合 (polling 禁止 / event-trigger 単発)**: helper script は呼ばれた瞬間に 1 行 append して即 exit する。wait loop / sleep ベースの polling は導入しない。watchdog は launchd / cron 側に閉じる
- **F-RULE-09 / D-RULE 抵触なし**: rotation / archive を含む全操作は破壊的操作 (rm -rf / force push / sudo / SIGKILL 等) を伴わない。Phase-1〜4 全てで監視 script の append / Edit のみで完結する
- **RACE-001 厳格分離**: 各 Phase の target_files は重複しない。並走発注時は family (kaseifu) が target_files の重複を fail-fast で検出する
- **1 commit = 1 Phase**: phased rollout の追跡性を担保する。複数 Phase を 1 commit に詰め込まない (revert 単位を Phase に揃える)
- **append-only 不変**: event log の既存 events を編集・削除しない。helper script は `>>` 演算子のみ使用し mkdir lock で並走を逐次化

## 5. 適用例: 本 cmd_log lifecycle (commits 87fee82 〜 1c6d0fd)

| Phase | task_id | commit | deliverable 概要 |
| --- | --- | --- | --- |
| Phase-1 | task_064a | `87fee82` | `scripts/cmd_log_append.sh` 新設 (6 event_type validation / mkdir lock / append-only / event_id padding `evt_%04d`) |
| Phase-1 | task_064b | `a55bb0a` | `instructions/ojousama.md` + `kaseifu.md` に cmd_log 呼出手順組込 (cmd_issued / cmd_acknowledged / cmd_dispatched / cmd_qc_started / cmd_aggregated / cmd_completed の 6 event 呼出例) |
| Phase-2 | task_064c | `335f9b1` | `scripts/watchdog.sh` を `walk_cmd_log` 関数で events walk + open_tasks 抽出 + per-task age check + alert / `queue/.watchdog_state` を YAML 化 (`alerted: <task_id>: <ts>` per-task dedupe) / 旧経路 `check_legacy_single_task` も並走維持 |
| Phase-3 | task_064d | `1c98c52` | `queue/inbox/ojousama_critical.yaml` 新設 + `notify_human.sh` に `--severity` / `--category` / `--related-yaml` 引数追加 (severity=critical 時のみ永続キュー append + tmux + ntfy の 3 経路同時配信 / 旧 2-arg signature は severity=low の互換動作) |
| Phase-3 | task_066a | `155e20f` | `scripts/hooks/precompact_notify.sh` + `postcompact_resume.sh` の option_C 2-hook flag 連携で unread=0 でも resume nudge を送信 (skip 仕様は flag 不在時のみ維持) |
| Phase-3 | task_064e | `3ca7c63` | `forbidden_actions.md` F-RULE-08 緩和補項 + `protocol.md` Section 3.1 命名規約 + Section 4.1/4.2 schema + 各ロール instructions に critical 通知例 + `CLAUDE.md` Mailbox v0.3 critical 例外段落 |
| Phase-4 | task_064f | `1c6d0fd` | `scripts/watchdog.sh` から `check_legacy_single_task` + `CMD_FILE` / `REPORT_FILE` 定数を削除 (360 → 282 行 / -78 行) |
| Phase-4 | task_064g | `1c6d0fd` | `forbidden_actions.md` F-RULE-08 補項を「例外規範 (確定 / Phase-4)」見出しへ書換 + `CLAUDE.md` Mailbox v0.3 critical 例外確定 + Watchdog 節を cmd_log ベース前提に更新 |

**学んだ教訓**:

- Phase-1 で event log の payload schema を 6 段全て揃えてから Phase-2 へ進めたため、Phase-2 watchdog の walk ロジックが安定 (event_type 列挙が確定済 → switch case で安全に分岐できた)
- Phase-2 の二重監視は false-positive を一時的に許容することで false-negative の漏れ検知を確保。Phase-4 で旧経路を削除する判断材料にもなる
- Phase-3 で並列発注した 3 commit (task_064d / task_066a / task_064e) は target_files が `notify_human.sh` / `inbox_write.sh` / hooks / instructions に分かれており RACE-001 を満たした。skill 候補は事前評価で並列性を担保する設計が肝要
- Phase-4 では「緩和」「再導入」「Phase-2 拡張」など過渡期の文言を全て確定文言に書換 (`forbidden_actions.md` で 0 件確認)。確定運用への移行が文言にも反映されることで、後続 task が Phase 過渡期と勘違いしないよう抑止する

## 6. 再利用シナリオ (将来適用候補)

本パターンは cmd lifecycle に限らず、以下の領域へ転用可能性がある。各シナリオは適用時に Phase-1 で payload schema を確定させる前提。

### 6.1 report YAML lifecycle 化

- **対象**: `queue/kaseifu_to_ojousama.yaml` / `queue/{role}_report.yaml` 等の集約報告 / 完了報告
- **event 例**: `report_drafted` (executor) / `report_qc_started` (shitsuji) / `report_qc_passed` (shitsuji) / `report_aggregated` (kaseifu) / `report_acknowledged` (ojousama)
- **適用可能性**: 中〜高 — 既存 4 ポイント通知と統合余地あり / cmd_log と統合可能 (esc_063_04 が議題化済)
- **risk**: report YAML の上書き運用と event log の append-only が二重管理になる懸念。statement-of-record をどちらに置くか Phase-1 で決定する必要あり

### 6.2 jiro-log 等の外部 repo lifecycle 追跡

- **対象**: 外部 repo (例: `jiro-log`) の作業 lifecycle (例: `task_imported` / `analysis_started` / `pr_drafted` / `pr_merged`)
- **event 例**: 外部 repo 操作の各遷移点を本 repo の `queue/<external_repo>_log.yaml` に append
- **適用可能性**: 中 — 外部 repo 側に helper script を配置する必要 / 認証境界の整理が必要
- **risk**: 外部 repo への push 権限 / API 認証境界をまたぐ。Phase-1 で「読み取り専用」「書込みは local repo の event log に閉じる」の境界を確立する必要

### 6.3 inbox message lifecycle 化

- **対象**: `queue/inbox/{role}.yaml` の `messages: [{from, ts, body, read}]` の `read` 状態遷移
- **event 例**: `message_received` / `message_read` / `message_acknowledged` / `message_resolved`
- **適用可能性**: 低〜中 — 既存 read: false → read: true の単純 toggle で運用上は十分 / event log の overhead が見合わない
- **risk**: Premature Generalization (現運用で問題が観測されていない領域への適用は慎重に)

### 6.4 maid task lifecycle 詳細追跡

- **対象**: メイド task の per-step lifecycle (`step_started` / `step_completed` / `step_failed` / `task_self_review` 等)
- **event 例**: maid 自己診断と self_assessment の証跡を event log 化
- **適用可能性**: 低 — 既存 report YAML で十分。観測必要性が高い特定 maid (例: 失敗多発 maid) のみ追跡を有効化する形が現実的
- **risk**: events 数が爆発的に増える (1 task = 数十 events 級)。rotation 規範の前倒しが必要

---

新規シナリオ適用時は、本ドキュメントの **2. event schema** に倣って payload を定義し、**3. Phase 別 roll-out** に倣って 4 段階の cut-over を計画する。**4. cross_phase_invariants** は新規シナリオでも維持必須。

<!-- task_067 -->
