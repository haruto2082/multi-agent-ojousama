# multi-agent-ojousama

Claude Code + tmux によるマルチエージェントシステム。

## 階層構造

```
殿（ユーザー）
  └─ お嬢様（ojousama）：指揮・承認・報告
       └─ 家政婦（kaseifu）：タスク分解・進捗管理
            └─ メイド × N（maid_01〜）：並列実行
```

## セットアップ

```bash
chmod +x scripts/*.sh

# デフォルト4体のメイドで起動
./scripts/setup.sh

# メイド数を指定する場合
./scripts/setup.sh 8
```

## 停止

```bash
./scripts/stop.sh
```

## 通信フロー

```
殿が指示
  → お嬢様が queue/ojousama_to_kaseifu.yaml を作成
  → 家政婦が分解して queue/kaseifu_to_maid_XX.yaml を作成
  → メイドが実行して queue/maid_XX_report.yaml を作成
  → 家政婦が集約して queue/kaseifu_to_ojousama.yaml を作成
  → お嬢様が殿に報告
```

## 注意事項

- tmux通知は必ず2ステップで送ること（`scripts/notify.sh` を使用）
- 家政婦はメイドへの通知を同時に送らない（フレンドリーファイア防止）
- コンテキスト圧縮後は `CLAUDE.md` の起動手順を再実行
- API料金に注意（Claude Max契約推奨）
