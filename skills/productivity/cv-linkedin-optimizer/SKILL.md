---
name: cv-linkedin-optimizer
description: Use this skill to tailor a CV and LinkedIn profile to a specific job posting - mapping experience to the posting's key competencies, adding sector keywords for ATS, quantifying achievements, and flagging gaps honestly.
metadata:
  version: "0.1.0"
  owner: "loren-local"
  source: "adapted from nicos_ai skill catalog"
  triggers:
    - optimize my CV
    - tailor resume to job
    - LinkedIn headline
    - adaptar el CV a esta oferta
---

# CV & LinkedIn Optimizer

## Objective

Rewrite a CV so it matches what a specific posting asks for, and produce LinkedIn headline and About suggestions.

## Workflow

1. Extract the posting's 5-7 key competencies.
2. Map the candidate's real experience against each one.
3. Rewrite role descriptions with action verbs and measurable results, weaving in the posting's keywords naturally for ATS.
4. For LinkedIn, write a headline as `role + differentiating value` and a short About.
5. Where direct experience is missing, show transferable experience or name the gap and suggest how to frame it.

## Rules

- Write in the language of the posting; default to Spanish for Loren.
- Never invent experience or inflate results.
- Keep the CV to one page under 5 years of experience, two pages otherwise.
- Include only 4-5 of the most relevant projects, and group skills into sections the way the portfolio does - do not dump everything.
- Do not copy phrases verbatim from the posting.
- For a CV that will be uploaded to a job portal, layout, dates and file format follow `ats-resume-formatting`.

## Output

- Optimized CV: professional profile (3-4 lines), experience, skills (prioritized to the posting), education.
- LinkedIn: headline, About, skills to feature.
- A short list of gaps and how to address them.
