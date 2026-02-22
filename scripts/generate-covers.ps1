<#
.SYNOPSIS
    既存の記事から楽天商品画像を抽出し、合成カバー画像を生成するスクリプト。
.DESCRIPTION
    content/posts/ 配下の .md ファイルを読み込み、
    shop-card / amazon ショートコードの img パラメータから商品画像URLを抽出。
    画像をダウンロードして横並びの合成カバー画像を生成し、
    記事をページバンドル形式に変換して cover.jpg を配置します。
.EXAMPLE
    .\scripts\generate-covers.ps1
    .\scripts\generate-covers.ps1 -Force
#>
param(
    [Parameter(Position=0)]
    [string]$PostPath,
    [switch]$Force
)

Add-Type -AssemblyName System.Drawing

# ── 設定 ──
$script:canvasW  = 960
$script:canvasH  = 400
$script:thumbSz  = 260
$script:pad      = 30

$contentRoot = Join-Path $PSScriptRoot "..\content\posts"
$contentRoot = [System.IO.Path]::GetFullPath($contentRoot)

# ── 画像URL抽出 ──
function Get-RakutenImageUrls([string]$text) {
    $out = @()
    $re  = [regex]::new('(?i)\{\{<\s*(shop-card|amazon)\s[^>]*img="([^"]+)"')
    $mc  = $re.Matches($text)
    foreach ($m in $mc) {
        $u = $m.Groups[2].Value
        $u = $u -replace '\?_ex=\d+x\d+', '?_ex=300x300'
        $out += $u
    }
    return $out
}

# ── 画像ダウンロード ──
function Get-ImageFromUrl([string]$url) {
    try {
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent", "Mozilla/5.0")
        $bytes = $wc.DownloadData($url)
        $ms = New-Object System.IO.MemoryStream(,$bytes)
        return [System.Drawing.Image]::FromStream($ms)
    }
    catch {
        Write-Host "    [WARN] DL failed: $url" -ForegroundColor Yellow
        return $null
    }
}

# ── 合成画像生成 ──
function New-CoverImage {
    param(
        [object[]]$Imgs,
        [string]$OutPath,
        [string]$Label
    )

    $w = $script:canvasW
    $h = $script:canvasH
    $sz = $script:thumbSz
    $pd = $script:pad

    $bmp = New-Object System.Drawing.Bitmap($w, $h)
    $gfx = [System.Drawing.Graphics]::FromImage($bmp)
    $gfx.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $gfx.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $gfx.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

    # 背景グラデーション
    $bgRect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
    $c1 = [System.Drawing.Color]::FromArgb(248, 249, 250)
    $c2 = [System.Drawing.Color]::FromArgb(233, 236, 239)
    $bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        $bgRect, $c1, $c2, [System.Drawing.Drawing2D.LinearGradientMode]::Vertical)
    $gfx.FillRectangle($bgBrush, $bgRect)
    $bgBrush.Dispose()

    $n = $Imgs.Count
    if ($n -gt 0) {
        $totalW = ($sz * $n) + ($pd * [Math]::Max(0, $n - 1))
        $ox = [int](($w - $totalW) / 2)
        $oy = [int](($h - $sz) / 2) - 10

        for ($i = 0; $i -lt $n; $i++) {
            $px = $ox + ($i * ($sz + $pd))
            $py = $oy

            # 影
            $shBr = New-Object System.Drawing.SolidBrush(
                [System.Drawing.Color]::FromArgb(40, 0, 0, 0))
            $gfx.FillRectangle($shBr, ($px + 4), ($py + 4), $sz, $sz)
            $shBr.Dispose()

            # 白背景
            $wBr = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
            $gfx.FillRectangle($wBr, $px, $py, $sz, $sz)
            $wBr.Dispose()

            # 画像描画
            $m = 12
            $dr = New-Object System.Drawing.Rectangle(($px+$m),($py+$m),($sz-$m*2),($sz-$m*2))
            $gfx.DrawImage($Imgs[$i], $dr)

            # 枠線
            $pen = New-Object System.Drawing.Pen(
                [System.Drawing.Color]::FromArgb(200,200,200), 1)
            $gfx.DrawRectangle($pen, $px, $py, $sz, $sz)
            $pen.Dispose()
        }

        # ラベル表示（無効化 - 商品画像のみ表示）
    }

    $gfx.Dispose()

    # JPEG 品質90で保存
    $enc = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
        Where-Object { $_.MimeType -eq 'image/jpeg' }
    $ep = New-Object System.Drawing.Imaging.EncoderParameters(1)
    $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter(
        [System.Drawing.Imaging.Encoder]::Quality, [long]90)
    $bmp.Save($OutPath, $enc, $ep)
    $bmp.Dispose()
}

# ── ページバンドル変換 ──
function ConvertTo-Bundle([string]$mdPath) {
    $stem   = [System.IO.Path]::GetFileNameWithoutExtension($mdPath)
    $parent = [System.IO.Path]::GetDirectoryName($mdPath)
    $dir    = Join-Path $parent $stem

    if (Test-Path (Join-Path $dir "index.md")) {
        Write-Host "    Already a bundle" -ForegroundColor DarkGray
        return (Join-Path $dir "index.md")
    }

    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $dest = Join-Path $dir "index.md"
    Move-Item -Path $mdPath -Destination $dest -Force
    Write-Host "    Converted to bundle: $stem/" -ForegroundColor Green
    return $dest
}

