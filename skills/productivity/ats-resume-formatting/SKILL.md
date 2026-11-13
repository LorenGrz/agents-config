---
name: ats-resume-formatting
description: Use this skill whenever a resume needs to be formatted, reviewed, or debugged for upload to Workday, Greenhouse, Lever, iCIMS, or any other ATS (applicant tracking system). Trigger on requests like "format my resume for ATS," "is my resume ATS-friendly," "why is Workday leaving fields blank," "clean up my resume for online applications," or "make my resume parse-safe." Also trigger proactively any time a user is building or editing a resume that will be uploaded to a job portal, even if they don't mention "ATS" by name — most resume-formatting requests have this failure mode lurking under the surface. Prevents the most common cause of silent application failure — a resume that looks perfect to a human but leaves the Company, Dates, or Title field blank or wrong in the parsed record, which means the candidate never surfaces in recruiter search regardless of how strong the resume is.
---

# ATS / Workday Parse-Safe Resume Formatting

## Why this exists

Workday and most ATS platforms don't show a recruiter your PDF or DOCX. They convert it to plain text, strip the layout, and run **named-entity recognition (NER)** to segment each experience block into structured fields: Job Title / Company / Start Date / End Date / Description. The recruiter searches and screens those parsed fields — not the file you uploaded.

**A resume that reads perfectly to a human can still leave a required field blank in the system of record.** When that happens, the candidate frequently doesn't get filtered — they simply never surface in recruiter search. It looks identical to silence, but it's a formatting bug, not a rejection.

This is the single most common, least-visible way a strong candidate loses to a weaker one: not worse experience, a worse parse.

### The two-stage parse (true of Workday's engine and most third-party parsers — Textkernel, RChilli, Daxtra)

1. **Ingestion** — file → raw plain text, layout stripped, read strictly top to bottom.
2. **Entity extraction** — each block segmented into Title / Company / Dates / Description. If extraction fails, the field is either blank or filled with the wrong text — and a blank required field can mean the application doesn't route into recruiter search at all.

**Reality check:** a clean single-column .docx extracts the large majority of fields correctly — but even a well-formatted file typically loses a handful of sub-fields: a date suffix, an unusual company name, a multi-line title. **No format guarantees a clean parse.** That's why this skill treats pre-submission validation and post-upload verification as mandatory steps, not optional polish — the parsed form data is the real application.

**On semantic/AI layers (Workday Illuminate and similar):** newer ATS platforms add a semantic-matching layer on top of the classic NER parser. It does not rescue a broken extraction — if the base parser can't map the text cleanly, the semantic layer has nothing to work with. Clean extraction always comes first.

---

## Rule Set A — Date format

The single most common parse failure is a date range with no month.

1. **Never use a year-only range.** `2021 – 2024` is the most common failure mode — it can fail to map at all, leaving the whole entry blank.
2. **One format, every role, whole document.** Use `Mon YYYY – Mon YYYY` (e.g. `Jul 2023 – Present`). Mixing formats across roles degrades extraction even when each individual date is technically valid.
3. **Current role ends in `Present`.** Never `current`, `now`, `ongoing`, or an open-ended dash.
4. **No apostrophe years (`'21`), no seasons (`Summer 2020`).** A parser has no dictionary entry for which month "Summer" means.
5. **Dates go on their own line**, directly under the employer line, with nothing else on it — no location, no tab-separated text.
6. **If you genuinely don't remember the month,** pick a defensible placeholder (many people default to July, the mid-point of a year) and apply it consistently — never leave the range as year-only just because the exact month is fuzzy.

---

## Rule Set B — Company name (the hardest failure to catch)

NER can drop a real, correctly-spelled company name simply because it's unusual, small, stylized, or lowercase — and worse, it can then backfill the Company field with the wrong text pulled from elsewhere in the block. This is invisible until you actually test the parse; it's the failure most people never catch before submitting.

