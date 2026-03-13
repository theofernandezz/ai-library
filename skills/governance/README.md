# Skill Freshness Governance

This module prevents skill drift by enforcing a repeatable update system.

## What It Includes

- Registry of monitored skills: `skills/governance/skill-release-registry.json`
- Freshness checker script: `skills/governance/check-skills-freshness.mjs`
- Weekly CI automation: `.github/workflows/skills-freshness.yml`

## Operating Model

1. Registry is the source of truth.
2. Checker validates metadata freshness, file assertions, and optional live source markers.
3. CI runs on pull requests and weekly schedule.
4. Maintainers review and merge updates.

## Required Registry Fields

Per skill entry:

- `id`: stable skill identifier
- `file`: path to `SKILL.md`
- `owner`: team or maintainer alias
- `cadenceDays`: max days between verifications
- `lastVerified`: `YYYY-MM-DD`

Optional fields:

- `fileAssertions`: strings that must exist in the skill file
- `sources`: list of source URLs and marker checks

## Commands

Run full checks (metadata + live source checks):

```bash
node skills/governance/check-skills-freshness.mjs --strict
```

Run without network fetches:

```bash
node skills/governance/check-skills-freshness.mjs --strict --no-fetch
```

Run only changed skill files (CI optimization):

```bash
CHANGED_FILES="skills/generic/react-native/SKILL.md" \
node skills/governance/check-skills-freshness.mjs --strict --changed-only
```

## Update Playbook

When a source release changes:

1. Update the affected skill file.
2. Update `lastVerified` for that skill in `skill-release-registry.json`.
3. Add or refine `fileAssertions` and `sources.mustContainAny` if needed.
4. Run checker locally.
5. Open PR with evidence links to official release pages.

## Suggested Cadence

- Weekly: volatile ecosystems (`react-native`, `nextjs-core`, `prisma`)
- Monthly: stable pattern skills
- Quarterly: full sweep and deprecation cleanup
