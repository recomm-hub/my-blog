<#
.SYNOPSIS
    Generate text-based cover images (960x400) for all articles.
    Uses pastel gradient backgrounds with decorative circles.
.EXAMPLE
    .\scripts\generate-text-covers.ps1
    .\scripts\generate-text-covers.ps1 -Force
#>
param([switch]$Force)

Add-Type -AssemblyName System.Drawing

# ── Product image helpers ──
function Get-FirstProductImageUrl([string]$mdPath) {
    if (-not (Test-Path $mdPath)) { return $null }
    $text = [System.IO.File]::ReadAllText($mdPath, [System.Text.Encoding]::UTF8)
    $re = [regex]::new('(?i)\{\{<\s*(shop-card|amazon)\s[^>]*img="([^"]+)"')
    $m = $re.Match($text)
    if ($m.Success) {
        $url = $m.Groups[2].Value
        $url = $url -replace '\?_ex=\d+x\d+', '?_ex=300x300'
        return $url
    }
    return $null
}

function Get-ImageFromUrl([string]$url) {
    try {
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent", "Mozilla/5.0")
        $bytes = $wc.DownloadData($url)
        $ms = New-Object System.IO.MemoryStream(,$bytes)
        return [System.Drawing.Image]::FromStream($ms)
    }
    catch {
        Write-Host "    [WARN] Image download failed: $url" -ForegroundColor Yellow
        return $null
    }
}

function Get-FirstProductImage([string]$mdPath) {
    $url = Get-FirstProductImageUrl $mdPath
    if (-not $url) {
        Write-Host "    (no product image found)" -ForegroundColor DarkGray
        return $null
    }
    Write-Host "    Downloading product image..." -ForegroundColor DarkGray -NoNewline
    $img = Get-ImageFromUrl $url
    if ($img) { Write-Host " OK" -ForegroundColor Green }
    return $img
}

