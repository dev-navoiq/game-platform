---
name: Feature / story
about: Propose a new feature or user-facing change
title: "[Feature] "
labels: feature, needs-refinement
---

## What

<!-- One paragraph: what does the user get? -->

## Why

<!-- The motivation — user pain, business goal, or strategy doc link -->

## User-facing scope

- [ ]
- [ ]
- [ ]

## Out of scope

-

## Open questions

-

---

@claude please refine this story. Specifically:
- Tighten the **What** into a one-line user-value statement
- Propose **acceptance criteria** as Given/When/Then bullets
- List **edge cases** I might've missed (offline, low-end device, social mode interactions, free-tier limits)
- Suggest a **test plan** (which packages/screens to cover with unit / widget / integration tests)
- Flag any **monorepo packages** that'll be touched (e.g. `packages/game_core`, `apps/flutter_app/lib/features/...`)

<!-- Delete the @claude block above to file without auto-refinement. -->
