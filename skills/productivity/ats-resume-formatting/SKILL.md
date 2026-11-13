---
name: ats-resume-formatting
description: Use when a resume needs to be formatted, reviewed, or debugged for upload to Workday, Greenhouse, Lever, iCIMS, or any other ATS - "format my resume for ATS", "is my resume ATS-friendly", "why is Workday leaving fields blank", "make my resume parse-safe" - and proactively whenever a resume is built or edited for a job portal. Prevents parsed records with blank or wrong Company, Dates, or Title fields.
---

# ATS / Workday Parse-Safe Resume Formatting

## Objective

Format and review resumes so ATS parsers (Workday, Greenhouse, Lever, iCIMS) fill Title, Company and Dates correctly, and verify the parsed result before and after upload.

Why: the ATS converts the file to plain text read strictly top to bottom, then runs named-entity recognition (NER) to split each block into Title / Company / Start Date / End Date / Description (true of Workday's engine and of Textkernel, RChilli, Daxtra). Recruiters search those parsed fields, not the file. A blank or wrong required field means the candidate never surfaces in recruiter search: a formatting bug that looks like silence. **No format guarantees a clean parse**, so the validation and post-upload steps are mandatory. Semantic layers (Workday Illuminate and similar) sit on top of the NER parse and do not rescue a broken extraction.

## Workflow

1. Apply Rule Sets A-E and the file format rule to the resume.
2. Build the canonical company-name list: list every employer as currently rendered; flag anything lowercase-styled, domain-styled (`.io`, `.video`), acronym-only, very short, or not a household name; fix flagged names with Rule Set B levers 1–2, then test them with the pre-submission check. Keep the tested form of each employer in a table and reuse it verbatim across every resume version; changing a rendered name is a deliberate, tested decision.
3. Run the pre-submission validation (see Verification) on the actual file.
4. After upload, run the post-upload protocol (see Verification).

## Rules

### Rule Set A — Date format

1. **Never use a year-only range.** `2021 – 2024` is the most common failure mode — it can fail to map at all, leaving the whole entry blank.
2. **One format, every role, whole document.** Use `Mon YYYY – Mon YYYY` (e.g. `Jul 2023 – Present`). Mixing formats degrades extraction even when each date is valid.
3. **Current role ends in `Present`.** Never `current`, `now`, `ongoing`, or an open-ended dash.
4. **No apostrophe years (`'21`), no seasons (`Summer 2020`).**
5. **Dates go on their own line**, directly under the employer line, with nothing else on it — no location, no tab-separated text.
6. **Month not remembered:** pick a defensible placeholder (many people default to July, the mid-point of a year) and apply it consistently — never leave the range year-only.

### Rule Set B — Company name (the hardest failure to catch)

NER can drop a real company name because it is unusual, small, stylized, or lowercase, then backfill Company with wrong text from elsewhere in the block. It is invisible until the parse is tested.

1. **De-stylize to plain word form, including capitalization.** Strip domain styling (`brightpath.io` → `BrightPath`) and lowercase brand stylization (`flowly` → `Flowly`) — a lowercase-initial token reads as a common noun, not a company.
2. **Anchor an obscure or small company with a recognized name, if one truthfully exists.**
   - **Parent-brand anchor:** if the company was acquired by or is a subsidiary of a well-known name, add it in parentheses — `Flowly (Atlassian)`. Only an actual recognized company name; a description like `(acquired by Atlassian in 2022)` belongs in a bullet, not the header.
   - **Legal-designator anchor:** if no recognized parent exists, a designator from the actual registered legal name (`Corporation`, `Inc.`, `LLC`) can help — but never invent one. If the registered name has no designator, render the name bare.
3. **Employer alone on its own line — no location, no dates, no delimiter after it.** `Company, Remote` on one line risks the parser reading the whole line as a location and leaving Company empty. Put the location in the contact block or in the ATS form fields.
4. **Never fuse the company into the title line.** No `Title | Company`, no em dash, no bullet, no tab character joining the two.
5. **Never put a parenthetical on the experience-block title line.** `Senior Product Manager (Growth & Retention)` reproduces the `Name (Org)` shape the parser uses to detect a company and can get seized as the employer. Put a role qualifier in the headline under the name instead.

### Rule Set C — Experience block structure

One employer per block, whitespace-separated:

```
Job Title                          ← Line 1: bare, no comma, no parenthetical
Company Name                       ← Line 2: alone, nothing after it
Mon YYYY – Mon YYYY                ← Line 3: alone
•  Bullet describing scope/impact
•  Bullet describing scope/impact
```

1. **Line 1 — title alone.** No comma (`Senior Manager, Product` invites a title/company split failure), no parenthetical, no delimiter.
2. **Line 2 — employer alone** (Rule Set B). **Line 3 — dates alone** (Rule Set A).
3. **One title per employer block.** A promotion within a company is its own block with its own date range; most parsers capture only the first title in a multi-title block and attribute the full tenure to it.
4. **No tables, text boxes, columns, or header/footer content for anything that needs to be parsed.** Contact info goes in a body paragraph at the top — Word header/footer content is frequently skipped.
5. **Standard section headings only:** `Professional Experience` / `Work Experience`, `Education`, `Certifications`, `Core Competencies` / `Skills`. Creative headers (`Career Highlights`, `What I've Built`) are often invisible to the parser.
6. **System font, 10–12pt body, single column, text-based .docx.** No icons, skill-rating bars, or logos in place of text.
7. **Standard bullet glyphs only: `•` or `-`.** Ornamental or icon-font bullets can render as junk or drop the line.

### Rule Set D — Education & certifications

1. **Never bullet an education or certification entry.** A bulleted degree line reads as description text and can be invisible as a degree.
2. **Never fuse degree and institution with an em dash on one line** (`MSc, Environmental Science — Hebrew University`). Use a stacked two-line block:
   ```
   Master of Science (MSc), Environmental Science
   University Name
   ```
3. **Spell out the degree name and pair it with the acronym.** A bare `MSc` or `BA` can miss the degree-level dictionary; `Master of Science (MSc)` hits it.
4. **Certifications belong in a structured `Certifications` section, not buried in a bullet.**
5. **Graduation years are optional on the resume**; a portal that forces a year in its own form field is a manual entry, not a rendering decision.

### Rule Set E — Tokens, competencies & file hygiene

1. **Pair acronyms with their spelled-out form at least once**: `Model Context Protocol (MCP)`, `Retrieval-Augmented Generation (RAG)`. Some ATS configurations treat the acronym and the full term as unrelated skills. Ubiquitous terms (`SaaS`, `ARR`, `GTM`) can usually stand alone.
2. **Core Competencies / Skills as a single wrapped paragraph or plain vertical list** — never tab-aligned pseudo-columns or a table (tab columns reintroduce the multi-column reading-order problem).
3. **File naming:** `FirstName-LastName-Resume.docx`, hyphens not spaces, no special characters. The filename is recruiter-visible and stored with the application record.

### File format

**.docx is the safest upload wherever the portal accepts it.** Treat "PDF parses at parity" claims skeptically: PDF text extraction can flatten structure before NER runs. Use PDF only for:

- Human-facing shares (email attachments, LinkedIn messages, networking) — never for portal upload where DOCX is accepted.
- Portals that flatly refuse DOCX; then be extra rigorous with both checks below.

A styled/branded render (heavy color, icons, multi-column templates) should never be the file uploaded to a parser, even if one is kept for human sharing.

## Reference

- `references/failure-patterns.md`: read when a field parses blank or wrong, or to show the user a worked before/after of each failure mode.

## Verification

### Pre-submission parse validation (before every upload)

1. **Plain-text paste test (60 seconds, every time).** Open the final .docx, select all, paste into a plain text editor (Notepad, TextEdit, or a plain `<textarea>`). For each role confirm the order: bare title → isolated company → dates → bullets, nothing fused or out of sequence; no parenthetical on any title line; Education and Certifications read as clean labeled entries. If it reads wrong here, the ATS reads it wrong too — fix and repeat.
2. **A parser simulator, for a new template or an unusual company name.** Free ATS resume checkers return the extracted Title/Company/Start/End per role — confirm every company name resolves into the Company field, not blank and not folded into the title.
3. **Test the actual file being uploaded**, not a close cousin. With both a plain ATS version and a styled version, validate the ATS one.

### Post-upload protocol (mandatory, even on a well-formatted file)

Autofill is unreliable even with a compliant file. After the portal autofills the form, **review and correct every field by hand** before submitting:

- **Company** — especially an employer with an unusual, short, or stylized name.
- **Location** — landed correctly per role.
- **Dates** — no field defaulted to a year-only or `01/01` placeholder.
- **Most recent title** — not truncated, no absorbed parenthetical.
- **Education fields** — degree level, institution, and year (if required) as separate structured fields.
- **Certifications** — structured credentials, not free text.

A blank field is a recruiter search you never appear in — even on fields that look optional. Fill everything before submitting.

**High-volume applying:** a profile-based autofill browser extension fills form fields from a saved profile, bypassing the resume parser for structured fields. That is a different workflow, not a resume fix.
