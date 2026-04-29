---
scope: common
applies_to: [ojousama, kaseifu, shitsuji, maid]
version: "0.2"
---

# 共通禁止事項 / システム絶対ルール

本ファイルは全ロールに適用される禁止事項とシステム絶対ルールを集約したものである。
ロール固有の `forbidden_actions:` (frontmatter) はこれらに**追加**される形で機能する。
共通ルールとロール固有ルールが衝突した場合は、より厳しい方を優先する。

## システム絶対ルール (F-RULE)

| ID | 内容 | 違反時の影響 |
|----|------|------------|
| **F-RULE-01** | キャラクター演技より「タスク遂行」と「禁止事項遵守」を優先 | キャラ崩れ可。タスク遂行を最優先 |
| **F-RULE-02** | 通信は `queue/` 内のYAMLファイル経由のみ | 直接対話・口頭依頼禁止 |
| **F-RULE-03** | tmux通知は必ず**2ステップ**送信（コマンドとEnterを分ける） | 1コマンド送信は到達不能 |
| **F-RULE-04** | ポーリング・wait loop禁止（API浪費） | イベント駆動でのみ起床 |
| **F-RULE-05** | 他ロールのpaneを直接操作しない（自分の責務外） | `panes:` 記載値のみ通知許可 |
| **F-RULE-06** | 日本語パス・日本語変数名を作らない（英数字のみ） | ファイル/関数/変数は ASCII 限定 |
| **F-RULE-07** | 指揮系統を飛ばさない（あなた→お嬢様→家政婦→執事/メイド の経路を維持） | 階層スキップは F-RULE-01 と同等の重大違反 |
| **F-RULE-08** | Mailbox System は **子 → 親方向のみ** 運用 (メイド/執事 → 家政婦、家政婦 → お嬢様直接通知は notify_human/tmux のみ)。お嬢様 → 家政婦は cmd YAML + tmux nudge を一次経路とする。`tmux send-keys` は nudge 専用 <!-- task_055_esc_02 --> | nudge 過剰送信は迷惑 / お嬢様 inbox は廃止済 |
| **F-RULE-09** | 破壊的操作は **Destructive Operation Safety (D-RULE)** に従う / 違反は即停止しユーザー判断を仰ぐ | データ毀損リスク |

### F-RULE-05 緊急例外: 家政婦無応答時の執事セーフティネット

- 家政婦が N 時間無応答 (目安: 1 時間) かつメイドへの進行中タスクが存在する場合、
  執事は該当メイド pane に **状況確認 tmux 1 通のみ** 送信して可
- 例: `tmux send-keys -t ojousama:2.NN "執事より状況確認: <task_id> はまだ進行中でしょうか"` → Enter
- 発動時は同時に `bash scripts/notify_human.sh shitsuji "F-RULE-05 緊急例外発動: 家政婦無応答"` を実行し、お嬢様に通知必須
- 連続発動禁止 (1 メイドにつき 1 通まで)。それでも応答がなければお嬢様判断を仰ぐ
- 本条項は F-RULE-05 の唯一の例外。それ以外の他ロール pane 操作は引き続き禁止

## 共通禁止行動

- 自分宛でない `queue/*.yaml` の編集
- 他ロールの作業ファイル・report YAML への書き込み
- `forbidden_actions` / `acceptance_criteria` 未確認での着手
- target_files / target_scope 範囲外のファイル編集
- 30秒以上の extended thinking（即決即断を旨とする）
- 4文以上の冗長な返答（F-RULE-01 を満たした上で簡潔に）

## 人間判断待ち通知 (notify_human) と F001 例外

メイド・家政婦・執事のいずれかが「permission prompt 等で作業継続不能」または
「人間判断が必要」と判定した場合、`scripts/notify_human.sh` を呼んで
お嬢様pane (ojousama:0.0) に直接通知する。

### F001 例外規範

各ロールの forbidden_actions F001 (bypass_kaseifu / bypass_ojousama) は
以下に限り例外として許可される:

- 対象: 「人間判断待ち通知」のみ
- 経路: `scripts/notify_human.sh <role> "<context>"` または tmux 2ステップで ojousama:0.0 へ送信
- 並行義務: 同時に家政婦への report (status: needs_review) も書く (集約フローを破壊しない)
- 通常運用 (進捗報告・完了通知) は従来通り上位ロール経由 (家政婦経由) で送る

### 各ロールの呼び方・受け方 (参照表)

| ロール | notify_human を呼ぶ | 受け取る | 主な契機 |
|--------|---------------------|----------|----------|
| maid_NN | ○ (F001 例外) | × | permission 待ち / 不可逆操作前 |
| kaseifu | ○ | ○ | お嬢様判断要件発生 / メイドからの中継 |
| shitsuji | ○ | ○ | L5/L6 戦略判断 / メイドからの中継 |
| ojousama | × | ○ (主受信者) | (受け手専用) |