# ── frontmatter 書き換え ──
function Set-CoverInFrontmatter([string]$filePath) {
    $lines = [System.IO.File]::ReadAllLines($filePath, [System.Text.Encoding]::UTF8)
    $result = New-Object System.Collections.Generic.List[string]
    $inCover = $false

    foreach ($ln in $lines) {
        # cover: ブロック開始
        if ($ln -match '^cover:\s*$') {
            $inCover = $true
            $result.Add('image: cover.jpg')
            continue
        }
        # cover ブロック内の子行をスキップ
        if ($inCover) {
            $trimmed = $ln.TrimStart()
            if ($trimmed.StartsWith('image:') -or $trimmed.StartsWith('alt:') -or $trimmed.StartsWith('hidden:')) {
                continue
            }
            $inCover = $false
        }
        $result.Add($ln)
    }

    $text = [string]::Join("`n", $result.ToArray())
    [System.IO.File]::WriteAllText($filePath, $text, [System.Text.UTF8Encoding]::new($false))
}

# ── キーワード取得 ──
function Get-Keyword([string]$text) {
    foreach ($ln in $text -split "`n") {
        if ($ln.StartsWith('tags:')) {
            $idx1 = $ln.IndexOf('[')
            $idx2 = $ln.IndexOf(']')
            if ($idx1 -ge 0 -and $idx2 -gt $idx1) {
                $inner = $ln.Substring($idx1 + 1, $idx2 - $idx1 - 1)
                $first = ($inner -split ',')[0].Trim().Trim('"')
                return $first
            }
        }
    }
    return ""
}

# ══════════════════════════════════════════════
# メイン処理
# ══════════════════════════════════════════════
Write-Host ""
Write-Host "Cover image generator" -ForegroundColor Cyan
Write-Host ("=" * 50) -ForegroundColor DarkGray

$mdFiles = @()

if ($PostPath) {
    $fp = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\$PostPath"))
    if (Test-Path $fp -PathType Leaf) {
        $mdFiles += Get-Item $fp
    }
    elseif (Test-Path $fp -PathType Container) {
        $ix = Join-Path $fp "index.md"
        if (Test-Path $ix) { $mdFiles += Get-Item $ix }
    }
    else {
        Write-Host "Not found: $PostPath" -ForegroundColor Red
        exit 1
    }
}
else {
    $mdFiles += Get-ChildItem -Path $contentRoot -Filter "*.md" -File
    foreach ($d in (Get-ChildItem -Path $contentRoot -Directory)) {
        $ix = Join-Path $d.FullName "index.md"
        if (Test-Path $ix) { $mdFiles += Get-Item $ix }
    }
}

if ($mdFiles.Count -eq 0) {
    Write-Host "No posts found." -ForegroundColor Yellow
    exit 0
}

Write-Host "Posts: $($mdFiles.Count)" -ForegroundColor White
Write-Host ""

$ok = 0; $skip = 0; $fail = 0

foreach ($f in $mdFiles) {
    $label = $f.Name
    if ($f.Name -eq "index.md") { $label = $f.Directory.Name + "/index.md" }
    Write-Host "--- $label ---" -ForegroundColor Cyan

    $body = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)

    # 既にカバーがあるか
    $isBundle = ($f.Name -eq "index.md")
    if ($isBundle -and (-not $Force)) {
        $cp = Join-Path $f.DirectoryName "cover.jpg"
        if (Test-Path $cp) {
            Write-Host "    Skip (cover exists, use -Force)" -ForegroundColor DarkGray
            $skip++
            continue
        }
    }

    # 画像URL抽出
    $urls = Get-RakutenImageUrls $body
    if ($urls.Count -eq 0) {
        Write-Host "    Skip (no images found)" -ForegroundColor Yellow
        $skip++
        continue
    }
    Write-Host "    Images: $($urls.Count)" -ForegroundColor White

    $kw = Get-Keyword $body

    # ダウンロード
    $imgs = @()
    foreach ($u in $urls) {
        Write-Host "    Downloading..." -ForegroundColor DarkGray -NoNewline
        $im = Get-ImageFromUrl $u
        if ($im) {
            $imgs += $im
            Write-Host " OK ($($im.Width)x$($im.Height))" -ForegroundColor Green
        }
        else {
            Write-Host " FAIL" -ForegroundColor Red
        }
    }

    if ($imgs.Count -eq 0) {
        Write-Host "    ERROR: no valid images" -ForegroundColor Red
        $fail++
        continue
    }

    # バンドル変換
    $current = $f.FullName
    if (-not $isBundle) {
        $current = ConvertTo-Bundle $f.FullName
    }

    $bDir  = [System.IO.Path]::GetDirectoryName($current)
    $cPath = Join-Path $bDir "cover.jpg"

    # 合成
    Write-Host "    Generating cover..." -ForegroundColor DarkGray
    try {
        New-CoverImage -Imgs $imgs -OutPath $cPath -Label $kw
        Write-Host "    OK: cover.jpg" -ForegroundColor Green
    }
    catch {
        Write-Host "    ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $fail++
        foreach ($im in $imgs) { $im.Dispose() }
        continue
    }

    # frontmatter 更新
    Set-CoverInFrontmatter $current
    Write-Host "    OK: frontmatter updated" -ForegroundColor Green

    foreach ($im in $imgs) { $im.Dispose() }
    $ok++
    Write-Host ""
}

Write-Host ("=" * 50) -ForegroundColor DarkGray
Write-Host "Done: OK=$ok  Skip=$skip  Fail=$fail" -ForegroundColor White
if ($ok -gt 0) {
    Write-Host "Run 'hugo server -D' to check." -ForegroundColor Yellow
}
