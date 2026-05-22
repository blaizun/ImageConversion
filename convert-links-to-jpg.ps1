param(
    [string]$SourceDir = ".\Links",
    [ValidateRange(1, 100)]
    [int]$Quality = 92,
    [switch]$Overwrite
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $SourceDir -PathType Container)) {
    throw "Source directory not found: $SourceDir"
}

Add-Type -AssemblyName PresentationCore

$sourcePath = (Resolve-Path -LiteralPath $SourceDir).Path
$convertibleExtensions = @(".tif", ".tiff", ".png", ".bmp", ".gif")
$skipExtensions = @(".jpg", ".jpeg")

$converted = 0
$skipped = 0
$failed = 0
$skippedArtifacts = 0

$files = Get-ChildItem -LiteralPath $sourcePath -File -Recurse

foreach ($file in $files) {
    $ext = $file.Extension.ToLowerInvariant()

    if ($skipExtensions -contains $ext) {
        continue
    }

    if (-not ($convertibleExtensions -contains $ext)) {
        continue
    }
    if ($file.Name.StartsWith("._") -or $file.FullName -like "*\__MACOSX\*") {
        $skippedArtifacts++
        continue
    }

    $destination = [System.IO.Path]::ChangeExtension($file.FullName, ".jpg")

    if ((Test-Path -LiteralPath $destination) -and -not $Overwrite) {
        $skipped++
        continue
    }
    $inStream = $null
    $outStream = $null
    $image = $null
    try {
        $inStream = [System.IO.File]::OpenRead($file.FullName)
        $decoder = [System.Windows.Media.Imaging.BitmapDecoder]::Create(
            $inStream,
            [System.Windows.Media.Imaging.BitmapCreateOptions]::PreservePixelFormat,
            [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        )

        if ($decoder.Frames.Count -lt 1) {
            throw "No image frames found."
        }

        $frame = $decoder.Frames[0]
        $encoder = New-Object System.Windows.Media.Imaging.JpegBitmapEncoder
        $encoder.QualityLevel = $Quality
        $encoder.Frames.Add($frame)

        $outStream = [System.IO.File]::Open($destination, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        $encoder.Save($outStream)
        $converted++
        Write-Host "Converted: $($file.FullName) -> $destination"
    }
    catch {
        $failed++
        Write-Warning "Failed to convert $($file.FullName): $($_.Exception.Message)"
    }
    finally {
        if ($null -ne $outStream) { $outStream.Dispose() }
        if ($null -ne $inStream) { $inStream.Dispose() }
    }
}

Write-Host ""
Write-Host "Done."
Write-Host "Converted: $converted"
Write-Host "Skipped (existing JPG): $skipped"
Write-Host "Skipped (macOS metadata artifacts): $skippedArtifacts"
Write-Host "Failed: $failed"
