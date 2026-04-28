---
name: skill-creator
description: 新しいClaude Code skillの雛形を作成する。Anthropic公式skill仕様（YAML frontmatter + Markdown 本文）に準拠したSKILL.mdを skills/<name>/ 以下に生成する。「スキルを新規作成」「skill雛形を作って」等の依頼で発動。
---

# skill-creator

新規スキルディレクトリと SKILL.md の雛形を生成する。

## 起動条件

- 「`<skill_name>` という skill を新規作成して」
- 「skill の雛形がほしい」
- 既存スキルを下敷きに新規スキルを派生させたいとき

## 必須情報（ユーザーから受け取る or 推定する）

| 項目 | 説明 | 必須 |
|---|---|---|
| `name` | ハイフン区切りの短い識別子（例: `ojousama-foo`） | yes |
| `description` | 1〜2文。**起動条件を必ず含める**（モデルが skill を選ぶ判断材料になる） | yes |
| `purpose` | このskillの目的を本文1段落で | recommended |
| `steps` | 実行手順（番号付きリスト） | recommended |
| `inputs` | 受け取る引数・前提 | optional |
| `outputs` | 出力の形式・置き場 | optional |

## 実行手順

1. ユーザーから `name` と `description` を受け取る（不足なら 1 回だけ確認質問）。
2. `skills/<name>/` ディレクトリを作成。
3. 下記テンプレに沿って `skills/<name>/SKILL.md` を生成する。
4. 必要なら補助ファイル（`scripts/`, `assets/`）の置き場をディレクトリ内に切る。
5. 生成後、生成したパスと description を表示してユーザーに確認を求める。

## SKILL.md テンプレート

```markdown
---
name: <name>
description: <1〜2文。「〜のとき発動」という起動条件を必ず含める>
---

# <name>

<このskillの一行紹介>

## 起動条件

- ユーザーがこういう依頼をしたとき
- システムがこういう状態のとき

## 実行手順

1. ステップ1
2. ステップ2
3. ステップ3

## 入力 / 出力

- 入力: ...
- 出力: ...

## 注意

- やってはいけないこと
- 連携が必要な他skill / agent
```

## description を書くときの原則

- **何ができるか + いつ起動するか** を両方含める
- 主語を曖昧にしない（「〜を生成する」「〜をチェックする」）
- 起動キーワード（自然言語の依頼例）を最低 1 つ入れる
- 100〜200 文字を目安にする（長すぎると検索精度が落ちる）

## 注意

- frontmatter の `name` は ディレクトリ名と一致させる。
- 既存 skill 名と衝突したら警告して中断する。
- F-RULE-06（英数字パスのみ）に従い、ディレクトリ名・ファイル名に日本語を使わない。
