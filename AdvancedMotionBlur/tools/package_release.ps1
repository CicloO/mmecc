# Build a local MME distribution from the current working tree.
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version,
    [string]$Output
)

$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
$source = Join-Path $project 'src'
$folder = "AdvancedMotionBlur-$Version"
if (-not $Output) {
    $Output = Join-Path $project "dist/MMD-$folder.zip"
}
$outputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Output)

$effects = @(
    'AdvancedMotionBlur.x', 'AdvancedMotionBlurController.pmx', 'AdvancedMotionBlur.fx',
    'DepthVelocity.fx', 'MotionGeometry.fx', 'ObjectMotion.fx', 'RigidMotion.fx', 'NoMotionBlur.fx',
    'Camera.fxh', 'Controller.fxh', 'Coverage.fxh', 'Foreground.fxh', 'Fullscreen.fxh',
    'Geometry.fxh', 'HistoryTargets.fxh', 'LinearLight.fxh', 'ModelTiming.fxh',
    'Outline.fxh', 'RigidHistory.fxh', 'Settings.fxh'
)
$entries = [ordered]@{}
foreach ($effect in $effects) {
    $entries.Add($effect, (Join-Path $source $effect))
}
$entries.Add('docs/PARAMETERS.md', (Join-Path $project 'docs/PARAMETERS.md'))
$entries.Add('docs/CHANGELOG.md', (Join-Path $project 'docs/CHANGELOG.md'))
$entries.Add('Readme.txt', (Join-Path $project 'Readme.txt'))

foreach ($path in $entries.Values) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Missing distribution file: $path"
    }
}
$readmeTitle = Get-Content -LiteralPath $entries['Readme.txt'] -TotalCount 1
if ($readmeTitle -ne "AdvancedMotionBlur  ver.$Version") {
    throw "Readme.txt version does not match $Version"
}
$changeHeading = '^## ' + [regex]::Escape($Version) + '(?![\d.])'
if (-not (Select-String -LiteralPath $entries['docs/CHANGELOG.md'] -Pattern $changeHeading -Quiet)) {
    throw "docs/CHANGELOG.md has no section for $Version"
}
foreach ($effect in $effects | Where-Object { $_ -match '\.fxh?$' }) {
    foreach ($include in (Select-String -LiteralPath $entries[$effect] -Pattern '^\s*#\s*include\s+"([^"]+)"')) {
        $name = $include.Matches[0].Groups[1].Value
        if (-not $effects.Contains($name)) {
            throw "$effect includes a file outside the distribution: $name"
        }
    }
}

[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($outputPath))
$buffer = [IO.MemoryStream]::new()
try {
    $archive = [IO.Compression.ZipArchive]::new($buffer, [IO.Compression.ZipArchiveMode]::Create, $true)
    try {
        foreach ($entry in $entries.GetEnumerator()) {
            $zipPath = "$folder/$($entry.Key)"
            if ($entry.Key -eq 'docs/PARAMETERS.md') {
                $manual = [IO.File]::ReadAllText($entry.Value).Replace('](../src/', '](../').Replace('`src/Settings.fxh`', '`Settings.fxh`')
                $data = [Text.Encoding]::UTF8.GetBytes($manual)
                $stream = $archive.CreateEntry($zipPath, [IO.Compression.CompressionLevel]::Optimal).Open()
                try {
                    $stream.Write($data, 0, $data.Length)
                } finally {
                    $stream.Dispose()
                }
            } else {
                [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $entry.Value, $zipPath)
            }
        }
    } finally {
        $archive.Dispose()
    }
    $outputFile = [IO.File]::Open($outputPath, [IO.FileMode]::CreateNew)
    try {
        $buffer.Position = 0
        $buffer.CopyTo($outputFile)
    } finally {
        $outputFile.Dispose()
    }
} finally {
    $buffer.Dispose()
}

Get-FileHash -LiteralPath $outputPath -Algorithm SHA256
