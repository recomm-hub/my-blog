<#
.SYNOPSIS
    楽天商品検索API を呼び出し、Hugo 記事の Markdown ファイルを自動生成するスクリプト。

.DESCRIPTION
    指定したキーワードで楽天市場を検索し、上位3商品の情報を取得。
    Hugo の front matter + shop-card ショートコード入りの Markdown ファイルを生成し、
    VS Code で自動的に開きます。
    -Style パラメータで記事の構成パターンを切り替えられます。

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

.PARAMETER Style
    記事の構成パターン（デフォルト: A）
    A: ランキング型（家電・ガジェット向け）
    B: 悩み解決型（健康・美容向け）
    C: 比較レビュー型（ガチ比較向け）
    D: シーン別提案型（趣味・ライフスタイル向け）
    E: 体験レポート型（日用品・食品向け）

.PARAMETER Slug
    URL用の英語スラッグ（例: "robot-vacuum", "air-purifier"）
    年号は含めない。半角英数字とハイフンのみ。

.EXAMPLE
    .\scripts\post.ps1 "空気清浄機" -Slug "air-purifier"
    .\scripts\post.ps1 "ロボット掃除機" -Hits 5 -Slug "robot-vacuum"
    .\scripts\post.ps1 "ワイヤレスイヤホン" -Sort "-reviewAverage" -Slug "wireless-earbuds"
    .\scripts\post.ps1 "花粉症対策グッズ" -Style B -Slug "hay-fever-goods"
    .\scripts\post.ps1 "ゲーミングチェア" -Style C -Slug "gaming-chair"
#>

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Keyword,

    [Parameter()]
    [ValidateRange(1, 5)]
    [int]$Hits = 3,

    [Parameter()]
    [string]$Sort = "-reviewCount",

    [Parameter()]
    [ValidateSet("A", "B", "C", "D", "E")]
    [string]$Style = "A",

    [Parameter(Mandatory=$true)]
    [ValidatePattern('^[a-z0-9]+(-[a-z0-9]+)*$')]
    [string]$Slug
)

# ──────────────────────────────────────────────
# 0. 計測ID定義ファイル読み込み
# ──────────────────────────────────────────────
$trackingIdFile = Join-Path $PSScriptRoot "..\data\tracking_ids.yaml"
$trackingIdFile = [System.IO.Path]::GetFullPath($trackingIdFile)
$trackingIds = @()

if (Test-Path $trackingIdFile) {
    $lines = Get-Content $trackingIdFile -Encoding UTF8
    $currentId = $null
    $currentKeywords = @()
    foreach ($line in $lines) {
        if ($line -match '^\s+- id:\s*(.+)$') {
            if ($currentId) {
                $trackingIds += [PSCustomObject]@{ Id = $currentId; Keywords = $currentKeywords }
            }
            $currentId = $Matches[1].Trim()
            $currentKeywords = @()
        }
        elseif ($currentId -and $line -match '^\s+- "(.+)"$') {
            $currentKeywords += $Matches[1]
        }
        elseif ($currentId -and $line -match '^\s+- id:') {
            # next entry ─ handled above
        }
    }
    if ($currentId) {
        $trackingIds += [PSCustomObject]@{ Id = $currentId; Keywords = $currentKeywords }
    }
}

function Get-TrackingId {
    param([string]$Keyword)
    foreach ($entry in $trackingIds) {
        foreach ($kw in $entry.Keywords) {
            if ($Keyword -match [regex]::Escape($kw)) {
                return $entry.Id
            }
        }
    }
    # マッチしない場合は警告を出して null を返す
    Write-Host "⚠️ 計測IDが見つかりませんでした。キーワード: $Keyword" -ForegroundColor Yellow
    Write-Host "  → data/tracking_ids.yaml に新しいIDを追加し、楽天管理画面でも登録してください" -ForegroundColor Yellow
    Write-Host "    https://affiliate.rakuten.co.jp/user/sites" -ForegroundColor Cyan
    return $null
}

# キーワードから計測IDを判定
$trackingId = Get-TrackingId -Keyword $Keyword
if ($trackingId) {
    Write-Host "🎯 計測ID: $trackingId" -ForegroundColor Green
}

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