function New-TextCover {
    param(
        [string]$OutPath,
        [char[]]$TitleChars,
        [char[]]$SubChars,
        [int]$G1R, [int]$G1G, [int]$G1B,
        [int]$G2R, [int]$G2G, [int]$G2B,
        [int]$CircleVariant = 1,
        [System.Drawing.Image]$ProductImg = $null
    )

    if ((Test-Path $OutPath) -and (-not $Force)) {
        Write-Host "  SKIP (exists, use -Force): $OutPath" -ForegroundColor DarkGray
        return
    }

    $w = 960; $h = 400
    $bmp = New-Object System.Drawing.Bitmap($w, $h)
    $gfx = [System.Drawing.Graphics]::FromImage($bmp)
    $gfx.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $gfx.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

    # Background gradient
    $bgRect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
    $c1 = [System.Drawing.Color]::FromArgb($G1R, $G1G, $G1B)
    $c2 = [System.Drawing.Color]::FromArgb($G2R, $G2G, $G2B)
    $bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        $bgRect, $c1, $c2, [System.Drawing.Drawing2D.LinearGradientMode]::Horizontal)
    $gfx.FillRectangle($bgBrush, $bgRect)
    $bgBrush.Dispose()

    # Decoration circles (3 layout variants)
    $alpha1 = 18; $alpha2 = 14
    # Derive circle colors: deeper/more saturated version of gradient (preserves hue)
    $cr1R = [int]($G1R * 0.55)
    $cr1G = [int]($G1G * 0.55)
    $cr1B = [int]($G1B * 0.55)
    $cr2R = [int]($G2R * 0.60)
    $cr2G = [int]($G2G * 0.60)
    $cr2B = [int]($G2B * 0.60)

    switch ($CircleVariant) {
        1 {
            # Left-top + right-bottom
            $cb = New-Object System.Drawing.SolidBrush(
                [System.Drawing.Color]::FromArgb($alpha1, $cr1R, $cr1G, $cr1B))
            $gfx.FillEllipse($cb, -40, 60, 200, 200)
            $cb.Dispose()
            $cb2 = New-Object System.Drawing.SolidBrush(
                [System.Drawing.Color]::FromArgb($alpha2, $cr2R, $cr2G, $cr2B))
            $gfx.FillEllipse($cb2, 780, 150, 220, 220)
            $cb2.Dispose()
        }
        2 {
            # Right-top + left-center
            $cb = New-Object System.Drawing.SolidBrush(
                [System.Drawing.Color]::FromArgb($alpha1, $cr1R, $cr1G, $cr1B))
            $gfx.FillEllipse($cb, 750, -30, 240, 240)
            $cb.Dispose()
            $cb2 = New-Object System.Drawing.SolidBrush(
                [System.Drawing.Color]::FromArgb($alpha2, $cr2R, $cr2G, $cr2B))
            $gfx.FillEllipse($cb2, -50, 130, 190, 190)
            $cb2.Dispose()
        }
        3 {
            # Left-center large + bottom-right small
            $cb = New-Object System.Drawing.SolidBrush(
                [System.Drawing.Color]::FromArgb($alpha1, $cr1R, $cr1G, $cr1B))
            $gfx.FillEllipse($cb, -60, 100, 230, 230)
            $cb.Dispose()
            $cb2 = New-Object System.Drawing.SolidBrush(
                [System.Drawing.Color]::FromArgb(35, $cr2R, $cr2G, $cr2B))
            $gfx.FillEllipse($cb2, 820, 200, 160, 160)
            $cb2.Dispose()
        }
    }

    # ── Product image card (left side) ──
    $textStartX = 0
    $textEndX = $w
    if ($ProductImg) {
        $cardSz = 210
        $cardX = 0
        $cardY = [int](($h - $cardSz) / 2)

        # Shadow
        $shBr = New-Object System.Drawing.SolidBrush(
            [System.Drawing.Color]::FromArgb(25, 0, 0, 0))
        $gfx.FillRectangle($shBr, ($cardX + 5), ($cardY + 5), $cardSz, $cardSz)
        $shBr.Dispose()

        # White card
        $wBr = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
        $gfx.FillRectangle($wBr, $cardX, $cardY, $cardSz, $cardSz)
        $wBr.Dispose()

        # Product image with padding
        $imgPad = 15
        $imgRect = New-Object System.Drawing.Rectangle(
            ($cardX + $imgPad), ($cardY + $imgPad),
            ($cardSz - $imgPad * 2), ($cardSz - $imgPad * 2))
        $gfx.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $gfx.DrawImage($ProductImg, $imgRect)

        # Card border
        $pen = New-Object System.Drawing.Pen(
            [System.Drawing.Color]::FromArgb(215, 215, 215), 1)
        $gfx.DrawRectangle($pen, $cardX, $cardY, $cardSz, $cardSz)
        $pen.Dispose()

        $textStartX = $cardX + $cardSz + 30
        $textEndX = $w - 25
    }

    # Title (centered in text area, y=155)
    $title = [string]::new($TitleChars)
    $tFont = New-Object System.Drawing.Font("Yu Gothic UI", 36, [System.Drawing.FontStyle]::Bold)
    $tBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(50, 50, 50))
    $tSize = $gfx.MeasureString($title, $tFont)
    if ($textStartX -gt 0) {
        $textAreaW = $textEndX - $textStartX
        $tX = [int]($textStartX + ($textAreaW - $tSize.Width) / 2)
    } else {
        $tX = [int](($w - $tSize.Width) / 2)
    }
    $gfx.DrawString($title, $tFont, $tBrush, $tX, 155)
    $tFont.Dispose()
    $tBrush.Dispose()

    # Subtitle (centered in text area, y=220)
    $sub = [string]::new($SubChars)
    $sFont = New-Object System.Drawing.Font("Yu Gothic UI", 16, [System.Drawing.FontStyle]::Regular)
    $sBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(100, 100, 100))
    $sSize = $gfx.MeasureString($sub, $sFont)
    if ($textStartX -gt 0) {
        $textAreaW = $textEndX - $textStartX
        $sX = [int]($textStartX + ($textAreaW - $sSize.Width) / 2)
    } else {
        $sX = [int](($w - $sSize.Width) / 2)
    }
    $gfx.DrawString($sub, $sFont, $sBrush, $sX, 220)
    $sFont.Dispose()
    $sBrush.Dispose()

    $gfx.Dispose()

    # Save as JPEG quality 90
    $enc = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
        Where-Object { $_.MimeType -eq 'image/jpeg' }
    $ep = New-Object System.Drawing.Imaging.EncoderParameters(1)
    $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter(
        [System.Drawing.Imaging.Encoder]::Quality, [long]90)
    $bmp.Save($OutPath, $enc, $ep)
    $bmp.Dispose()

    Write-Host "  OK: $OutPath" -ForegroundColor Green
}

