---
name: ojousama-readme-sync
description: README.md と CLAUDE.md / instructions/*.md の整合性をチェックし、ロール一覧・ルール番号・主要パスのズレを検出する。READMEの同期確認や更新依頼があったときに発動する。
---

# ojousama-readme-sync

プロジェクトの README.md と他ドキュメント（CLAUDE.md, instructions/*.md）の記述ズレを検出する軽量チェッカー。
日本語版 README のみを対象とした最小実装。

## 起動条件

- 「README を同期確認して」「README が古くないか見て」
- ドキュメントの整合性チェック依頼
- 大きめのリファクタ後の最終確認

## チェック項目

1. **ロール一覧**: README に記載のロール名が `instructions/` 配下のファイル名と一致しているか
   - 期待: `ojousama`, `kaseifu`, `maid` (maid_01〜maid_08)
2. **F-RULE 番号の連続性**: CLAUDE.md の F-RULE-01..NN と README で言及される番号がズレていないか
3. **主要ファイルパス**: README が指す `scripts/setup.sh`, `config/settings.yaml`, `status_board.md` 等が実在するか
4. **maid_count**: `config/settings.yaml` の `maid_count` と README に書かれた人数が一致しているか

## 実行手順

1. README.md（存在すれば）を Read で読み取る。なければ「README.md が未作成です」と報告して終了。
2. 上記4項目をそれぞれ検証:
   - ロール一覧 → `ls instructions/` と突き合わせ
   - F-RULE → `grep -E '^- \*\*F-RULE-[0-9]+' CLAUDE.md` で抽出
   - パス → 各 `test -f` 相当の存在チェック
   - maid_count → `config/settings.yaml` を読んで照合
3. 不一致が見つかったら表形式で列挙。すべて整合していれば「整合性OK」と報告。

## 出力フォーマット

```
| 項目 | README記載 | 実際 | 一致 |
|---|---|---|---|
| ロール数 | 10 | 10 | ✓ |
| maid_count | 8 | 8 | ✓ |
| status_board.md | 言及あり | 存在 | ✓ |
| F-RULE 最大番号 | F-RULE-06 | F-RULE-06 | ✓ |
```

## 注意

- このスキルは**読み取り専用**。差分を提示するだけで、README を勝手に書き換えない。
- 修正提案は出すが、実際の編集はユーザーまたは家政婦の承認を経てから別タスクで実施する。
