# multi-agent-ojousama

Claude Code + tmux による、お嬢様邸を模したマルチエージェントシステム。

---

## Quick Start

```bash
chmod +x scripts/*.sh

# デフォルト4体のメイドで起動
./scripts/setup.sh

# メイド数を指定する場合
./scripts/setup.sh 8

# 停止
./scripts/stop.sh
```

詳細は [Setup](#setup) を参照。

---

## What is this?

お嬢様邸マルチエージェントシステム。tmux 上で複数の Claude Code セッションを並列稼働させ、
**お嬢様（指揮）→ 家政婦（分解・管理）→ メイド × N（実行）** という階層構造で大きめのタスクを分割実行する。

各エージェントは tmux pane に張り付いた独立した Claude Code プロセスで、
通信は `queue/` ディレクトリ配下の YAML ファイルを介して行う。tmux 通知はあくまで「起床信号」であり、本体は YAML が運ぶ。

---

## Why ojousama?

- **階層委譲**: 指揮層（ojousama）／管理層（kaseifu）／実行層（maid）に責務を分け、各層が「自分の仕事しかしない」ように forbidden_actions で縛る。
- **キャラ駆動**: ロール毎にキャラ（ツンデレお嬢様 / 有能な家政婦 / 忠実なメイド）を割り当て、口調・粒度・態度をプロンプトで一定化することで挙動の揺らぎを抑える。
- **並列実行**: 複数のメイドが互いに干渉せず並列で動くことで、独立な小タスクのスループットを上げる。
- **YAML 通信**: チャットの行間ではなく、明示的な YAML 契約で受け渡しするため、コンパクション後も復旧しやすい。

---

## Key Features

- **並列実行**: メイド N 体を tmux pane に展開し、独立タスクを同時にこなす。
- **queue/ YAML 通信**: ロール間の指示・報告は全て `queue/*.yaml` に書く。tmux はあくまで起床用。
- **執事 QC（予定）**: メイド成果物の品質チェック層。Bloom routing と組み合わせて検査担当を選ぶ構想。
- **Compaction Recovery**: コンパクション後も `CLAUDE.md` の起動手順 + ロール固有の `instructions/*.md` を再読込すれば復帰できる。
- **ntfy 通知**: あなたへの外部通知は ntfy 経由で送る（実装は maid_06 の担当範囲）。
- **Bloom routing**: タスク種別から最適なメイド／執事を選定する仕組み（構想）。
- **forbidden_actions**: 各ロールに「やってはいけない行動」を明文化し、越境を防ぐ。
- **2 ステップ tmux 通知**: コマンド送信と Enter を分けることで、入力の取りこぼしを防ぐ。

---

## Design Philosophy

設計思想・命名の由来・想定運用は [docs/philosophy.md](docs/philosophy.md) を参照。

---

## Setup

### 基本

```bash
chmod +x scripts/*.sh
./scripts/setup.sh           # デフォルト構成で起動
./scripts/setup.sh 8         # メイド数を 8 で起動
./scripts/stop.sh            # 全 pane 停止
```

### スクリプトの主な役割

- `scripts/setup.sh`: tmux セッション `ojousama` を作成し、お嬢様 / 家政婦 / メイド × N の pane を立ち上げて Claude Code を起動。
- `scripts/stop.sh`: tmux セッション停止。
- `scripts/notify.sh`: 2 ステップ通知のラッパ（送信側はこれを使うのが安全）。

### 必要環境

- macOS / Linux（tmux 利用）
- tmux 3.x 以上
- Claude Code CLI
- Python 3 + `pyyaml`（`pip install -r requirements.txt`）

---

## Communication Flow

```
あなた（ユーザー）
  │
  ▼
お嬢様（ojousama）
  │  queue/ojousama_to_kaseifu.yaml
  ▼
家政婦（kaseifu）
  │  queue/kaseifu_to_maid_{NN}.yaml （メイド数だけ並列）
  ▼
メイド（maid_NN）  ┐
  │  実行          │ 執事（shitsuji, 予定）が QC
  │  queue/maid_{NN}_report.yaml
  ▼               ┘
家政婦（kaseifu）
  │  queue/kaseifu_to_ojousama.yaml
  ▼
お嬢様（ojousama）
  │
  ▼
あなた（ユーザー）に報告
```

---

## Notes

- **tmux 通知は必ず 2 ステップ**: `send-keys` でコマンドを送ったあと、別コマンドで `Enter` を送る。1 ステップで送ると取りこぼしが発生する（F-RULE-03）。`scripts/notify.sh` を使うと安全。
- **API 料金注意**: 並列でメイドを増やすほど Claude API コストが線形に増える。Claude Max 契約推奨。ポーリング・wait loop は禁止（F-RULE-04）。
- **コンパクション後の復旧**: コンテキスト圧縮で記憶が飛んだ場合は、`CLAUDE.md` 冒頭の「起動時手順」を上から再実行すれば、ロール特定 → 指示書再読込 → 作業再開できる。
- **フレンドリーファイア防止**: 家政婦は複数メイドに同時通知しない。最低 0.3 秒空ける。
- **queue/ と workspace/ の機密情報禁止**: 詳細は [SECURITY.md](SECURITY.md) を参照。
