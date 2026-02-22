# GitHub Copilot 共通インストラクション

このファイルは GitHub Copilot が会話開始時に自動的に読み込む定義ファイルです。
AIはこのファイルを参照し、ファイル配置・フォルダ構成を正確に把握した上で作業を行ってください。

---

## フォルダ構成とファイルの役割

### `.github/agents/` — エージェント定義（Copilot Chat で使うワークフロー）

| ファイル | 役割 |
|---------|------|
| `daily-workflow.md` | 記事作成ワークフロー全体の定義。著者が毎日使うメインの指示書 |

> **注意**: `.github/agents/` に置かれたファイルは VS Code の Copilot Chat でエージェントとして認識される。
> 新しい手順・チェックリスト類は原則 `prompts/` に置き、`daily-workflow.md` から参照する。

### `prompts/` — プロンプト・手順書（エージェントから参照される）

| ファイル | 役割 |
|---------|------|
| `fact-check.md` | ファクトチェックの手順・チェック観点・アウトプット形式 |
| `review-checklist.md` | 公開前の品質チェックリスト |
| `review-template.md` | レビュー出力のテンプレート |
| `seo-strategy.md` | SEO戦略・キーワード選定ガイド |
| `style-A-ranking.md` | 記事スタイルA: ランキング形式 |
| `style-B-solution.md` | 記事スタイルB: 問題解決形式 |
| `style-C-comparison.md` | 記事スタイルC: 比較形式 |
| `style-D-scene.md` | 記事スタイルD: シーン訴求形式 |
| `style-E-experience.md` | 記事スタイルE: 体験談形式 |
| `style-F-knowledge.md` | 記事スタイルF: 知識・解説記事 |

### `scripts/` — 自動化スクリプト

| ファイル | 役割 |
|---------|------|
| `post.ps1` | 楽天 API を呼び出して記事雛形を生成。実行時に `_snapshot.json` も生成する |
| `knowledge.ps1` | 知識・解説記事の雛形生成 |
| `generate-covers.ps1` | カバー画像の自動生成 |

### `data/` — 設定ファイル

| ファイル | 役割 |
|---------|------|
| `tracking_ids.yaml` | 楽天アフィリエイト計測ID |
| `referrals.yaml` | 紹介コード・アフィリエイトリンク |
| `banner.yaml` | バナー設定 |
| `events.yaml` | イベント設定 |

### `content/posts/YYYY-MM-DD-slug/` — 記事バンドル

各記事ディレクトリに以下のファイルが含まれる:

| ファイル | 役割 |
|---------|------|
| `index.md` | 記事本文（公開対象） |
| `cover.jpg` | カバー画像（公開対象） |
| `_snapshot.json` | 記事生成時点の楽天API取得データ（ファクトチェック用エビデンス、公開されない） |
| `_fact-check.md` | ファクトチェック結果レポート（公開されない） |

> `_` で始まるファイルは Hugo のビルドから除外され、公開されない。

### `docs/` — 仕様書・TODO

| ファイル | 役割 |
|---------|------|
| `SPEC.md` | システム全体の仕様書 |
| `TODO.md` | 開発TODO |

---

## AI への行動指針

- **ファイル配置は上記の通りに従う。** `prompts/` に置く手順書を `.github/agents/` に作成しない。
- **`daily-workflow.md` は `.github/agents/` にのみ存在する。** `prompts/` には置かない。
- **`fact-check.md` は `prompts/` にのみ存在する。** `.github/agents/` には置かない。
- ファイルを作成・移動する前に、上記の表でどのフォルダが正しいか確認する。

---

## git push ルール

### 原則：ユーザーの明示的な指示があるときのみ push する

- AIは自律的に `git push` を実行してはならない。
- ファイルの編集・作成はローカルで完結させ、push は行わない。
- ユーザーから「push して」「デプロイして」「公開して」等の明示的な指示を受けた場合のみ push を実行する。

### push 時の手順（必ず以下の順序で実行する）

1. **ローカルビルド確認**
   ```powershell
   hugo --gc --minify
   ```
   エラーが出た場合は push せず、先にエラーを修正する。

2. **変更内容の提示**
   push 前に、コミット対象のファイル一覧とコミットメッセージをユーザーに明示する。

3. **git add / commit / push の実行**
   ```powershell
   git add <対象ファイル>
   git commit -m "<コミットメッセージ>"
   git push
   ```

4. **GitHub Actions のビルド結果を確認**
   push 後、以下のコマンドでデプロイ完了を待機・確認する。
   ```powershell
   gh run watch --repo recomm-hub/my-blog
   ```
   - 完了後に `✓ Run completed` と表示されればデプロイ成功。ユーザーに報告する。
   - `✗` が表示された場合はログを確認してエラー内容を調査・報告する。
   ```powershell
   gh run view --repo recomm-hub/my-blog --log-failed
   ```