# 商品名クリーニング関数（楽天APIのSEOスパム・販促文を除去）
function Clean-ProductName {
    param([string]$RawName)
    $n = $RawName

    # ── 括弧で囲まれた販促テキストを除去 ──
    $n = $n -replace '【[^】]*】', ''          # 【クーポンで割引...】
    $n = $n -replace '\[[^\]]*\]', ''          # [お買い物マラソン! ...]
    $n = $n -replace '《[^》]*》', ''          # 《4年連続 最も売れた...》
    $n = $n -replace '＼[^／]*／', ''          # ＼81%OFF＆P2倍で...／
    $n = $n -replace '｛[^｝]*｝', ''          # ｛...｝

    # ── よくある販促フレーズを除去 ──
    $n = $n -replace '送料無料', ''
    $n = $n -replace '楽天ランキング\d*位', ''
    $n = $n -replace '楽天\d*位[受賞!！]*', ''
    $n = $n -replace '\d+年間?MVP', ''
    $n = $n -replace '\d+%OFF', ''
    $n = $n -replace '\d+,?\d*円OFF\S*', ''
    $n = $n -replace 'P\d+倍', ''
    $n = $n -replace 'ポイント\d*倍\S*', ''
    $n = $n -replace 'クーポン\S*', ''
    $n = $n -replace '特価セット', ''
    $n = $n -replace '新色追加[!！]*', ''
    $n = $n -replace 'お買い物マラソン\S*', ''
    $n = $n -replace 'スーパーSALE\S*', ''
    $n = $n -replace 'メール便', ''
    $n = $n -replace '＋おまけ', ''
    $n = $n -replace '母の日', ''
    $n = $n -replace '父の日', ''
    $n = $n -replace '引っ越し祝い', ''
    $n = $n -replace 'メーカー\d+年保証', ''
    $n = $n -replace 'PSE認証済み', ''
    $n = $n -replace 'PL保険[^\s]*', ''
    $n = $n -replace 'ポスト投函', ''
    $n = $n -replace '選べる特典', ''
    $n = $n -replace '\d+/\d+[〜\-~]+\d+/\d+', ''  # 日付範囲 2/14〜2/23
    $n = $n -replace '\d+:\d+[-~]\d+:\d+', ''       # 時間範囲

    # ── 整形 ──
    $n = $n -replace '[＆&]+', ' '
    $n = $n -replace '[\\／]+', ' '
    $n = $n -replace '\s+', ' '
    $n = $n.Trim(' 　・＋+!！/・※')

    # ── 長すぎる場合はスペース区切りで50文字以内に切り詰め ──
    if ($n.Length -gt 50) {
        $parts = $n -split '\s+'
        $result = ""
        foreach ($part in $parts) {
            $candidate = if ($result) { "$result $part" } else { $part }
            if ($candidate.Length -gt 50) { break }
            $result = $candidate
        }
        if ($result) { $n = $result }
    }

    return $n
}