# ============================================================
# Cover definitions
# ============================================================
$base = "c:\Users\nh1r0\my-blog-local\content\posts\202602"

Write-Host "`nGenerating text-based cover images..." -ForegroundColor Cyan
Write-Host ("=" * 50) -ForegroundColor DarkGray

# 1. BRITA Flow (light blue -> white) - water theme
Write-Host "1/10 brita-water-purifier" -ForegroundColor White
$pImg = Get-FirstProductImage "$base\brita-water-purifier\index.md"
New-TextCover -OutPath "$base\brita-water-purifier\cover.jpg" `
    -TitleChars @(0x42,0x52,0x49,0x54,0x41,0x20,0x46,0x6C,0x6F,0x77,0x20,0x30EC,0x30D3,0x30E5,0x30FC) `
    -SubChars @(0x6C34,0x9053,0x6C34,0x306E,0x30AB,0x30EB,0x30AD,0x81ED,0x304C,0x6D88,0x3048,0x305F,0x8A71) `
    -G1R 200 -G1G 228 -G1B 248 `
    -G2R 235 -G2G 245 -G2B 252 `
    -CircleVariant 2 `
    -ProductImg $pImg
if ($pImg) { $pImg.Dispose() }

# 2. Dishwasher (light gray -> light beige) - kitchen theme
Write-Host "2/10 dishwasher-tabletop" -ForegroundColor White
$pImg = Get-FirstProductImage "$base\dishwasher-tabletop\index.md"
New-TextCover -OutPath "$base\dishwasher-tabletop\cover.jpg" `
    -TitleChars @(0x5353,0x4E0A,0x98DF,0x6D17,0x6A5F,0x20,0x4E,0x50,0x2D,0x54,0x53,0x50,0x31,0x20,0x30EC,0x30D3,0x30E5,0x30FC) `
    -SubChars @(0x8CC3,0x8CB8,0x3067,0x4F7F,0x3063,0x3066,0x6B63,0x89E3,0x3060,0x3063,0x305F) `
    -G1R 238 -G1G 235 -G1B 230 `
    -G2R 248 -G2G 244 -G2B 235 `
    -CircleVariant 3 `
    -ProductImg $pImg
if ($pImg) { $pImg.Dispose() }

# 3. Kids water bottle (light orange -> light yellow) - warmth
Write-Host "3/10 kids-water-bottle-guide" -ForegroundColor White
$pImg = Get-FirstProductImage "$base\kids-water-bottle-guide\index.md"
New-TextCover -OutPath "$base\kids-water-bottle-guide\cover.jpg" `
    -TitleChars @(0x5B50,0x4F9B,0x306E,0x6C34,0x7B52,0x306E,0x9078,0x3073,0x65B9) `
    -SubChars @(0x5E74,0x9F62,0x5225,0x306E,0x5BB9,0x91CF,0x76EE,0x5B89,0x30AC,0x30A4,0x30C9) `
    -G1R 252 -G1G 237 -G1B 215 `
    -G2R 252 -G2G 248 -G2B 225 `
    -CircleVariant 1 `
    -ProductImg $pImg
if ($pImg) { $pImg.Dispose() }

