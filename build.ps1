# build.ps1 — regenerate the resume PDF + docx from README.md.
# Source of truth is README.md; everything else is generated. Run after edits, then commit.
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

# Locate pandoc (winget installs it here and adds it to PATH for new shells)
$pandoc = Get-Command pandoc -ErrorAction SilentlyContinue
if (-not $pandoc) {
  $candidate = "$env:LOCALAPPDATA\Pandoc\pandoc.exe"
  if (Test-Path $candidate) { $pandoc = $candidate } else { throw "pandoc not found. Install with: winget install --id JohnMacFarlane.Pandoc -e" }
} else { $pandoc = $pandoc.Source }

# Locate a Chromium browser for PDF printing (Chrome preferred, Edge fallback)
$browser = @(
  "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
  "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
  "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
  "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $browser) { throw "No Chrome/Edge found for PDF printing." }

$pdf = "PanoKatsourakis_EngineerResume.pdf"
$docx = "PanoKatsourakis_EngineerResume.docx"

# 1. Markdown -> standalone styled HTML
& $pandoc README.md -o resume.html --standalone --css=resume.css --metadata pagetitle="Pano Katsourakis Resume"

# 2. HTML -> PDF via headless browser.
# Use a throwaway --user-data-dir so we get a fresh isolated instance even if
# Chrome/Edge is already running (otherwise the headless call is silently ignored).
$profileDir = Join-Path $env:TEMP "resume-build-chrome"
$htmlUrl = "file:///" + ((Resolve-Path resume.html) -replace '\\','/')
$pdfFull = Join-Path $PSScriptRoot $pdf
$bArgs = @(
  "--headless=new", "--disable-gpu", "--no-pdf-header-footer",
  "--user-data-dir=$profileDir", "--print-to-pdf=$pdfFull", $htmlUrl
)
# Start-Process -Wait so we block on the child that actually does the printing
# (the chrome.exe launcher forks and returns immediately on its own).
$proc = Start-Process -FilePath $browser -ArgumentList $bArgs -Wait -PassThru -NoNewWindow
if ($proc.ExitCode -ne 0 -or -not (Test-Path $pdfFull)) { throw "PDF was not produced (browser exit $($proc.ExitCode))." }

# 3. Markdown -> docx (same source, for applications that want Word)
& $pandoc README.md -o $docx

Write-Host "Built $pdf and $docx from README.md" -ForegroundColor Green
