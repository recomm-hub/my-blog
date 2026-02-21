<#
.SYNOPSIS
    楽天商品検索API を呼び出し、Hugo 記事の Markdown ファイルを自動生成するスクリプト。

.DESCRIPTION
    指定したキーワードで楽天市場を検索し、上位3商品の情報を取得。
    Hugo の front matter + rakuten ショートコード入りの Markdown ファイルを生成し、
    VS Code で自動的に開きます。

.PARAMETER Keyword
    検索キーワード（例: "空気清浄機", "ワイヤレスイヤホン"）

.PARAMETER Hits
    取得する商品数（デフォルト: 3、最大: 5）

.PARAMETER Sort
    並び順（デフォルト: -reviewCount）
    -reviewCount: レビュー件数の多い順
    -reviewAverage: レビュー評価の高い順
    standard: 標準
    -seller: 売上順

.EXAMPLE
    .\scripts\post.ps1 "空気清浄機"
    .\scripts\post.ps1 "ロボット掃除機" -Hits 5
    .\scripts\post.ps1 "ワイヤレスイヤホン" -Sort "-reviewAverage"
#>

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Keyword,

    [Parameter()]
    [ValidateRange(1, 5)]
    [int]$Hits = 3,

    [Parameter()]
    [string]$Sort = "-reviewCount"
)

# ──────────────────────────────────────────────
# 1. 環境変数チェック
# ──────────────────────────────────────────────
$appId       = $env:RAKUTEN_APP_ID
$affiliateId = $env:RAKUTEN_AFFILIATE_ID

if (-not $appId) {
    Write-Host "❌ 環境変数 RAKUTEN_APP_ID が設定されていません。" -ForegroundColor Red
    Write-Host ""
    Write-Host "以下のコマンドで設定してください：" -ForegroundColor Yellow
    Write-Host '  [System.Environment]::SetEnvironmentVariable("RAKUTEN_APP_ID", "あなたのAPP_ID", "User")'
    Write-Host ""
    Write-Host "設定後、VS Code を再起動してください。"
    exit 1
}

if (-not $affiliateId) {
    Write-Host "❌ 環境変数 RAKUTEN_AFFILIATE_ID が設定されていません。" -ForegroundColor Red
    Write-Host ""
    Write-Host "以下のコマンドで設定してください：" -ForegroundColor Yellow
    Write-Host '  [System.Environment]::SetEnvironmentVariable("RAKUTEN_AFFILIATE_ID", "あなたのアフィリエイトID", "User")'
    Write-Host ""
    Write-Host "設定後、VS Code を再起動してください。"
    exit 1
}

# ──────────────────────────────────────────────
# 2. 楽天商品検索API 呼び出し
# ──────────────────────────────────────────────
Write-Host "🔍 楽天市場で「$Keyword」を検索中..." -ForegroundColor Cyan

$apiUrl = "https://app.rakuten.co.jp/services/api/IchibaItem/Search/20220601"
$params = @{
    applicationId = $appId
    affiliateId   = $affiliateId
    keyword       = $Keyword
    hits          = $Hits
    sort          = $Sort
    formatVersion = 2
    imageFlag     = 1
}

# クエリ文字列を組み立て
$query = ($params.GetEnumerator() | ForEach-Object {
    "$($_.Key)=$([System.Uri]::EscapeDataString($_.Value))"
}) -join "&"

$requestUrl = "$apiUrl`?$query"

try {
    $response = Invoke-RestMethod -Uri $requestUrl -Method Get -ErrorAction Stop
} catch {
    Write-Host "❌ API呼び出しに失敗しました: $_" -ForegroundColor Red
    exit 1
}

$items = $response.Items
if (-not $items -or $items.Count -eq 0) {
    Write-Host "❌ 「$Keyword」の検索結果が0件でした。キーワードを変えてみてください。" -ForegroundColor Red
    exit 1
}

Write-Host "✅ $($items.Count)件の商品情報を取得しました。" -ForegroundColor Green

# ──────────────────────────────────────────────
# 3. 商品情報を整理
# ──────────────────────────────────────────────
$products = @()
$rank = 0
foreach ($item in $items) {
    $rank++
    # 画像URLを取得（複数ある場合は最初の1枚）
    $imageUrl = ""
    if ($item.mediumImageUrls -and $item.mediumImageUrls.Count -gt 0) {
        $imageUrl = $item.mediumImageUrls[0]
        if ($imageUrl -is [PSCustomObject]) {
            $imageUrl = $imageUrl.imageUrl
        }
    }

    # アフィリエイトURL（APIが生成してくれる）
    $affiliateUrl = $item.affiliateUrl
    if (-not $affiliateUrl) {
        $affiliateUrl = $item.itemUrl
    }

    # 価格をフォーマット（カンマ区切り）
    $price = $item.itemPrice
    $priceFormatted = "{0:N0}" -f [int]$price

    $products += [PSCustomObject]@{
        Rank         = $rank
        Name         = $item.itemName
        Price        = $priceFormatted
        Url          = $affiliateUrl
        ImageUrl     = $imageUrl
        ShopName     = $item.shopName
        ReviewCount  = $item.reviewCount
        ReviewAvg    = $item.reviewAverage
    }

    Write-Host ("  #{0} {1} - ¥{2}" -f $rank, $item.itemName.Substring(0, [Math]::Min(40, $item.itemName.Length)), $priceFormatted) -ForegroundColor White
}