# 4. LinkBuds (light purple -> light pink) - music/gadget
Write-Host "4/10 linkbuds" -ForegroundColor White
$pImg = Get-FirstProductImage "$base\linkbuds\index.md"
New-TextCover -OutPath "$base\linkbuds\cover.jpg" `
    -TitleChars @(0x53,0x6F,0x6E,0x79,0x20,0x4C,0x69,0x6E,0x6B,0x42,0x75,0x64,0x73,0x20,0x30EC,0x30D3,0x30E5,0x30FC) `
    -SubChars @(0x30C6,0x30EC,0x30EF,0x30FC,0x30AB,0x30FC,0x306B,0x523A,0x3055,0x308B,0x30AA,0x30FC,0x30D7,0x30F3,0x30A4,0x30E4,0x30FC) `
    -G1R 235 -G1G 225 -G1B 248 `
    -G2R 248 -G2G 235 -G2B 242 `
    -CircleVariant 2 `
    -ProductImg $pImg
if ($pImg) { $pImg.Dispose() }

# 5. Rakuten Mobile (light red -> light pink) - rakuten color
Write-Host "5/10 rakuten-mobile" -ForegroundColor White
$pImg = Get-FirstProductImage "$base\rakuten-mobile\index.md"
New-TextCover -OutPath "$base\rakuten-mobile\cover.jpg" `
    -TitleChars @(0x697D,0x5929,0x30E2,0x30D0,0x30A4,0x30EB,0x20,0x30EC,0x30D3,0x30E5,0x30FC) `
    -SubChars @(0x6708,0x38,0x2C,0x30,0x30,0x30,0x5186,0x304C,0x33,0x2C,0x30,0x30,0x30,0x5186,0x4EE5,0x4E0B,0x306B,0x306A,0x3063,0x305F,0x8A71) `
    -G1R 248 -G1G 222 -G1B 225 `
    -G2R 252 -G2G 238 -G2B 240 `
    -CircleVariant 1 `
    -ProductImg $pImg
if ($pImg) { $pImg.Dispose() }

# 6. Roomba Mini (light blue -> light gray) - tech/cleaning
Write-Host "6/10 roomba-mini" -ForegroundColor White
$pImg = Get-FirstProductImage "$base\roomba-mini\index.md"
New-TextCover -OutPath "$base\roomba-mini\cover.jpg" `
    -TitleChars @(0x52,0x6F,0x6F,0x6D,0x62,0x61,0x20,0x4D,0x69,0x6E,0x69,0x20,0x307E,0x3068,0x3081) `
    -SubChars @(0x4F53,0x7A4D,0x534A,0x5206,0x30FB,0x5438,0x5F15,0x529B,0x37,0x30,0x500D,0x306E,0x5B9F,0x529B) `
    -G1R 220 -G1G 235 -G1B 250 `
    -G2R 238 -G2G 240 -G2B 245 `
    -CircleVariant 3 `
    -ProductImg $pImg
if ($pImg) { $pImg.Dispose() }

# 7. Water purifier guide (light teal -> white) - water/guide
Write-Host "7/10 water-purifier-guide" -ForegroundColor White
$pImg = Get-FirstProductImage "$base\water-purifier-guide\index.md"
New-TextCover -OutPath "$base\water-purifier-guide\cover.jpg" `
    -TitleChars @(0x6D44,0x6C34,0x5668,0x306E,0x9078,0x3073,0x65B9,0x30AC,0x30A4,0x30C9) `
    -SubChars @(0x35,0x7A2E,0x985E,0x306E,0x9055,0x3044,0x3068,0x30B3,0x30B9,0x30C8,0x3092,0x6BD4,0x8F03) `
    -G1R 218 -G1G 242 -G1B 238 `
    -G2R 242 -G2G 250 -G2B 248 `
    -CircleVariant 2 `
    -ProductImg $pImg
if ($pImg) { $pImg.Dispose() }

