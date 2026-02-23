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

function New-TextCover {
    param(
        [string]$OutPath,
        [char[]]$TitleChars,
        [char[]]$SubChars,
        [int]$G1R, [int]$G1G, [int]$G1B,
        [int]$G2R, [int]$G2G, [int]$G2B,
        [int]$CircleVariant = 1
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

    # Title (centered, y=155 to stay in visible 160px band)
    $title = [string]::new($TitleChars)
    $tFont = New-Object System.Drawing.Font("Yu Gothic UI", 36, [System.Drawing.FontStyle]::Bold)
    $tBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(50, 50, 50))
    $tSize = $gfx.MeasureString($title, $tFont)
    $tX = [int](($w - $tSize.Width) / 2)
    $gfx.DrawString($title, $tFont, $tBrush, $tX, 155)
    $tFont.Dispose()
    $tBrush.Dispose()

    # Subtitle (centered, y=220)
    $sub = [string]::new($SubChars)
    $sFont = New-Object System.Drawing.Font("Yu Gothic UI", 16, [System.Drawing.FontStyle]::Regular)
    $sBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(100, 100, 100))
    $sSize = $gfx.MeasureString($sub, $sFont)
    $sX = [int](($w - $sSize.Width) / 2)
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
Write-Host "1/9 brita-water-purifier" -ForegroundColor White
New-TextCover -OutPath "$base\brita-water-purifier\cover.jpg" `
    -TitleChars @(0x42,0x52,0x49,0x54,0x41,0x20,0x46,0x6C,0x6F,0x77,0x20,0x30EC,0x30D3,0x30E5,0x30FC) `
    -SubChars @(0x6C34,0x9053,0x6C34,0x306E,0x30AB,0x30EB,0x30AD,0x81ED,0x304C,0x6D88,0x3048,0x305F,0x8A71) `
    -G1R 200 -G1G 228 -G1B 248 `
    -G2R 235 -G2G 245 -G2B 252 `
    -CircleVariant 2

# 2. Dishwasher (light gray -> light beige) - kitchen theme
Write-Host "2/9 dishwasher-tabletop" -ForegroundColor White
New-TextCover -OutPath "$base\dishwasher-tabletop\cover.jpg" `
    -TitleChars @(0x5353,0x4E0A,0x98DF,0x6D17,0x6A5F,0x20,0x4E,0x50,0x2D,0x54,0x53,0x50,0x31,0x20,0x30EC,0x30D3,0x30E5,0x30FC) `
    -SubChars @(0x8CC3,0x8CB8,0x3067,0x4F7F,0x3063,0x3066,0x6B63,0x89E3,0x3060,0x3063,0x305F) `
    -G1R 238 -G1G 235 -G1B 230 `
    -G2R 248 -G2G 244 -G2B 235 `
    -CircleVariant 3

# 3. Kids water bottle (light orange -> light yellow) - warmth
Write-Host "3/9 kids-water-bottle-guide" -ForegroundColor White
New-TextCover -OutPath "$base\kids-water-bottle-guide\cover.jpg" `
    -TitleChars @(0x5B50,0x4F9B,0x306E,0x6C34,0x7B52,0x306E,0x9078,0x3073,0x65B9) `
    -SubChars @(0x5E74,0x9F62,0x5225,0x306E,0x5BB9,0x91CF,0x76EE,0x5B89,0x30AC,0x30A4,0x30C9) `
    -G1R 252 -G1G 237 -G1B 215 `
    -G2R 252 -G2G 248 -G2B 225 `
    -CircleVariant 1

# 4. LinkBuds (light purple -> light pink) - music/gadget
Write-Host "4/9 linkbuds" -ForegroundColor White
New-TextCover -OutPath "$base\linkbuds\cover.jpg" `
    -TitleChars @(0x53,0x6F,0x6E,0x79,0x20,0x4C,0x69,0x6E,0x6B,0x42,0x75,0x64,0x73,0x20,0x30EC,0x30D3,0x30E5,0x30FC) `
    -SubChars @(0x30C6,0x30EC,0x30EF,0x30FC,0x30AB,0x30FC,0x306B,0x523A,0x3055,0x308B,0x30AA,0x30FC,0x30D7,0x30F3,0x30A4,0x30E4,0x30FC) `
    -G1R 235 -G1G 225 -G1B 248 `
    -G2R 248 -G2G 235 -G2B 242 `
    -CircleVariant 2

