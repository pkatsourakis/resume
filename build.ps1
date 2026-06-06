# build.ps1: regenerate the resume + cover-letter PDFs/docx from their markdown sources.
# Sources of truth are README.md and cover-letter.md; everything else is generated. Run after edits, then commit.
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

# Each entry is a source markdown file and the basenames of its generated artifacts.
$docs = @(
  @{ Md = "README.md";       Html = "resume.html";       Pdf = "PanoKatsourakis_EngineerResume.pdf"; Docx = "PanoKatsourakis_EngineerResume.docx"; Title = "Pano Katsourakis Resume" },
  @{ Md = "cover-letter.md"; Html = "cover-letter.html"; Pdf = "PanoKatsourakis_CoverLetter.pdf";    Docx = "PanoKatsourakis_CoverLetter.docx";    Title = "Pano Katsourakis Cover Letter" }
)

$profileDir = Join-Path $env:TEMP "resume-build-chrome"

foreach ($doc in $docs) {
  # 1. Markdown -> standalone styled HTML
  & $pandoc $doc.Md -o $doc.Html --standalone --css=resume.css --metadata pagetitle=$doc.Title

  # 2. HTML -> PDF via headless browser.
  # Use a throwaway --user-data-dir so we get a fresh isolated instance even if
  # Chrome/Edge is already running (otherwise the headless call is silently ignored).
  $htmlUrl = "file:///" + ((Resolve-Path $doc.Html) -replace '\\','/')
  $pdfFull = Join-Path $PSScriptRoot $doc.Pdf
  $bArgs = @(
    "--headless=new", "--disable-gpu", "--no-pdf-header-footer",
    "--user-data-dir=$profileDir", "--print-to-pdf=$pdfFull", $htmlUrl
  )
  # Start-Process -Wait so we block on the child that actually does the printing
  # (the chrome.exe launcher forks and returns immediately on its own).
  $proc = Start-Process -FilePath $browser -ArgumentList $bArgs -Wait -PassThru -NoNewWindow
  if ($proc.ExitCode -ne 0 -or -not (Test-Path $pdfFull)) { throw "PDF was not produced for $($doc.Md) (browser exit $($proc.ExitCode))." }

  # 3. Markdown -> docx (same source, for applications that want Word)
  & $pandoc $doc.Md -o $doc.Docx

  Write-Host "Built $($doc.Pdf) and $($doc.Docx) from $($doc.Md)" -ForegroundColor Green
}
