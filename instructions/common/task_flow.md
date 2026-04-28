---
scope: common
applies_to: [ojousama, kaseifu, shitsuji, maid]
version: "0.1"
---

# タスクライフサイクルと QC 三段階フロー

## 1. ライフサイクル概要

```
あなた
 ├─[口頭]→ お嬢様
 │           ├─[ojousama_to_kaseifu.yaml]→ 家政婦
 │           │                              ├─[kaseifu_to_maid_NN.yaml]→ メイドN  (Stage 1)
 │           │                              │                              └─[maid_NN_report.yaml]→
 │           │                              ├─[kaseifu_to_shitsuji_NN.yaml]→ 執事 (Stage 2)
 │           │                              │                              └─[shitsuji_report.yaml]→
 │           │                              └─[kaseifu_to_ojousama.yaml]→ お嬢様 (Stage 3)
 │           └─[あなたへ口頭報告]
 └← 結果
```

各ロールはタスク完了直後に **1 度だけ** 上位へ通知し、以後は idle に戻る（F-RULE-04）。

## 2. QC 三段階フロー

### Stage 1: メイドによる実行と自己検証

1. 家政婦から `kaseifu_to_maid_{NN}.yaml` で割当を受ける
2. `target_files` / `constraints` / `acceptance_criteria` を確認（未確認着手は F-RULE-07 相当）
3. `workspace/` 配下で実装
4. **自己検証**: 自身で acceptance_criteria を 1 項目ずつ ✓/✗ 確認
5. `queue/maid_{NN}_report.yaml` を作成（必須フィールドは下記スキーマ参照）
6. `skill_candidate` フィールドに、本タスクで再利用可能と感じた手順・スクリプト案があれば記載
7. 家政婦に 1 度だけ tmux 通知

### Stage 2: 執事 (shitsuji) による QC

1. 家政婦から `queue/kaseifu_to_shitsuji_{NN}.yaml` で QC 依頼を受ける
2. 全メイドの `maid_{NN}_report.yaml` を読む
3. 各メイドについて以下を判定:
   - **scope_match**: 編集ファイルが `target_files` 内に収まっているか
   - **acceptance_pass**: `acceptance_criteria` 全項目を満たすか
   - **forbidden_clean**: 共通/個別 forbidden_actions に抵触していないか
4. `queue/shitsuji_report.yaml` を作成（全メイド分を集約形式で記載）
5. 家政婦に 1 度だけ tmux 通知

### Stage 3: 家政婦による集約とあなたへの上申

1. 全メイド報告 + 執事 QC を読み合わせる
2. いずれかが `failed` / `needs_review` ならお嬢様に正直に報告（隠蔽禁止）
3. `queue/kaseifu_to_ojousama.yaml` に集約報告を作成
4. お嬢様に 1 度だけ tmux 通知

お嬢様は本ファイルを 2〜3 文に要約しあなたへ口頭報告。

## 3. report YAML スキーマ（必須）

すべてのメイド報告 (`maid_{NN}_report.yaml`) は以下の **必須フィールド** を含む:

```yaml
task_id: "..."                 # 必須
from: "maid_NN"                # 必須
to: "kaseifu"                  # 必須
status: "completed"            # 必須: completed / partial / failed / needs_review
summary: "..."                 # 必須: 2〜3 文
files_created: []              # 必須: 配列（空でも可）
files_modified: []             # 必須: 配列（空でも可）
acceptance_check:              # 必須: acceptance_criteria 各項目の真偽
  criterion_1: "true/false"
  criterion_2: "true/false"
errors: null                   # 必須: 失敗時は文字列で原因
skill_candidate:               # ★必須★
  found: "true/false"
  description: ""              # found=true の場合は再利用案を 1〜3 文で記述
```

### `skill_candidate` フィールドの目的

メイドは作業中に「これは今後も繰り返し発生しそう」と感じた手順・スクリプト・テンプレートがあれば、`skill_candidate.found: true` として `description` に概要を書く。
家政婦は集約時に複数メイドの skill_candidate を見て、`scripts/` への昇格可否をお嬢様に提案する。
これは上流リポジトリ移植判断（first_setup.sh 系の機能棚卸し）と紐づく運用情報になる。

`found: false` の場合 `description` は空文字列。

## 4. 失敗時の挙動

| 状態 | 報告 status | 対応 |
|------|-------------|------|
| 達成 | `completed` | Stage 2 へ |
| 部分達成 | `partial` | 家政婦が再割当の要否判断 |
| 失敗 | `failed` | 自己判断で再試行しない。家政婦の指示を待つ |
| 判断保留 | `needs_review` | 家政婦経由でお嬢様に判断仰ぐ |

ポーリング・自動再試行は禁止（F-RULE-04）。
