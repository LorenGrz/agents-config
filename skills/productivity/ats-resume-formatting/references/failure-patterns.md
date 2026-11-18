# ATS Parse Failure Patterns — Worked Examples
Read when: a resume field parses blank or wrong and you need the worked before/after cause of each failure mode in `SKILL.md`.

All company names below are fictional; each illustrates a naming *pattern*.

---

## Pattern 1 — The lowercase brand

**Before (fails):**
```
flowly
Product Marketing Manager
2021 – 2024
```

**What happens:** capitalization-weighted NER reads lowercase `flowly` as a common noun, not a company. With the year-only date (Pattern 3), Company and dates can both come out blank.

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

**What happens:** the parenthetical mimics the `Name (Org)` company shape. If `Northwind Analytics` is *also* out-of-dictionary or ambiguous, the parser can seize `(Growth & Lifecycle)` as the Company.

**After (parses):**
```
Senior Director of Marketing
Northwind Analytics
Jan 2022 – Present
```
The qualifier moves to the name-block headline, which has no Company field:
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

**What happens:** the most common failure across every parser tested. Some engines fail to map a year-only range at all and leave the whole entry blank, not just the date.

**After (parses):**
```
Marketing Manager
Northwind Analytics
Aug 2019 – Nov 2022
```

Month not remembered: pick a placeholder (January or July are common) and apply it consistently.

---

## Pattern 4 — The company/location same-line pairing

**Before (fails):**
```
Product Marketing Lead
Cascade Software, Remote
Jun 2020 – Feb 2022
```

**What happens:** the comma-separated pairing can be read as a location line, leaving Company empty even though `Cascade Software` parses fine alone.

**After (parses):**
```
Product Marketing Lead
Cascade Software
Jun 2020 – Feb 2022
```
Location goes in the contact block or the ATS location form field, never on the company line.

---

## Pattern 5 — The domain-styled or acquired brand

**Before (fails):**
```
Marketing Manager
Loopwave.io
Jan 2020 – Present
```

**What happens:** the `.io` styling reads as a URL fragment, an out-of-dictionary NER miss however clean the layout.

**After (parses), if there's a recognized parent company:**
```
Marketing Manager
Loopwave (Salesforce)
Jan 2020 – Present
```
The test: would a human recognize the word in parentheses as an actual company? If yes, it's a legitimate anchor (unlike Pattern 2's description). A description (`(a Salesforce acquisition)`, `(now part of Slack)`) belongs in a bullet, not the header.

**After (parses), if there's no recognized parent:**
```
Marketing Manager
Loopwave
Jan 2020 – Present
```
De-stylize and rely on isolation (its own line, nothing after it); never invent a designator that isn't part of the real legal name.

---

## Pattern 6 — The bulleted, fused education entry

**Before (fails):**
```
Education
• MSc, Environmental Science — University of Toronto
```

**What happens:** three failures stack: the bullet marks the line as description text, the bare `MSc` misses the degree-level dictionary (which maps `Master of Science`), and the em dash fuses degree and institution. The section often parses as nothing: no degree, no institution.

**After (parses):**
```
Education

Master of Science (MSc), Environmental Science
University of Toronto
```
No bullet, degree spelled out and paired with its acronym, institution on its own line beneath it.

---

Every "before" above looks fine to a human: only the plain-text paste test in `SKILL.md` shows what the parser sees.
