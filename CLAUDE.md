# お嬢様邸 マルチエージェントシステム

## 起動時の必須手順（コンパクション後も必ず再実行）
1. 自分のpaneタイトルを確認する（window名は自動変更されるので使わない）
   ```bash
   tmux display-message -p '#{pane_title}'
   ```
2. paneタイトルに対応するinstructionsを読み込む
   - `ojousama` → `instructions/ojousama.md`
   - `kaseifu`  → `instructions/kaseifu.md`
   - `maid_*`   → `instructions/maid.md`
3. 禁止事項を確認してから作業開始

## システム絶対ルール
- キャラクター演技よりタスク遂行を**最優先**
- 通信は `queue/` 内のYAMLファイル経由のみ
- ファイルパス・変数名は英数字のみ（日本語パス禁止）
- tmux通知は必ず**2ステップ**で送る（コマンドとEnterを分ける）
- ポーリング禁止（イベント駆動のみ）
- 作業前に必ず `queue/` の自分宛YAMLを確認する

## 階層構造
```
殿（ユーザー）
  └─ お嬢様（ojousama）：指揮・承認・報告
       └─ 家政婦（kaseifu）：タスク分解・進捗管理
            └─ メイド×N（maid_01〜）：並列実行
```

## 通知コマンド（必ずこの形式で）
```bash
# ✅ 正しい2ステップ送信
tmux send-keys -t ojousama:kaseifu "メッセージ内容"
tmux send-keys -t ojousama:kaseifu Enter

# ❌ 禁止（Enter結合は動かない場合がある）
tmux send-keys -t ojousama:kaseifu "メッセージ内容" Enter
```
