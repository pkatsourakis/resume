# CLAUDE.md

Personal resume repo. Single source of truth is **`README.md`**, which *is* the resume content (Markdown). Everything else is either styling, build tooling, or generated output.

## Writing style (applies to all prose in this repo)

- **Never use em-dashes (`—`).** Use commas, colons, parentheses, or separate sentences instead. This applies to the resume, cover letter, and every comment, doc, and commit message here.
- **No "AI tells."** Avoid the giveaways of machine-generated writing: reflexive rule-of-three lists, "not just X but Y" constructions, "whether it's X or Y," empty intensifiers (robust, seamless, leverage, delve), and neat summarizing kickers. Write the way a real, specific person writes.

## How it works

- **`README.md`**: the resume. Edit this to change resume content.
- **`cover-letter.md`**: the cover letter template. Bracketed `[placeholders]` are filled in per application. Reuses `resume.css` for styling.
- **`resume.css`**: styling applied when rendering both documents to HTML/PDF.
- **`index.html`**: the GitHub Pages landing page; embeds the generated resume PDF.

## Build pipeline

Each Markdown source goes: Markdown -> (pandoc) -> styled HTML -> (headless Chrome) -> PDF, plus Markdown -> (pandoc) -> DOCX.

- **Local:** run `./build.ps1` (PowerShell). Needs `pandoc` (`winget install --id JohnMacFarlane.Pandoc -e`) and Chrome or Edge. Regenerates the resume and cover-letter PDF + DOCX from their Markdown sources.
- **CI/CD:** `.github/workflows/build.yml` runs the same pipeline on push to `main` when `README.md`, `cover-letter.md`, `resume.css`, `index.html`, or the workflow itself change, then deploys to GitHub Pages.
- Published at https://pkatsourakis.github.io/resume/

## Generated artifacts, do NOT hand-edit

These are gitignored and produced by the build. Never edit them directly; edit the Markdown source and rebuild:

- `resume.html`, `cover-letter.html`
- `PanoKatsourakis_EngineerResume.pdf`, `PanoKatsourakis_EngineerResume.docx`
- `PanoKatsourakis_CoverLetter.pdf`, `PanoKatsourakis_CoverLetter.docx`
- `preview.png`

## Working here

- To change the resume or cover letter, edit the Markdown source only. Optionally run `./build.ps1` to preview locally; otherwise CI rebuilds and deploys on push.
- Keep the Markdown valid so pandoc renders it cleanly. `README.md` doubles as the GitHub repo landing page and the source for PDF/DOCX.
