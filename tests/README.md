# tests/ - テスト雛形

本ディレクトリは将来の **bats（Bash Automated Testing System）** ベースのテスト導入を想定した雛形。
現時点ではテスト本体は未実装で、ディレクトリ構造のみ用意している。

---

## 構成

```
tests/
├── README.md           本書
├── test_helper/        bats のヘルパ（bats-assert / bats-support 等を導入予定）
├── unit/               ユニットテスト（scripts/ 内の関数単位）
└── e2e/                エンドツーエンドテスト（setup.sh 起動 → queue 経由のフロー検証）
```

---

## 導入予定

### bats 本体

```bash
brew install bats-core
```

### ヘルパライブラリ

```bash
git submodule add https://github.com/bats-core/bats-assert  tests/test_helper/bats-assert
git submodule add https://github.com/bats-core/bats-support tests/test_helper/bats-support
```

> サブモジュール導入時には `.gitmodules` の整備も併せて行うこと。

---

## テスト方針（案）

### unit/

- `scripts/notify.sh` の 2 ステップ送信が正しい順序で実行されるか
- ロール識別ロジック（`tmux display-message` のフォールバック）が動くか
- YAML パース処理（pyyaml）の最低限の正常系

### e2e/

- `scripts/setup.sh` で tmux セッション `ojousama` が立ち上がるか
- お嬢様 → 家政婦 → メイド の queue/YAML 受け渡しが完走するか
- `scripts/stop.sh` で全 pane が綺麗に落ちるか

---

## 実装着手前の確認事項

- macOS / Linux 両方で bats が動くか
- tmux を絡めた e2e テストは CI（GitHub Actions）で再現可能か（`tmux new-session -d` で代替）
- CI 導入は OSS 公開しない方針のため当面見送り。ローカル実行のみで運用する想定

---

現時点では空の `.gitkeep` のみが各サブディレクトリに置かれている。
テスト実装が始まったら本書を更新すること。
