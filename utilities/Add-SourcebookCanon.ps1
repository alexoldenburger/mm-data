param(
    [string] $SourcebookDir = (Join-Path $PSScriptRoot "..\data\sourcebooks"),
    [switch] $DryRun
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $SourcebookDir -PathType Container)) {
    Write-Error "Sourcebook directory not found: $SourcebookDir"
    exit 1
}

$resolvedSourcebookDir = (Resolve-Path -LiteralPath $SourcebookDir).Path
$precedingKeyPattern = '^(?:ispublished|url|image|abbrev|title|sku|id)\s*:'
$updatedFiles = @()
$skippedFiles = @()
$utf8NoBom = New-Object System.Text.UTF8Encoding $false

Get-ChildItem -LiteralPath $resolvedSourcebookDir -Filter *.yaml -File |
      Sort-Object Name |
      ForEach-Object {
          $filePath = $_.FullName
          $content = [System.IO.File]::ReadAllText($filePath)
          if ($content -match '(?m)^canon\s*:') {
              $skippedFiles += $filePath
              return
          }

          $lineEnding = if ($content.Contains("`r`n")) { "`r`n" } else { "`n" }
          $lines = $content -split '\r?\n', -1
          $insertAt = $null
          for ($index = 0; $index -lt $lines.Count; $index++) {
              if ($lines[$index] -match $precedingKeyPattern) {
                  $insertAt = $index + 1
              }
          }
          if ($null -eq $insertAt) {
              $insertAt = 0
          }

          $newLines = @()
          if ($insertAt -gt 0) {
              $newLines += $lines[0..($insertAt - 1)]
          }
          $newLines += 'canon: true'
          if ($insertAt -lt $lines.Count) {
              $newLines += $lines[$insertAt..($lines.Count - 1)]
          }

          if (-not $DryRun) {
              [System.IO.File]::WriteAllText($filePath, [string]::Join($lineEnding, $newLines), $utf8NoBom)
          }
          $updatedFiles += $filePath
      }

Write-Output "Sourcebook directory: $resolvedSourcebookDir"
Write-Output "Files with existing canon key skipped: $($skippedFiles.Count)"
Write-Output "Files $(if ($DryRun) { 'that would be updated' } else { 'updated' }): $($updatedFiles.Count)"
$updatedFiles | ForEach-Object { Write-Output "  $_" }