# 5. Rakuten Mobile (light red -> light pink) - rakuten color
Write-Host "5/9 rakuten-mobile" -ForegroundColor White
New-TextCover -OutPath "$base\rakuten-mobile\cover.jpg" `
    -TitleChars @(0x697D,0x5929,0x30E2,0x30D0,0x30A4,0x30EB,0x20,0x30EC,0x30D3,0x30E5,0x30FC) `
    -SubChars @(0x6708,0x38,0x2C,0x30,0x30,0x30,0x5186,0x304C,0x33,0x2C,0x30,0x30,0x30,0x5186,0x4EE5,0x4E0B,0x306B,0x306A,0x3063,0x305F,0x8A71) `
    -G1R 248 -G1G 222 -G1B 225 `
    -G2R 252 -G2G 238 -G2B 240 `
    -CircleVariant 1

# 6. Roomba Mini (light blue -> light gray) - tech/cleaning
Write-Host "6/9 roomba-mini" -ForegroundColor White
New-TextCover -OutPath "$base\roomba-mini\cover.jpg" `
    -TitleChars @(0x52,0x6F,0x6F,0x6D,0x62,0x61,0x20,0x4D,0x69,0x6E,0x69,0x20,0x307E,0x3068,0x3081) `
    -SubChars @(0x4F53,0x7A4D,0x534A,0x5206,0x30FB,0x5438,0x5F15,0x529B,0x37,0x30,0x500D,0x306E,0x5B9F,0x529B) `
    -G1R 220 -G1G 235 -G1B 250 `
    -G2R 238 -G2G 240 -G2B 245 `
    -CircleVariant 3

# 7. Water purifier guide (light teal -> white) - water/guide
Write-Host "7/9 water-purifier-guide" -ForegroundColor White
New-TextCover -OutPath "$base\water-purifier-guide\cover.jpg" `
    -TitleChars @(0x6D44,0x6C34,0x5668,0x306E,0x9078,0x3073,0x65B9,0x30AC,0x30A4,0x30C9) `
    -SubChars @(0x35,0x7A2E,0x985E,0x306E,0x9055,0x3044,0x3068,0x30B3,0x30B9,0x30C8,0x3092,0x6BD4,0x8F03) `
    -G1R 218 -G1G 242 -G1B 238 `
    -G2R 242 -G2G 250 -G2B 248 `
    -CircleVariant 2

# 8. Wireless earphones ranking (light navy -> light gray) - gadget
Write-Host "8/9 wireless-earphones-ranking" -ForegroundColor White
New-TextCover -OutPath "$base\wireless-earphones-ranking\cover.jpg" `
    -TitleChars @(0x30EF,0x30A4,0x30E4,0x30EC,0x30B9,0x30A4,0x30E4,0x30DB,0x30F3) `
    -SubChars @(0x304A,0x3059,0x3059,0x3081,0x30E9,0x30F3,0x30AD,0x30F3,0x30B0,0x35,0x9078) `
    -G1R 225 -G1G 228 -G1B 242 `
    -G2R 240 -G2G 240 -G2B 248 `
    -CircleVariant 1

# 9. Remote work pollen (spring green -> light yellow) - health/season
Write-Host "9/9 remote-work-pollen" -ForegroundColor White
New-TextCover -OutPath "$base\remote-work-pollen\cover.jpg" `
    -TitleChars @(0x5728,0x5B85,0x30EF,0x30FC,0x30AF,0x306E,0x82B1,0x7C89,0x75C7,0x5BFE,0x7B56) `
    -SubChars @(0x5BA4,0x5185,0x3067,0x3082,0xFF19,0x5272,0x304C,0x75C7,0x72B6,0x3042,0x308A,0x20,0x2500,0x2500,0x20,0x539F,0x56E0,0x3068,0x5BFE,0x7B56,0x307E,0x3068,0x3081) `
    -G1R 220 -G1G 242 -G1B 215 `
    -G2R 248 -G2G 250 -G2B 225 `
    -CircleVariant 1

Write-Host "`n" ("=" * 50) -ForegroundColor DarkGray
Write-Host "Done!" -ForegroundColor Cyan