# 商品ページを解析してブランド名・型番を取得する関数
function Get-ProductBrandModel {
    param(
        [string]$ItemUrl,
        [string]$ShopName
    )

    $brand = ""
    $model = ""

    try {
        $html = (Invoke-WebRequest -Uri $ItemUrl -UseBasicParsing -TimeoutSec 20).Content

        # ── Strategy 1: 楽天ページ内の itemNumber (最も信頼できる型番) ──
        if ($html -match '"itemNumber"\s*:\s*"([^"]+)"') {
            $model = $matches[1].Trim()
        }

        # ── Strategy 2: 画像 alt テキストからブランド+型番パターンを抽出 ──
        # 楽天の画像altには「BRANDMODELカラー」の形式が多い
        if (-not $brand) {
            $altMatches = [regex]::Matches($html, '"alt"\s*:\s*"[^"]*?([A-Z][A-Za-z]{2,15})[\s]?(' + [regex]::Escape($model) + ')[^"]*"')
            if ($altMatches.Count -gt 0) {
                $brand = $altMatches[0].Groups[1].Value
            }
        }

        # ── Strategy 3: title タグ末尾のショップ名からブランドを推定 ──
        if (-not $brand -and $html -match '<title>[^<]+[：:]([^<]+)</title>') {
            $shopDisplayName = $matches[1].Trim()
            # 「○○楽天市場店」「○○公式 ストア」等からブランド部分を抽出
            $brandCandidate = $shopDisplayName -replace '楽天市場店$', '' -replace '楽天店$', '' -replace '公式\s*ストア$', '' -replace '公式店$', '' -replace 'ストア$', '' -replace '直営店$', '' -replace 'ショップ$', '' -replace 'SHOP$', '' -replace 'shop$', ''
            $brandCandidate = $brandCandidate.Trim()
            if ($brandCandidate.Length -ge 2 -and $brandCandidate.Length -le 25) {
                $brand = $brandCandidate
            }
        }

        # ── Strategy 4: URL ショップコードからブランドを推定（最後の手段）──
        if (-not $brand -and $ItemUrl -match 'item\.rakuten\.co\.jp/([^/]+)/') {
            $shopCode = $matches[1]
            # store- プレフィックスを除去、ハイフンをスペースに
            $brandCandidate = $shopCode -replace '^store-', '' -replace '-japan$', '' -replace '-official$', ''
            # 英字ブランド名っぽければ採用（全小文字→先頭大文字に）
            if ($brandCandidate -match '^[a-z]{2,15}$') {
                $brand = (Get-Culture).TextInfo.ToTitleCase($brandCandidate)
            }
        }

    } catch {
        Write-Host "    ⚠️ 商品ページ解析スキップ: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    return @{ Brand = $brand; Model = $model }
}

# ブランド・型番をクリーニング済み名前に統合する関数
function Build-DisplayName {
    param(
        [string]$CleanName,
        [string]$Brand,
        [string]$Model,
        [string]$RawName
    )

    $display = $CleanName

    # ── CleanName 内に既にブランド名が含まれているかチェック ──
    # （例: "ECOVACS DEEBOT N20 PRO PLUS ロボット掃除機" → ECOVACS 含む → スキップ）
    $hasBrand = $false
    if ($Brand) {
        # ブランド名の英字部分で比較（「エコバックスジャパン」と「ECOVACS」両方チェック）
        $brandAlpha = $Brand -replace '[^A-Za-z]', ''
        if ($brandAlpha.Length -ge 3 -and $display -match "(?i)$([regex]::Escape($brandAlpha))") {
            $hasBrand = $true
        } elseif ($display -match [regex]::Escape($Brand)) {
            $hasBrand = $true
        }
        # カタカナ部分でも照合（「エコバックスジャパン」→「エコバックス」が本文にあればOK）
        if (-not $hasBrand) {
            $brandKatakana = [regex]::Match($Brand, '[\u30A0-\u30FF]{2,}').Value
            if ($brandKatakana -and $display -match [regex]::Escape($brandKatakana)) {
                $hasBrand = $true
            }
        }
        # RawName 内の英字ブランド名が CleanName に含まれているかもチェック
        if (-not $hasBrand) {
            $rawBrands = [regex]::Matches($RawName, '\b([A-Z][a-z]*[A-Z]+[a-z]*|[A-Z]{2,15})\b')
            foreach ($rb in $rawBrands) {
                if ($rb.Value -notmatch '^(WiFi|LED|USB|Type|OFF|PRO|PLUS|MAX|MINI|TWS|AAC|ENC|HiFi|IPX\d|UV|PU|PC)$' -and $rb.Value.Length -ge 3) {
                    if ($display -match "(?i)$([regex]::Escape($rb.Value))") {
                        $hasBrand = $true
                        break
                    }
                }
            }
        }
    }

    # ── CleanName 内に型番（マーケティング名）が含まれているかチェック ──
    # APIの itemName に型番が入っている場合はそちらを優先
    $hasModel = $false
    if ($Model) {
        if ($display -match [regex]::Escape($Model)) {
            $hasModel = $true
        }
    }

    # ── RawName からマーケティング型番を抽出（itemNumber と異なる場合がある）──
    # 例: RawName に "DEEBOT N20 PRO PLUS" が含まれるが、itemNumber は "DKX55-12EE"
    $marketingModel = ""
    if ($RawName -match '([A-Z][A-Za-z]*[\s\-]?[A-Z]?\d{1,4}(?:[\s\-]?(?:PRO|PLUS|MAX|MINI|LITE|SE|AIR|NEO|ULTRA|EX|S|X|i)+)*)') {
        $candidate = $matches[1].Trim()
        if ($candidate.Length -ge 3 -and $candidate -ne $Model) {
            $marketingModel = $candidate
        }
    }

    # ── ブランドが含まれていなければ先頭に追加 ──
    if (-not $hasBrand -and $Brand) {
        # ブランド名が長すぎる場合（「エコバックスジャパン」等）は英字版を探す
        $brandToUse = $Brand
        if ($Brand.Length -gt 12 -and $RawName -match '([A-Z][A-Za-z]{2,15})') {
            # RawName から英字ブランド候補を探す
            $candidates = [regex]::Matches($RawName, '\b([A-Z][a-z]*[A-Z]+[a-z]*|[A-Z]{2,15})\b')
            foreach ($c in $candidates) {
                $cv = $c.Value
                # 一般的な英単語は除外
                if ($cv -notmatch '^(WiFi|LED|USB|Type|OFF|PRO|PLUS|MAX|MINI|TWS|AAC|ENC|HiFi|IPX\d|UV|PU|PC)$' -and $cv.Length -ge 3) {
                    $brandToUse = $cv
                    break
                }
            }
        }
        $display = "$brandToUse $display"
    }

    # ── 型番が含まれていなければ追加（マーケティング名優先、なければ itemNumber）──
    if (-not $hasModel) {
        $modelToAdd = if ($marketingModel) { $marketingModel } else { $Model }
        if ($modelToAdd -and $display -notmatch [regex]::Escape($modelToAdd)) {
            # ブランド名の直後に型番を挿入
            if ($Brand -and $display -match [regex]::Escape($Brand)) {
                # 内部管理番号っぽい型番（数字だらけ）はスキップ
                if ($modelToAdd -notmatch '^\d{4,}') {
                    $display = $display -replace ([regex]::Escape($Brand)), "$Brand $modelToAdd"
                }
            } else {
                if ($modelToAdd -notmatch '^\d{4,}') {
                    $display = "$modelToAdd $display"
                }
            }
        }
    }

    # 最終整形（重複スペース除去、60文字制限）
    $display = ($display -replace '\s+', ' ').Trim()
    if ($display.Length -gt 60) {
        $parts = $display -split '\s+'
        $result = ""
        foreach ($part in $parts) {
            $candidate = if ($result) { "$result $part" } else { $part }
            if ($candidate.Length -gt 60) { break }
            $result = $candidate
        }
        if ($result) { $display = $result }
    }

    return $display
}

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
        # Rakuten thumbnail CDNの画像を拡大（128x128 → 256x256）
        $imageUrl = $imageUrl -replace '_ex=128x128', '_ex=256x256'
    }

    # アフィリエイトURL（APIが生成してくれる）
    $affiliateUrl = $item.affiliateUrl
    if (-not $affiliateUrl) {
        $affiliateUrl = $item.itemUrl
    }
    # 計測IDをアフィリエイトURLに付与（scid パラメータ）
    if ($trackingId -and $affiliateUrl) {
        $separator = if ($affiliateUrl -match '\?') { '&' } else { '?' }
        $affiliateUrl = "${affiliateUrl}${separator}scid=${trackingId}"
    }

    # 価格をフォーマット（カンマ区切り）
    $price = $item.itemPrice
    $priceFormatted = "{0:N0}" -f [int]$price

    # 商品ページを解析してブランド名・型番を取得
    Write-Host ("  #{0} 商品ページを解析中..." -f $rank) -ForegroundColor DarkGray
    $brandModel = Get-ProductBrandModel -ItemUrl $item.itemUrl -ShopName $item.shopName
    $cleanName = Clean-ProductName $item.itemName
    $displayName = Build-DisplayName -CleanName $cleanName -Brand $brandModel.Brand -Model $brandModel.Model -RawName $item.itemName

    $products += [PSCustomObject]@{
        Rank         = $rank
        Name         = $item.itemName
        CleanName    = $displayName
        Price        = $priceFormatted
        Url          = $affiliateUrl
        ImageUrl     = $imageUrl
        ShopName     = $item.shopName
        Brand        = $brandModel.Brand
        Model        = $brandModel.Model
        ReviewCount  = $item.reviewCount
        ReviewAvg    = $item.reviewAverage
    }

    $brandInfo = ""
    if ($brandModel.Brand) { $brandInfo += " [Brand: $($brandModel.Brand)]" }
    if ($brandModel.Model) { $brandInfo += " [Model: $($brandModel.Model)]" }
    Write-Host ("  #{0} {1} - ¥{2}{3}" -f $rank, $displayName, $priceFormatted, $brandInfo) -ForegroundColor White
}

