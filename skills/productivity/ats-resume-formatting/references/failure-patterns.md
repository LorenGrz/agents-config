# ATS Parse Failure Patterns — Worked Examples

This reference walks through exactly how each failure mode in `SKILL.md` happens, with before/after examples. All company names below are fictional, chosen only to illustrate a naming *pattern* (lowercase brand, acquired subsidiary, domain-styled name, etc.) — not real companies.

---

## Pattern 1 — The lowercase brand

**Before (fails):**
```
flowly
Product Marketing Manager
2021 – 2024
```

**What happens:** capitalization-weighted NER treats a lowercase-initial token as a common noun, not a proper noun — `flowly` reads like a stray word, not a company. Combined with the year-only date (Pattern 3 below), this block can extract with Company blank and dates missing entirely.

**After (parses):**
```
Product Marketing Manager
Flowly
Mar 2021 – Jun 2024
```

---

## Pattern 2 — The parenthetical title line

**Before (fails):**
```
Senior Director of Marketing (Growth & Lifecycle)
Northwind Analytics
Jan 2022 – Present
```

**What happens:** the parenthetical reproduces the exact `Name (Org)` shape parsers use to detect a company name elsewhere in a block. If `Northwind Analytics` is *also* an out-of-dictionary or ambiguous token, the parser can fall back to scanning the block and seize `(Growth & Lifecycle)` as the Company field instead of the real employer two lines down.

**After (parses):**
```
Senior Director of Marketing
Northwind Analytics
Jan 2022 – Present
```
The qualifier moves to the name-block headline instead, where there's no Company field for it to contaminate:
```
Jordan Rivera
Senior Director of Marketing (Growth & Lifecycle)
Chicago, IL · jordan@email.com · linkedin.com/in/jordanrivera
```

---

## Pattern 3 — The year-only date range

**Before (fails):**
```
Marketing Manager
Northwind Analytics
2019 – 2022
```

**What happens:** this is the single most common failure across every parser tested for this skill. Some engines simply fail to map a year-only range at all, leaving the entire tenure blank in the parsed record — not just the date, the whole entry.

**After (parses):**
```
Marketing Manager
Northwind Analytics
Aug 2019 – Nov 2022
```

If you genuinely don't remember the exact month, pick a placeholder and apply it consistently (many people default to January or July) rather than leaving any range as year-only.

---

## Pattern 4 — The company/location same-line pairing

**Before (fails):**
```
Product Marketing Lead
Cascade Software, Remote
Jun 2020 – Feb 2022
```

**What happens:** the comma-separated pairing can be read as a location line rather than a company line, leaving Company empty even though `Cascade Software` is a perfectly parseable, well-known-shaped name.

**After (parses):**
```
Product Marketing Lead
Cascade Software
Jun 2020 – Feb 2022
```
Location moves to the contact block at the top of the resume, or gets entered directly in the ATS's location form field — never appended to the company line.

---

## Pattern 5 — The domain-styled or acquired brand

**Before (fails):**
```
Marketing Manager
Loopwave.io
Jan 2020 – Present
```

**What happens:** the `.io` domain styling reads to the parser as a URL fragment, not a company name — an out-of-dictionary NER miss regardless of how clean the surrounding layout is.

**After (parses), if there's a recognized parent company:**
```
Marketing Manager
Loopwave (Salesforce)
Jan 2020 – Present
```
The parenthetical here is a *recognized company name*, which is different from Pattern 2's parenthetical (a description). That distinction is the whole test: would a human recognize the word in parentheses as an actual company? If yes, it's a legitimate anchor. If it's a description (`(a Salesforce acquisition)`, `(now part of Slack)`), it belongs in a bullet instead, not the header.

**After (parses), if there's no recognized parent:**
```
Marketing Manager
Loopwave
Jan 2020 – Present
```
De-stylize to plain word form and rely on isolation (its own line, nothing after it) rather than inventing a designator that isn't part of the real legal name.

---

## Pattern 6 — The bulleted, fused education entry

**Before (fails):**
```
Education
• MSc, Environmental Science — University of Toronto
```

**What happens:** three failures stack in one line. The bullet glyph marks the line as description text rather than an entity header. The bare `MSc` acronym misses the degree-level dictionary (which maps `Master of Science`, not the abbreviation). The em dash fuses degree and institution into a single string the parser can't split. The result: this section frequently parses as nothing at all — no degree, no institution.

**After (parses):**
```
Education

Master of Science (MSc), Environmental Science
University of Toronto
```
No bullet, degree spelled out and paired with its acronym, institution on its own line beneath it.

---

## The meta-lesson

None of these failures are visible by reading the resume normally — every "before" example above looks completely reasonable to a human. That's exactly why the plain-text paste test in `SKILL.md` matters: it's the only cheap way to see the document the way the parser sees it, before you find out the hard way that a required field came through blank.