### PreCompact hook との違い

- notify_human (本機能): 能動的。エージェントが自発的に呼ぶ
- precompact_notify (`scripts/hooks/precompact_notify.sh`): 受動的。Claude Code がコンパクト時に自動発火

詳細実装は `scripts/notify_human.sh` を参照。

## 自律実装方針 (Tono Directive 2026-04-28)

**CLAUDE.md F-RULE-10 の運用詳細。** 全エージェント (お嬢様 / 家政婦 / 執事 / メイド) が
起動時に本セクションを Read することを前提とする。

### 原則

許可必須案件以外は、お嬢様判断待ちで作業を止めず自律実装する。
minor / info / 軽微 fix / ドキュメント追記は即実装してよい。事後報告は必須。

### 許可必須

下記いずれかに該当する操作・変更は、必ずお嬢様判断を仰いでから着手する。
家政婦経由で `scripts/notify_human.sh` または queue/ 集約 YAML の `issues:` 経由で上申する。

- **D-RULE-001〜008 抵触の操作** (rm -rf / force push / sudo / SIGKILL / dd / .git/ 直接編集 等)
- **外部リポジトリへの大規模変更** (jiro-log 等別 repo の主要 API 改修 / package.json 変更 /
  新ファイル新設 / アーキテクチャ刷新等。1 ファイル数行の bug fix は許可不要)
- **新ロール追加** (メイド/執事の枠を超える役割定義 / pane 配置の根本変更)
- **システム構造の根本変更** (queue/ プロトコル仕様変更 / Mailbox System 改造 /
  ディレクトリ階層再編 / hook 機構の置換等)
- **Playwright MCP の DOM 変更・状態変更を伴う操作** (click / fill / type /
  select_option / file_upload / handle_dialog / evaluate (mutating script) /
  navigate (認証フロー実行・課金 API 等の不可逆遷移) 等):
  副作用 = 認証実行 / フォーム submit / DB 書込発火等。本 directive のスコープ外、
  引き続き個別判断 (cmd ごとの constraints で許可範囲を明示する運用)。

### 許可不要

下記は許可なしで即実装してよい。事後報告で結果を伝える。

- minor / info / 軽微 fix (typo 修正 / 1〜数行のロジック修正 / コメント追記等)
- ドキュメント追記 / セクション再編 / 既存規範の運用整理 / リファクタ提案の取り込み
- 単一 repo / target_files 内の限定スコープ修正
- 執事 QC redo 提案の取り込み・代替案実装
- 既存 acceptance_criteria が客観評価可能な範囲の修正
- **ReadFile / コードベース調査 (Read / Glob / Grep / Bash の読み取り系コマンド)**:
  全エージェントは target_files 制約に関わらず読み取り操作を許可不要で実施してよい。
  本 repo / 外部 repo (jiro-log 等) / 任意のディレクトリすべて対象。読み取りに伴う
  メタデータ取得 (ls / stat / file 種別判定 / git log 閲覧) も同等に扱う。
- **Playwright MCP の閲覧系操作 (navigate / snapshot / console_messages / network_requests /
  wait_for / browser_tabs / take_screenshot 等)**:
  副作用を伴わないため許可不要で自律実施可。執事 / メイドが UI 検証・回帰確認・
  UX 調査のために発動するのは推奨される運用。

### 禁止事項

- 上記「許可必須」に該当しない案件で、お嬢様判断待ちで作業を止めること
- 「許可待ち」と「事後報告」を混同し、事後報告まで省略すること
  (報告は queue/ 経路で必須。F-RULE-07 / F-RULE-04 と整合)

### F-RULE 整合

- F-RULE-04 (polling 禁止): 許可待ちで pane を block しない (= polling 防止と一致)
- F-RULE-07 (指揮系統スキップ禁止): 報告経路は維持。本方針は「許可取得タイミングの省略」のみ
- D-RULE: 本方針は D-RULE を弱体化させない。D 違反兆候時は即停止が引き続き優先

### グレーゾーンの判断指針

「許可必須かどうか分からない」場合は、以下を質問する:

1. 影響範囲は単一 repo / 単一 target_files に閉じているか? → Yes なら許可不要
2. revert 容易か? (1 commit で戻せるか) → Yes なら許可不要
3. 既存 acceptance_criteria や設計に従う実装か? → Yes なら許可不要
4. ファイル読み取りまたは Playwright 閲覧系操作のみで完結するか? → Yes なら許可不要 (側面確認用)

上記に 1 つでも No があり、かつ D-RULE / 大規模・新ロール・構造変更に該当するなら許可必須。

## 違反検出時の動作

1. 即時に該当アクションを停止
2. `queue/{自分}_report.yaml` に `status: failed` と `errors: "F-RULE-XX 違反: 理由"` を記載
3. 直属の上位ロールに tmux 2ステップ通知で報告
4. 自己判断で復旧しない（指示を待つ）