# ──────────────────────────────────────────────
# 4. ファイル名とパスを決定
# ──────────────────────────────────────────────
$date = Get-Date -Format "yyyy-MM-dd"
$dateISO = Get-Date -Format "yyyy-MM-ddTHH:mm:ss+09:00"

# キーワードをファイル名用にスラッグ化（日本語はそのまま使用）
$slug = $Keyword -replace '\s+', '-' -replace '[\\/:*?"<>|]', ''
$bundleName = "$date-$slug"
$bundleDir = Join-Path $PSScriptRoot "..\content\posts\$bundleName"
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
# 5. Markdown ファイルを生成（スタイル別）
# ──────────────────────────────────────────────
$rankEmoji = @("🥇", "🥈", "🥉", "4️⃣", "5️⃣")

# スタイル名マップ
$styleNames = @{
    "A" = "ランキング型"
    "B" = "悩み解決型"
    "C" = "比較レビュー型"
    "D" = "シーン別提案型"
    "E" = "体験レポート型"
}
$styleName = $styleNames[$Style]

Write-Host "📐 スタイル: $Style ($styleName)" -ForegroundColor Magenta

# 共通: ショートコード部分を生成（スタイルに応じてTODOコメントを変更）
$productSections = ""
foreach ($p in $products) {
    $emoji = $rankEmoji[$p.Rank - 1]
    # 商品名の中の " を全角に変換（Hugo ショートコードのパース対策）
    $safeName = $p.CleanName -replace '"', '＂' -replace '"', '＂' -replace '"', '＂'

    switch ($Style) {
        "A" {
            $productSections += @"

### $emoji 第$($p.Rank)位：$($p.CleanName)

<!-- TODO: prompts/style-A-ranking.md の指示に従って執筆 -->
**おすすめポイント：**
- ✅ （ポイント1）
- ✅ （ポイント2）
- ✅ （ポイント3）
- ⚠️ （気になる点1つ）

**向いてる人：** （1行で記入）
**向いてない人：** （1行で記入）

{{< shop-card title="$safeName" url="$($p.Url)" img="$($p.ImageUrl)" price="$($p.Price)" keyword="$Keyword" >}}

---
"@
        }
        "B" {
            $productSections += @"

### おすすめ$($p.Rank)：$($p.CleanName)

<!-- TODO: prompts/style-B-solution.md の指示に従って執筆 -->
（この商品を使っているシーンや体験を文章で書く。箇条書きだけにしない。
 「〜な場面で使ってる」「〜が地味に助かってる」的なトーンで）

{{< shop-card title="$safeName" url="$($p.Url)" img="$($p.ImageUrl)" price="$($p.Price)" keyword="$Keyword" >}}

※あくまで個人の感想です。合う合わないは人によります。

---
"@
        }
        "C" {
            $productSections += @"

### $($p.CleanName)

<!-- TODO: prompts/style-C-comparison.md の指示に従って執筆 -->
**良い点：**
- （具体的に。スペックだけでなく使用感も）
- （カタログに書いてないリアルな良さ）

**気になる点：**
- （正直に。「値段の割に〜」「〜は物足りない」）

**使用シーン：** （「朝の通勤で〜」「デスクに置くと〜」的な具体描写）

{{< shop-card title="$safeName" url="$($p.Url)" img="$($p.ImageUrl)" price="$($p.Price)" keyword="$Keyword" >}}

---
"@
        }
        "D" {
            $sceneName = switch ($p.Rank) {
                1 { "はじめて買う人" }
                2 { "毎日ガッツリ使う人" }
                3 { "プレゼント・ギフト用" }
                default { "その他" }
            }
            $productSections += @"

### 📌 $sceneName には → $($p.CleanName)

<!-- TODO: prompts/style-D-scene.md の指示に従って執筆 -->
（「これは〜な人向け」から始めて、文章メインで紹介。
 良い点を文章で語った後、活用Tipsを1つ入れる。
 「こんな人には合わないかも」も正直に）

{{< shop-card title="$safeName" url="$($p.Url)" img="$($p.ImageUrl)" price="$($p.Price)" keyword="$Keyword" >}}

---
"@
        }
        "E" {
            $timingLabel = switch ($p.Rank) {
                1 { "最初に試したのがこれ" }
                2 { "次に手を出したのがこれ" }
                3 { "最後に見つけたのがこれ" }
                default { "追加で試したやつ" }
            }
            $productSections += @"

### $timingLabel：$($p.CleanName)

<!-- TODO: prompts/style-E-experience.md の指示に従って執筆 -->
（時系列で書く: 開封→第一印象→使ってみて→今どう思ってるか。
 感覚的な表現を多めに。全商品同じ密度にしないこと）

{{< shop-card title="$safeName" url="$($p.Url)" img="$($p.ImageUrl)" price="$($p.Price)" keyword="$Keyword" >}}

---
"@
        }
    }
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
    # 商品名にアフィリエイトリンクを付与（比較表からも楽天に遷移できるようにする）
    $linkedName = "[$($p.CleanName)]($($p.Url))"
    $comparisonRows += "| $emoji | $linkedName | ¥$($p.Price) | $($p.ReviewCount)件 | ★$($p.ReviewAvg) |`n"
}

