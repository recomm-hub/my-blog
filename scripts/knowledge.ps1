<#
.SYNOPSIS
    お役立ち知識記事の Markdown ファイルを自動生成するスクリプト。

.DESCRIPTION
    楽天APIを使わず、知識・ハウツー系の記事テンプレートを生成します。
    アフィリエイトリンクなしの「お役立ち記事」を素早く書くためのツール。
    関連するレビュー記事への内部リンク欄を自動で付けます。

.PARAMETER Keyword
    記事のテーマ（例: "花粉症の原因と対策", "空気清浄機のフィルター掃除"）

.PARAMETER Slug
    URLスラグ（省略時はキーワードから自動生成）
    英語で指定推奨（例: "hay-fever-basics", "air-purifier-filter-care"）

.PARAMETER RelatedPost
    関連するレビュー記事のスラグ（省略可、複数指定可）
    例: -RelatedPost "air-purifier-2026","robot-vacuum-2026"

.EXAMPLE
    .\scripts\knowledge.ps1 "花粉症の時期と原因"
    .\scripts\knowledge.ps1 "花粉症の時期と原因" -Slug "hay-fever-season-guide"
    .\scripts\knowledge.ps1 "空気清浄機のフィルター掃除" -Slug "air-purifier-filter-care" -RelatedPost "air-purifier-2026"
    .\scripts\knowledge.ps1 "テレワーク 腰痛対策" -Slug "remote-work-back-pain-tips" -RelatedPost "desk-chair-2026"
#>

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Keyword,

    [Parameter()]
    [string]$Slug = "",

    [Parameter()]
    [string[]]$RelatedPost = @()
)

# ──────────────────────────────────────────────
# 1. スラグとファイル名を決定
# ──────────────────────────────────────────────
$date = Get-Date -Format "yyyy-MM-dd"
$dateISO = Get-Date -Format "yyyy-MM-ddTHH:mm:ss+09:00"

if (-not $Slug) {
    # キーワードをそのままスラグに（日本語可だがSEO的には英語推奨）
    $Slug = $Keyword -replace '\s+', '-' -replace '[\\/:*?"<>|]', ''
    Write-Host "💡 -Slug を指定すると英語のURL（SEOに有利）にできます" -ForegroundColor Yellow
    Write-Host "   例: -Slug `"hay-fever-season-guide`"" -ForegroundColor Yellow
    Write-Host ""
}

$yearMonth = Get-Date -Format "yyyyMM"
$bundleName = $Slug
$bundleDir = Join-Path $PSScriptRoot "..\content\posts\$yearMonth\$bundleName"
$bundleDir = [System.IO.Path]::GetFullPath($bundleDir)
$filePath = Join-Path $bundleDir "index.md"

if (Test-Path $filePath) {
    Write-Host "⚠️ ファイルが既に存在します: $bundleName/index.md" -ForegroundColor Yellow
    $overwrite = Read-Host "上書きしますか？ (y/N)"
    if ($overwrite -ne "y") {
        Write-Host "中止しました。"
        exit 0
    }
}

# ページバンドル用ディレクトリ作成
if (-not (Test-Path $bundleDir)) {
    New-Item -ItemType Directory -Path $bundleDir -Force | Out-Null
}

# ──────────────────────────────────────────────
# 2. 関連記事リンクを生成
# ──────────────────────────────────────────────
$relatedLinks = ""
if ($RelatedPost.Count -gt 0) {
    $relatedLinks = @"

---

## 関連記事

"@
    foreach ($rp in $RelatedPost) {
        $relatedLinks += "- 👉 [関連レビュー記事はこちら](/posts/$rp/)`n"
    }
}

# ──────────────────────────────────────────────
# 3. Markdown ファイルを生成
# ──────────────────────────────────────────────

# タグからキーワードを分解（スペース区切りで複数タグに）
$tags = @($Keyword -split '\s+' | Where-Object { $_.Length -ge 2 })
if ($tags.Count -eq 0) { $tags = @($Keyword) }
# 「お役立ち」タグを追加
$tags += "お役立ち"
$tagsYaml = ($tags | ForEach-Object { "`"$_`"" }) -join ", "

$markdown = @"
---
title: "<!-- TODO: 32文字以内のタイトル。疑問形 or 「〜まとめ」「〜の基本」系 -->"
date: $dateISO
draft: true
categories: ["解説"]
tags: [$tagsYaml]
description: "<!-- TODO: 120文字以内。テーマのメインKWを前半に -->"
slug: "$Slug"
style: "F"
image: cover.jpg
ShowToc: true
TocOpen: true
---

<!-- 📝 この記事はお役立ち知識記事です（アフィリエイトなし） -->
<!-- 📋 執筆手順: prompts/style-F-knowledge.md の Step 1 → Step 2 を使ってください -->

## テーマ: $Keyword

<!-- TODO: prompts/style-F-knowledge.md Step 1 の指示で執筆 → Step 2 でレビュー -->

---

## 導入

（「〜って気になりません？」的なカジュアルな問いかけ。この記事で何がわかるか予告。100〜200字）

---

## そもそも〜って？（基礎知識①）

（「要するに〜」で始める。専門用語はカッコで補足。）

---

## 〜の原因 / 仕組み（基礎知識②）

（「知ってそうで知らない」ポイントを1つ入れる）

---

## 今日からできる対策 / コツ

### 1. （すぐできること）

（アクションレベルで具体的に。「自分はこうしてる」を入れる）

### 2. （もうひと手間）

（違う切り口で）

### 3. （意外と効果的なやつ）

（「これ地味に効くんですよね」的なトーンで）

---

## よくある勘違い

（「意外とみんなやりがち」系。1〜2つ。読んで「あっ」となるやつ）

---

## まとめ

（3行以内であっさり。要点だけ。「いかがでしたか？」は絶対NG）
$relatedLinks
"@

# UTF-8 BOM なしで書き出し
[System.IO.File]::WriteAllText($filePath, $markdown, [System.Text.UTF8Encoding]::new($false))

Write-Host ""
Write-Host "📝 知識記事ファイルを生成しました！" -ForegroundColor Green
Write-Host "   $filePath" -ForegroundColor White
Write-Host "   カテゴリ: 解説（アフィリエイトなし）" -ForegroundColor Cyan
Write-Host ""

# カバー画像を自動生成
Write-Host "🖼️ カバー画像を生成中..." -ForegroundColor Cyan
$coverScript = Join-Path $PSScriptRoot "generate-covers.ps1"
if (Test-Path $coverScript) {
    $bundleRelPath = "content\posts\$yearMonth\$bundleName"
    & $coverScript -PostPath $bundleRelPath -Force
}
else {
    Write-Host "   ⚠️ generate-covers.ps1 が見つかりません。手動で実行してください。" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "📋 次のステップ：" -ForegroundColor Yellow
Write-Host "   1. VS Code でファイルが開きます"
Write-Host "   2. prompts/style-F-knowledge.md の Step 1 プロンプトで本文を執筆"
Write-Host "   3. 同 Step 2 でセルフレビュー"
Write-Host "   4. prompts/review-checklist.md で最終チェック"
Write-Host "   5. draft: true → false に変更して Ctrl+S で公開"
Write-Host ""

# VS Code で開く
code $filePath
