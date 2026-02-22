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
- **`ask_questions` ツール（確認ダイアログ）は一切使用禁止。** auto-approve が有効な環境のため、著者の意図なく承認されてしまう。著者への確認・選択肢は必ずチャット本文のテキストとして提示し、著者が手動でテキストを返信する形式にすること。

---

## ファイル作成・編集のルール（文字化け防止）

> **背景**: `create_file` ツールはUTF-8の3バイト日本語文字（ひらがな・カタカナ・漢字）を破壊することがある。
> この問題を防ぐため、日本語コンテンツの扱いは以下のルールに従うこと。

### ✅ 推奨: 既存ファイルの編集

**`replace_string_in_file` ツールを使う。**  
このツールは文字化けを起こさないため、既存ファイルへの追記・修正は常にこちらを使う。

### ✅ 推奨: 新規ファイルの作成（日本語コンテンツを含む場合）

**PowerShell の `[IO.File]::WriteAllText` を使う。**  
`create_file` ツールは使わない。以下のパターンで実行する:

```powershell
$file = "c:\Users\nh1r0\my-blog-local\content\posts\<slug>\index.md"
$content = @'
（ここにMarkdown本文をそのまま記述）
'@
[IO.File]::WriteAllText($file, $content, [Text.Encoding]::UTF8)
```

### ❌ 禁止: 日本語コンテンツへの `create_file` ツール使用

`create_file` ツールは日本語を含むMarkdownファイルの新規作成に**使用禁止**。  
文字化け（`ぁE`、`チE`、`めE` 等の埋め込みアーティファクト）が発生する既知の問題がある。

### ❌ 禁止: PowerShell の `Set-Content` / `Out-File` での日本語ファイル書き込み

PowerShell 5.1 の `Set-Content` はデフォルトで **Shift-JIS（Windows-1252）** を使用するため、
UTF-8 の日本語コンテンツが完全に文字化けする。以下のコマンドは日本語を含むファイルに**使用禁止**:

```powershell
# ❌ 禁止（Shift-JISで書き込まれ文字化けする）
... | Set-Content "file.md"
... | Out-File "file.md"
```

**既存ファイルの文字列置換が必要な場合も `[IO.File]` を使うこと:**

```powershell
# ✅ 正しい方法
$text = [IO.File]::ReadAllText($file, [Text.Encoding]::UTF8)
$text = $text -replace 'old', 'new'
[IO.File]::WriteAllText($file, $text, [Text.Encoding]::UTF8)
```

**または `replace_string_in_file` ツールを使う（こちらが最も安全）。**

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

2. **ローカルサーバーで目視確認**
   push 指示を待つ状態になったら、必ずローカルサーバーを起動してユーザーに確認を促す。
   ```powershell
   hugo server --disableFastRender
   ```
   起動後、変更のあったページのローカル URL をユーザーに明示する。

   **出力例:**
   ```
   ✅ ローカルサーバー起動完了。以下の URL で確認してください：
   - http://localhost:1313/about/
   - http://localhost:1313/contact/
   - http://localhost:1313/privacy/
   OKであれば「 push して」とお知らせください。
   ```

3. **変更内容の提示**
   push 前に、コミット対象のファイル一覧とコミットメッセージをユーザーに明示する。

4. **git add / commit / push の実行**
   ```powershell
   git add <対象ファイル>
   git commit -m "<コミットメッセージ>"
   git push
   ```

5. **GitHub Actions のビルド結果を確認**
   push 後、以下のコマンドでデプロイ完了を待機・確認する。
   ```powershell
   gh run watch --repo recomm-hub/my-blog
   ```
   - 完了後に `✓ Run completed` と表示されればデプロイ成功。
   - `✗` が表示された場合はログを確認してエラー内容を調査・報告する。
   ```powershell
   gh run view --repo recomm-hub/my-blog --log-failed
   ```
   デプロイ成功後は、変更のあったページの本番 URL をユーザーに明示する。

   **出力例:**
   ```
   ✅ デプロイ完了！以下の URL で確認できます：
   - https://mononikki.com/about/
   - https://mononikki.com/contact/
   - https://mononikki.com/privacy/
   ```