# スタイル別のタイトル・構成を生成
$titleMap = @{
    "A" = "【$(Get-Date -Format 'yyyy')年版】おすすめの${Keyword}ランキング｜人気${Hits}選を徹底比較"
    "B" = "${Keyword}で悩んでない？｜実際に試したおすすめ${Hits}選"
    "C" = "【徹底比較】${Keyword}おすすめ${Hits}選、結局どれがいい？"
    "D" = "【目的別に選ぶ】${Keyword}のおすすめ${Hits}選ガイド"
    "E" = "${Keyword}を買ってみた｜${Hits}つ使い比べた正直レビュー"
}
$articleTitle = $titleMap[$Style]

# スタイル別カテゴリマッピング
# まとめ: 商品選定・比較・悩み解決ガイド (A, B, C, D)
# レビュー: 実体験ベースの使用感 (E)
# 解説: 知識・ハウツー (F ※ knowledge.ps1 で管理)
$categoryMap = @{
    "A" = "まとめ"
    "B" = "まとめ"
    "C" = "まとめ"
    "D" = "まとめ"
    "E" = "レビュー"
}
$category = $categoryMap[$Style]

# スタイル別の本文テンプレート
switch ($Style) {
    "A" {
$markdown = @"
---
title: "$articleTitle"
slug: "$Slug"
date: $dateISO
draft: true
categories: ["$category"]
tags: ["$Keyword", "おすすめ", "ランキング", "比較"]
description: "${Keyword}のおすすめ商品を徹底比較！人気${Hits}選をランキング形式でご紹介します。"
style: "A"
image: cover.jpg
ShowToc: true
TocOpen: true
---

## はじめに

<!-- TODO: prompts/style-A-ranking.md Step 1 の指示で執筆 → Step 2 でレビュー -->

（「〜で困ってませんか？」「〜って迷いますよね」で始める。自分がこのジャンルに詳しい理由を1文。）

---

## ${Keyword}を選ぶポイント

### 1. （疑問形 or 断言形の見出し）

（説明。「失敗しがちなパターン」を1つは入れる）

### 2. （前と違う形式の見出し）

（説明）

### 3. （前と違う形式の見出し）

（説明）

---

## おすすめ${Keyword}ランキング TOP${Hits}

> 💡 価格や在庫は変動します。最新情報はリンク先でご確認ください。
$productSections
$comparisonHeader
$comparisonRows
---

## まとめ

<!-- TODO: 「迷ったらこれ買っとけ」的なカジュアルな結論。最後は個人的な感想で。 -->

---

> 📝 この記事は楽天市場の商品情報を元に作成しています。価格・レビュー件数は記事作成時点のものです。
"@
    }
    "B" {
$markdown = @"
---
title: "$articleTitle"
slug: "$Slug"
date: $dateISO
draft: true
categories: ["$category"]
tags: ["$Keyword", "悩み解決", "対策", "おすすめ"]
description: "${Keyword}で悩んでいる方へ。実際に試したおすすめアイテムと対策法を紹介します。"
style: "B"
image: cover.jpg
ShowToc: true
TocOpen: true
---

## ${Keyword}、つらいですよね

<!-- TODO: prompts/style-B-solution.md Step 1 の指示で執筆 → Step 2 でレビュー -->

（自分も悩んでたエピソードから。「いつ頃から」「ネットで調べても情報多すぎて…」）

---

## そもそもなぜ？原因をざっくり解説

（専門的になりすぎない。「ざっくり言うと〜」「原因がわかると対策しやすい」）

---

## 自分が試した3つのアプローチ

### 1. （お金をかけずにできること）

（具体的な行動レベルで）

### 2. （少し投資して改善）

（体感を交えて）

### 3. （グッズに頼る）

（「最終的にこれに落ち着いた」的な流れで商品紹介へ橋渡し）

---

## 実際に使ってるアイテム${Hits}選
$productSections
$comparisonHeader
$comparisonRows
---

## 自分の場合はこうなった

<!-- TODO: 体験談風。「劇的に！」ではなく「地味に良くなった」「気づいたら楽に…」 -->
<!-- 最後は「参考になれば嬉しいです」的にカジュアルに -->

---

> 📝 この記事は楽天市場の商品情報を元に作成しています。価格・レビュー件数は記事作成時点のものです。
> ※ 効果には個人差があります。
"@
    }
    "C" {
$markdown = @"
---
title: "$articleTitle"
slug: "$Slug"
date: $dateISO
draft: true
categories: ["$category"]
tags: ["$Keyword", "比較", "レビュー", "どっちがいい"]
description: "${Keyword}の人気${Hits}モデルをガチ比較。結局どれがいいのか、使った感想とともに解説。"
style: "C"
image: cover.jpg
ShowToc: true
TocOpen: true
---

## 先に結論

<!-- TODO: prompts/style-C-comparison.md Step 1 の指示で執筆 → Step 2 でレビュー -->

（「時間がない人向けに」3商品×1行ずつ「こんな人 → これ」）

---

## 各モデルの正直レビュー
$productSections

## 直接対決：表には出ない違い
$comparisonHeader
$comparisonRows

<!-- TODO: 「〇〇 vs △△」形式で、表だけじゃわからないリアルな差を文章で -->

---

## 結局どれがいい？

<!-- TODO: 冒頭の結論を深掘り。「ぶっちゃけ一番使ってるのは…」 -->
<!-- 価格変動の可能性に触れて締める -->

---

> 📝 この記事は楽天市場の商品情報を元に作成しています。価格・レビュー件数は記事作成時点のものです。
"@
    }
    "D" {
$markdown = @"
---
title: "$articleTitle"
slug: "$Slug"
date: $dateISO
draft: true
categories: ["$category"]
tags: ["$Keyword", "目的別", "初心者", "おすすめ"]
description: "${Keyword}を目的・シーン別に選ぶガイド。初心者からヘビーユーザーまで。"
style: "D"
image: cover.jpg
ShowToc: true
TocOpen: true
---

## ${Keyword}って何？ざっくり解説

<!-- TODO: prompts/style-D-scene.md Step 1 の指示で執筆 → Step 2 でレビュー -->

（堅い定義ではなく「要するに〜」で。「最近〜で話題」「〜な人が増えてる」）

---

## あなたに合うのはどれ？シーン別ガイド

| こんな人 | おすすめ |
|:---|:---|
| はじめて買う人 | → 第1位の商品名 |
| 毎日ガッツリ使う人 | → 第2位の商品名 |
| プレゼント用に探してる | → 第3位の商品名 |

---
$productSections
$comparisonHeader
$comparisonRows

---

## よくある質問

### Q: （よくある疑問1）
（あっさり2-3行で回答）

### Q: （よくある疑問2）
（あっさり2-3行で回答）

---

## まとめ

<!-- TODO: 「とりあえず迷ったら〜から始めてみて」の気軽さで -->

---

> 📝 この記事は楽天市場の商品情報を元に作成しています。価格・レビュー件数は記事作成時点のものです。
"@
    }
    "E" {
$markdown = @"
---
title: "$articleTitle"
slug: "$Slug"
date: $dateISO
draft: true
categories: ["$category"]
tags: ["$Keyword", "買ってみた", "レビュー", "正直"]
description: "${Keyword}を${Hits}つ買って使い比べてみた正直な感想。良かった点・微妙だった点を包み隠さず。"
style: "E"
image: cover.jpg
ShowToc: true
TocOpen: true
---

## 買ったきっかけ

<!-- TODO: prompts/style-E-experience.md Step 1 の指示で執筆 → Step 2 でレビュー -->

（「前から気になってた」or「衝動買いした」的なリアルな動機。いきなり商品紹介に入らない）

---

## 使い比べてみた
$productSections

## ぶっちゃけどうだった？
$comparisonHeader
$comparisonRows

<!-- TODO: 表ではなく文章で「良かった → でもここが…」の流れ。「値段分の価値あったか？」に答える -->

---

## こんな人に向いてる / 向いてない

（2-3行でサクッと。ダラダラ書かない）

---

## 最後にひとこと

<!-- TODO: 「また買うか？」に一言で。余韻を残す終わり方 -->

---

> 📝 この記事は楽天市場の商品情報を元に作成しています。価格・レビュー件数は記事作成時点のものです。
> ※ あくまで個人の感想です。
"@
    }
}