1. **De-stylize to plain word form, including capitalization.** Strip domain styling (`brightpath.io` → `BrightPath`) and lowercase brand stylization (`flowly` → `Flowly`) — a lowercase-initial token reads to capitalization-weighted NER as a common noun, not a company name.
2. **Anchor an obscure or small company with a recognized name, if one truthfully exists.**
   - **Parent-brand anchor:** if the company was acquired by or is a subsidiary of a well-known name, add it in parentheses — `Flowly (Atlassian)`. Only do this if the parenthetical is an actual recognized company name; a description like `(acquired by Atlassian in 2022)` belongs in a bullet, not the header.
   - **Legal-designator anchor:** if no recognized parent exists, a corporate designator drawn from the actual registered legal name (`Corporation`, `Inc.`, `LLC`) can help — but never invent one. If the registered name doesn't include a designator, don't add one; render the name bare instead.
3. **Put the employer alone on its own line — no location, no dates, no delimiter after it.** This is the default that causes the fewest failures: pairing `Company, Remote` on one line risks the parser reading the whole line as a location and leaving Company empty. Put the location in your contact block or in the ATS form fields instead — not on the company line.
4. **Never fuse the company into the title line.** No `Title | Company`, no em dash, no bullet, no tab character joining the two.
5. **Never put a parenthetical on the experience-block title line.** `Senior Product Manager (Growth & Retention)` on the title line reproduces the exact `Name (Org)` shape the parser uses to detect a company — and it can get seized as the employer instead of your actual company name. If you want a role qualifier or specialization visible, put it in your headline under your name, not on the title line inside an experience block.

### How to build your own canonical company-name list

Don't guess which of your past employers are parse-risky — test each one:

1. List every employer name exactly as you currently render it.
2. Flag anything that's lowercase-styled, domain-styled (`.io`, `.video`), acronym-only, very short, or not a household name.
3. Run each flagged name through the pre-submission check below (Rule Set B levers 1–2 first).
4. Keep a running table of *your* tested, canonical form for each employer — reuse it verbatim across every resume version. Treat any change to a company's rendered name as a deliberate, tested decision, not a one-off edit.

---

## Rule Set C — Experience block structure

The parse-safest shape, one employer per block, whitespace-separated:

```
Job Title                          ← Line 1: bare, no comma, no parenthetical
Company Name                       ← Line 2: alone, nothing after it
Mon YYYY – Mon YYYY                ← Line 3: alone
•  Bullet describing scope/impact
•  Bullet describing scope/impact
```

1. **Line 1 — title alone.** No comma (`Senior Manager, Product` invites a title/company split failure), no parenthetical, no delimiter.
2. **Line 2 — employer alone**, per Rule Set B.
3. **Line 3 — dates alone**, per Rule Set A.
4. **One title per employer block.** If you were promoted within a company, list each title as its own block with its own date range. Most parsers only capture the first title in a multi-title block and misattribute the full tenure to it.
5. **No tables, text boxes, columns, or header/footer content for anything that needs to be parsed.** Contact info goes in a body paragraph at the top of the document — content placed in a Word header or footer is frequently skipped entirely by parsers.
6. **Standard section headings only:** `Professional Experience` / `Work Experience`, `Education`, `Certifications`, `Core Competencies` / `Skills`. Creative headers (`Career Highlights`, `What I've Built`) are often unrecognized and effectively invisible to the parser.
7. **System font, 10–12pt body, single column, text-based .docx.** No icons, skill-rating bars, or logos in place of text.
8. **Standard bullet glyphs only: `•` or `-`.** Ornamental or icon-font bullets can render as junk characters or drop the line entirely.

---

## Rule Set D — Education & certifications

1. **Never bullet an education or certification entry.** A bullet glyph marks a line as description text subordinate to something else — a bulleted degree line can be invisible as a degree.
2. **Never fuse degree and institution with an em dash on one line** (`MSc, Environmental Science — Hebrew University` as a single line). Use a stacked two-line block instead:
   ```
   Master of Science (MSc), Environmental Science
   University Name
   ```
3. **Spell out the degree name and pair it with the acronym.** A bare `MSc` or `BA` can miss the degree-level dictionary; `Master of Science (MSc)` hits it.
4. **Certifications belong in a structured `Certifications` section, not buried in a bullet.** A credential mentioned only inside an experience bullet is invisible to a structured-field filter that recruiters use to search for it directly.
5. **Leave graduation years off if you'd rather not disclose them** — many portals still force a year in their own form field, which is fine; that's a manual entry, not a resume-rendering decision.

---

## Rule Set E — Tokens, competencies & file hygiene