# ──────────────────────────────────────────────
# 4. ファイル名とパスを決定
# ──────────────────────────────────────────────
$date = Get-Date -Format "yyyy-MM-dd"
$dateISO = Get-Date -Format "yyyy-MM-ddTHH:mm:ss+09:00"

# キーワードをファイル名用にスラッグ化（日本語はそのまま使用）
$slug = $Keyword -replace '\s+', '-' -replace '[\\/:*?"<>|]', ''
$fileName = "$date-$slug.md"
$filePath = Join-Path $PSScriptRoot "..\content\posts\$fileName"
$filePath = [System.IO.Path]::GetFullPath($filePath)

if (Test-Path $filePath) {
    Write-Host "⚠️ ファイルが既に存在します: $fileName" -ForegroundColor Yellow
    $overwrite = Read-Host "上書きしますか？ (y/N)"
    if ($overwrite -ne "y") {
        Write-Host "中止しました。"
        exit 0
    }
}

# ──────────────────────────────────────────────
# 5. Markdown ファイルを生成
# ──────────────────────────────────────────────
$rankEmoji = @("🥇", "🥈", "🥉", "4️⃣", "5️⃣")

# ショートコード部分を生成
$productSections = ""
foreach ($p in $products) {
    $emoji = $rankEmoji[$p.Rank - 1]
    $productSections += @"

### $emoji 第$($p.Rank)位：$($p.Name)

<!-- TODO: Copilot で以下のおすすめポイントを生成してください -->
**おすすめポイント：**
- ✅ （ポイント1を記入）
- ✅ （ポイント2を記入）
- ✅ （ポイント3を記入）

{{< rakuten title="$($p.Name)" url="$($p.Url)" img="$($p.ImageUrl)" price="$($p.Price)" keyword="$Keyword" >}}

---
"@
}

# 比較表を生成
$comparisonHeader = @"

## 比較表

| 順位 | 商品名 | 価格 | レビュー件数 | レビュー評価 |
|:----:|--------|-----:|:------------:|:------------:|
"@

$comparisonRows = ""
foreach ($p in $products) {
    $emoji = $rankEmoji[$p.Rank - 1]
    $nameShort = $p.Name
    if ($nameShort.Length -gt 30) {
        $nameShort = $nameShort.Substring(0, 30) + "…"
    }
    $comparisonRows += "| $emoji | $nameShort | ¥$($p.Price) | $($p.ReviewCount)件 | ★$($p.ReviewAvg) |`n"
}

$markdown = @"
---
title: "【$(Get-Date -Format 'yyyy')年版】おすすめの${Keyword}ランキング｜人気${Hits}選を徹底比較"
date: $dateISO
draft: true
categories: ["レビュー"]
tags: ["$Keyword", "おすすめ", "ランキング", "比較"]
description: "${Keyword}のおすすめ商品を徹底比較！人気${Hits}選をランキング形式でご紹介します。"
cover:
  image: ""
  alt: "${Keyword}おすすめ"
  hidden: false
ShowToc: true
TocOpen: true
---

## はじめに

<!-- TODO: Copilot で導入文を生成してください。prompts/review-template.md のテンプレートを使用 -->

（ここに導入文を記入：なぜこの商品カテゴリが注目されているか、どんな人に読んでほしいか）

---

## ${Keyword}を選ぶポイント

<!-- TODO: Copilot で選び方のポイントを3つ生成してください -->

### 1. （選ぶポイント1）

（説明を記入）

### 2. （選ぶポイント2）

（説明を記入）

### 3. （選ぶポイント3）

（説明を記入）

---

## おすすめ${Keyword}ランキング TOP${Hits}

> 💡 **この記事では楽天市場の商品情報を元にご紹介しています。**
> 価格や在庫状況は変動する場合があります。最新情報は各リンク先をご確認ください。
$productSections
$comparisonHeader
$comparisonRows
---

## まとめ

<!-- TODO: Copilot でまとめを生成してください -->

（ここにまとめを記入：どんな人にどの商品がおすすめか、最終的なアドバイス）

---

> 📝 **この記事は楽天市場の商品情報を元に作成しています。**
> 価格・レビュー件数・レビュー評価は記事作成時点のものです。
> 最新の情報は各商品リンクからご確認ください。
"@

# UTF-8 BOM なしで書き出し
[System.IO.File]::WriteAllText($filePath, $markdown, [System.Text.UTF8Encoding]::new($false))

Write-Host ""
Write-Host "📝 記事ファイルを生成しました！" -ForegroundColor Green
Write-Host "   $filePath" -ForegroundColor White
Write-Host ""
Write-Host "📋 次のステップ：" -ForegroundColor Yellow
Write-Host "   1. VS Code でファイルが開きます"
Write-Host "   2. <!-- TODO --> のコメント部分を Copilot Chat で埋めてください"
Write-Host "   3. プロンプトは prompts/review-template.md を参考にしてください"
Write-Host "   4. draft: true → draft: false に変更すると公開されます"
Write-Host "   5. Ctrl+S で保存すると自動で git push → デプロイされます"
Write-Host ""

# VS Code で開く
code $filePath