# ──────────────────────────────────────────────
# エビデンス用スナップショットを保存（ファクトチェック用）
# ──────────────────────────────────────────────
$snapshotPath = Join-Path $bundleDir "_snapshot.json"
$snapshotProducts = $products | ForEach-Object {
    [ordered]@{
        rank          = $_.Rank
        cleanName     = $_.CleanName
        rawName       = $_.Name
        shopName      = $_.ShopName
        price         = $_.Price
        reviewCount   = $_.ReviewCount
        reviewAverage = $_.ReviewAvg
        itemUrl       = ($_.Url -replace '\?scid=.*$', '')  # 計測IDを除いた素のURL
        imageUrl      = $_.ImageUrl
    }
}
$snapshot = [ordered]@{
    generatedAt = $dateISO
    keyword     = $Keyword
    slug        = $Slug
    style       = $Style
    sort        = $Sort
    products    = @($snapshotProducts)
}
$snapshotJson = $snapshot | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText($snapshotPath, $snapshotJson, [System.Text.UTF8Encoding]::new($false))
Write-Host "📸 エビデンス保存: _snapshot.json" -ForegroundColor DarkGray

# UTF-8 BOM なしで書き出し
[System.IO.File]::WriteAllText($filePath, $markdown, [System.Text.UTF8Encoding]::new($false))