1. **Pair acronyms with their spelled-out form at least once**, anywhere on the resume: `Model Context Protocol (MCP)`, `Retrieval-Augmented Generation (RAG)`. Some ATS configurations treat the acronym and the full term as unrelated skills. Ubiquitous terms (`SaaS`, `ARR`, `GTM`) can usually stand alone.
2. **Core Competencies / Skills as a single wrapped paragraph or plain vertical list** — never tab-aligned pseudo-columns or a table. Tab columns silently reintroduce the multi-column reading-order problem inside an otherwise single-column document.
3. **File naming:** `FirstName-LastName-Resume.docx`, hyphens not spaces, no special characters. The filename is recruiter-visible and stored with the application record.

---

## File format

**.docx is the safest upload wherever the portal accepts it.** Text-selectable PDFs are sometimes advertised as parsing "at parity" with DOCX on modern ATS platforms — treat that claim skeptically. PDF text extraction can flatten document structure before NER runs, and a structurally-correct DOCX gives the parser more to work with. Use PDF only for:
- Human-facing shares (email attachments, LinkedIn messages, networking) — never for portal upload where DOCX is accepted.
- Portals that flatly refuse DOCX. If you're forced onto PDF, run the pre-submission check below and be extra rigorous on post-upload verification.

A styled/branded resume render (heavy color, icons, multi-column "modern" templates) should never be the file you upload to a parser, even if you also maintain one for human sharing.

---

## Pre-submission parse validation (do this before every upload)

Catch a mis-parse while you can still fix the file — not after the form has locked it in.

1. **The plain-text paste test (free, 60 seconds, do this every time).** Open the final .docx, select all, paste into a plain text editor (Notepad, TextEdit, or a plain `<textarea>`). For each role, confirm you can read, in order: bare title → isolated company → dates → bullets, with nothing fused together or out of sequence. Confirm no parenthetical appears on any title line. Confirm Education and Certifications read as clean labeled entries. If it reads wrong here, the ATS will read it wrong too — fix and repeat.
2. **A parser simulator, for a new template or an unusual company name.** Several free ATS resume checkers will return the extracted Title/Company/Start/End per role — use one to confirm every company name resolves into the Company field, not blank and not folded into the title text.
3. **Test the actual file you're about to upload** — not a close cousin of it. If you maintain both a plain ATS version and a styled human-facing version, validate the ATS version specifically.

---

## Post-upload protocol (mandatory, even on a well-formatted file)

Autofill is unreliable even when the source document is fully compliant with everything above. After the portal autofills the form, **review and correct every field by hand** before submitting:

- **Company** — especially on any employer with an unusual, short, or stylized name.
- **Location** — confirm it landed correctly per role.
- **Dates** — confirm no field defaulted to a year-only or `01/01` placeholder you didn't intend.
- **Most recent title** — confirm it's not truncated and hasn't absorbed a parenthetical.
- **Education fields** — degree level, institution, and year (if required) parsed as separate structured fields.
- **Certifications** — landed as structured credentials, not as free text.

A blank field is a recruiter search you never appear in — even on fields that look optional. Fill everything before you submit.

**High-volume applying:** a profile-based autofill browser extension can fill form fields directly from a saved profile, bypassing the resume parser for structured fields entirely. That's a different workflow, not a resume fix, but worth knowing if you're applying at volume.

---

## Quick pre-flight checklist

- [ ] No year-only dates anywhere; `Mon YYYY` format, consistent document-wide
- [ ] Every employer name tested against Rule Set B (de-stylized, correctly capitalized, anchored if needed)
- [ ] Every employer on its own isolated line — no location, no delimiter after it
- [ ] No comma or parenthetical on any experience-block title line
- [ ] Single column, standard fonts, standard bullets, no tables/text boxes/headers-footers
- [ ] Education and certifications un-bulleted, degree spelled out + paired with acronym
- [ ] Skills/competencies as a wrapped paragraph or plain list, not a table
- [ ] Filename is `FirstName-LastName-Resume.docx`, hyphens, no special characters
- [ ] Ran the plain-text paste test on the actual file being uploaded
- [ ] Uploaded .docx wherever accepted; PDF only for human sharing or PDF-only portals
- [ ] Verified every autofilled field by hand before hitting submit

See `references/failure-patterns.md` for a longer walkthrough of exactly how each of these failures happens under the hood, with worked before/after examples.
