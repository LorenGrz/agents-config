---
name: meeting-notes-organizer
description: Use this skill to turn raw meeting notes into an actionable record - executive summary, decisions made, action items with owner and deadline, and open topics for next time.
metadata:
  version: "0.1.0"
  owner: "loren-local"
  source: "adapted from nicos_ai skill catalog"
  triggers:
    - meeting minutes
    - clean up these notes
    - action items from meeting
    - acta de reunión
---

# Meeting Notes Organizer

## Objective

Convert unstructured notes into a record where every decision and task is explicit.

## Workflow

1. Process the raw notes.
2. Separate discussion from decisions.
3. Extract each action item with an owner and a due date.
4. Write a 3-5 line executive summary.
5. Move unresolved debates to an "open topics" section.

## Output

- Meeting metadata: date, attendees, topic.
- Executive summary (3-5 lines).
- Decisions made.
- Action items: who / what / when.
- Open topics for the next meeting.

## Operating Rules

- Write in the language of the source notes; default to Spanish for Loren.
- Do not invent anything not in the notes.
- Mark `[PENDING OWNER]` for any action without a clear owner.
- Mark `[NO DATE]` for any task without a deadline.
- Prefer a scannable structure over completeness.