Write-Host ""
Write-Host "📝 記事ファイルを生成しました！" -ForegroundColor Green
Write-Host "   $filePath" -ForegroundColor White
Write-Host "   スタイル: $Style ($styleName)" -ForegroundColor Magenta
Write-Host ""

# カバー画像を自動生成
Write-Host "🖼️ カバー画像を生成中..." -ForegroundColor Cyan
$coverScript = Join-Path $PSScriptRoot "generate-covers.ps1"
if (Test-Path $coverScript) {
    $bundleRelPath = "content\posts\$bundleName"
    & $coverScript -PostPath $bundleRelPath -Force
}
else {
    Write-Host "   ⚠️ generate-covers.ps1 が見つかりません。手動で実行してください。" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "📋 次のステップ：" -ForegroundColor Yellow
Write-Host "   1. VS Code でファイルが開きます"
Write-Host "   2. prompts/style-$Style-*.md のプロンプトを使って本文を執筆（Step 1）"
Write-Host "   3. 執筆後、同ファイルの Step 2 レビュー指示でセルフレビュー"
Write-Host "   4. prompts/review-checklist.md でチェック"
Write-Host "   5. draft: true → draft: false に変更すると公開されます"
Write-Host "   6. Ctrl+S で保存すると自動で git push → デプロイされます"
Write-Host ""

# VS Code で開く
code $filePath