# 8. Wireless earphones ranking (light navy -> light gray) - gadget
Write-Host "8/10 wireless-earphones-ranking" -ForegroundColor White
$pImg = Get-FirstProductImage "$base\wireless-earphones-ranking\index.md"
New-TextCover -OutPath "$base\wireless-earphones-ranking\cover.jpg" `
    -TitleChars @(0x30EF,0x30A4,0x30E4,0x30EC,0x30B9,0x30A4,0x30E4,0x30DB,0x30F3) `
    -SubChars @(0x304A,0x3059,0x3059,0x3081,0x30E9,0x30F3,0x30AD,0x30F3,0x30B0,0x35,0x9078) `
    -G1R 225 -G1G 228 -G1B 242 `
    -G2R 240 -G2G 240 -G2B 248 `
    -CircleVariant 1 `
    -ProductImg $pImg
if ($pImg) { $pImg.Dispose() }

# 9. Remote work pollen (spring green -> light yellow) - health/season
Write-Host "9/10 remote-work-pollen" -ForegroundColor White
$pImg = Get-FirstProductImage "$base\remote-work-pollen\index.md"
New-TextCover -OutPath "$base\remote-work-pollen\cover.jpg" `
    -TitleChars @(0x5728,0x5B85,0x30EF,0x30FC,0x30AF,0x306E,0x82B1,0x7C89,0x75C7,0x5BFE,0x7B56) `
    -SubChars @(0x5BA4,0x5185,0x3067,0x3082,0xFF19,0x5272,0x304C,0x75C7,0x72B6,0x3042,0x308A,0x20,0x2500,0x2500,0x20,0x539F,0x56E0,0x3068,0x5BFE,0x7B56,0x307E,0x3068,0x3081) `
    -G1R 220 -G1G 242 -G1B 215 `
    -G2R 248 -G2G 250 -G2B 225 `
    -CircleVariant 1 `
    -ProductImg $pImg
if ($pImg) { $pImg.Dispose() }

# 10. OttoCast vs MILEL (dark gray -> light gray) - car tech
# MILEL画像を使用（2番目のshop-card）
Write-Host "10/10 ottocast-milel-comparison" -ForegroundColor White
$milelUrl = "https://thumbnail.image.rakuten.co.jp/@0_mall/milel-carlife/cabinet/12734098/imgrc0114629980.jpg?_ex=300x300"
Write-Host "    Downloading product image..." -ForegroundColor DarkGray -NoNewline
$pImg = Get-ImageFromUrl $milelUrl
if ($pImg) { Write-Host " OK" -ForegroundColor Green }
# OttoCast vs MILEL = 0x4F,0x74,0x74,0x6F,0x43,0x61,0x73,0x74,0x20,0x76,0x73,0x20,0x4D,0x49,0x4C,0x45,0x4C
# AI BOX 徹底比較 = 0x41,0x49,0x20,0x42,0x4F,0x58,0x20,0x5FB9,0x5E95,0x6BD4,0x8F03
New-TextCover -OutPath "$base\ottocast-milel-comparison\cover.jpg" `
    -TitleChars @(0x4F,0x74,0x74,0x6F,0x43,0x61,0x73,0x74,0x20,0x76,0x73,0x20,0x4D,0x49,0x4C,0x45,0x4C) `
    -SubChars @(0x41,0x49,0x20,0x42,0x4F,0x58,0x20,0x5FB9,0x5E95,0x6BD4,0x8F03) `
    -G1R 230 -G1G 232 -G1B 238 `
    -G2R 242 -G2G 242 -G2B 245 `
    -CircleVariant 3 `
    -ProductImg $pImg
if ($pImg) { $pImg.Dispose() }

# 11. SwitchBot smart home (mint blue -> sky blue) - smart home/tech
Write-Host "11 switchbot-smart-home" -ForegroundColor White
$pImg = Get-FirstProductImage "$base\switchbot-smart-home\index.md"
# SwitchBot の選び方
# シーン別でわかる ── 初心者おすすめガイド
New-TextCover -OutPath "$base\switchbot-smart-home\cover.jpg" `
    -TitleChars @(0x53,0x77,0x69,0x74,0x63,0x68,0x42,0x6F,0x74,0x20,0x306E,0x9078,0x3073,0x65B9) `
    -SubChars @(0x30B7,0x30FC,0x30F3,0x5225,0x3067,0x308F,0x304B,0x308B,0x20,0x2500,0x2500,0x20,0x521D,0x5FC3,0x8005,0x304A,0x3059,0x3059,0x3081,0x30AC,0x30A4,0x30C9) `
    -G1R 200 -G1G 235 -G1B 235 `
    -G2R 215 -G2G 235 -G2B 250 `
    -CircleVariant 2 `
    -ProductImg $pImg
if ($pImg) { $pImg.Dispose() }

# ============================================================
# 202603 articles
# ============================================================
$base03 = "c:\Users\nh1r0\my-blog-local\content\posts\202603"

# nursery-preparation-guide (pastel pink -> lavender) - spring/kids
Write-Host "nursery-preparation-guide" -ForegroundColor White
New-TextCover -OutPath "$base03\nursery-preparation-guide\cover.jpg" `
    -TitleChars @(0x5165,0x5712,0x6E96,0x5099,0x306E,0x6301,0x3061,0x7269,0x30EA,0x30B9,0x30C8) `
    -SubChars @(0x8CBB,0x7528,0x30FB,0x540D,0x524D,0x3064,0x3051,0x30FB,0x5931,0x6557,0x8AC7,0x307E,0x3068,0x3081) `
    -G1R 248 -G1G 225 -G1B 232 `
    -G2R 235 -G2G 228 -G2B 248 `
    -CircleVariant 2

# name-sticker-comparison (soft pink -> peach) - nursery/kids
Write-Host "name-sticker-comparison" -ForegroundColor White
$pImg = Get-FirstProductImage "$base03\name-sticker-comparison\index.md"
New-TextCover -OutPath "$base03\name-sticker-comparison\cover.jpg" `
    -TitleChars @(0x304A,0x540D,0x524D,0x30B7,0x30FC,0x30EB,0x20,0x304A,0x3059,0x3059,0x3081,0x33,0x9078) `
    -SubChars @(0x9632,0x6C34,0x30FB,0x30C7,0x30B6,0x30A4,0x30F3,0x30FB,0x30B3,0x30B9,0x30D1,0x3067,0x6BD4,0x8F03) `
    -G1R 252 -G1G 228 -G1B 225 `
    -G2R 255 -G2G 242 -G2B 230 `
    -CircleVariant 1 `
    -ProductImg $pImg
if ($pImg) { $pImg.Dispose() }

# clothes-dryer-dehumidifier (light cyan -> light blue) - appliance/laundry
Write-Host "clothes-dryer-dehumidifier" -ForegroundColor White
$pImg = Get-FirstProductImage "$base03\clothes-dryer-dehumidifier\index.md"
# 衣類乾燥除湿機 おすすめ3選 = 0x8863,0x985E,0x4E7E,0x71E5,0x9664,0x6E7F,0x6A5F,0x20,0x304A,0x3059,0x3059,0x3081,0x33,0x9078
# 2万円以下で部屋干し臭ゼロへ = 0xFF12,0x4E07,0x5186,0x4EE5,0x4E0B,0x3067,0x90E8,0x5C4B,0x5E72,0x3057,0x81ED,0x30BC,0x30ED,0x3078
New-TextCover -OutPath "$base03\clothes-dryer-dehumidifier\cover.jpg" `
    -TitleChars @(0x8863,0x985E,0x4E7E,0x71E5,0x9664,0x6E7F,0x6A5F,0x20,0x304A,0x3059,0x3059,0x3081,0x33,0x9078) `
    -SubChars @(0xFF12,0x4E07,0x5186,0x4EE5,0x4E0B,0x3067,0x90E8,0x5C4B,0x5E72,0x3057,0x81ED,0x30BC,0x30ED,0x3078) `
    -G1R 210 -G1G 235 -G1B 248 `
    -G2R 230 -G2G 245 -G2B 252 `
    -CircleVariant 1 `
    -ProductImg $pImg
if ($pImg) { $pImg.Dispose() }

Write-Host "`n" ("=" * 50) -ForegroundColor DarkGray
Write-Host "Done!" -ForegroundColor Cyan
