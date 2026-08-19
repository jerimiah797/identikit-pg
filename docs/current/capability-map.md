# Capability map

Changes I want to make to my factory, ranked. Started in L2 on Day 1, finished on Day 2 morning, and built from in the three feature labs.

Every row below comes from one autonomous pass through the pipeline: bead `ip-ef6`
("Add a fourth built-in style that belongs alongside the existing three") went
polecat → refinery → architect → refinery → merged to `main`, and closed, without
a human approving anything. That run is the evidence base.

## The layer each change touches

Naming the layer is most of the thinking, because it decides what file you open.

| Layer | You are changing | Shape of the change |
| --- | --- | --- |
| **Pack** | What capabilities exist at all | One `gc import add`, often one of the six options |
| **Agent** | What an agent knows and how it judges | A prompt template, an `agent.toml` |
| **Formula** | What steps a job has and what they depend on | A `*.formula.toml`, often extending an existing one |
| **Order** | When something happens with no human present | An `order.toml` with a `cooldown`, `cron`, `condition` or `event` trigger |

## The map

| Rank | What I want the factory to do | Layer | Why it does not do this today | How I will know it worked | Cost |
| --- | --- | --- | --- | --- | --- |
| 1 | Remove the factory's ability to move `main` at all: publish a pull request and leave the landing to a human | Formula + repo config — default work to `merge_strategy=pr`, then branch protection so "publish" is terminal | The `approval-review` step **already runs** — and the refinery is its own approver (`refinery_approved=true`). On `ip-ef6` it cleared its own checklist, then `direct` mode fast-forwarded to `main`. No installed pack implements the manifest's Gate 2 (a *human* approving a review report); PR mode only produces an artifact that needs a human to finish. And agents push with my credentials, so protection has to bind admins to bind them | Sling a bead: a PR appears, `main` does not move, and a direct push to `main` from an agent worktree is refused | Two half-slots |
| 2 | Refuse a bead that does not say what "done" means, and hand it back naming what is missing, before any implementer sees it | Pack — `bead-gate-rig` (option) | Nothing sits in front of the polecat. `ip-ef6` had a thin description and no acceptance criteria, and went straight to an implementer that invented a style name, a visual concept, and its own definition of correct | Re-sling a bead with no acceptance criteria. It comes back rejected, the feedback names the missing field, and no branch is created | One `gc import add`, one lab slot (the L3 option) |
| 3 | Fail a branch mechanically when it breaks a rule the manifest calls absolute | Formula — a check step in the refinery patrol | Every convention that held on `ip-ef6` held because the polecat imitated the repo, not because anything checked: goldens untouched, `import Testing` over XCTest, Conventional Commit subjects, Jdenticon's colour theme reused. Correct behaviour, zero enforcement | Three throwaway branches, each breaking one rule — a regenerated `goldens.json`, an XCTest import, a non-conventional subject. Each one fails the gate and names which rule | One slot |
| 4 | Produce review verdicts scored against named principles instead of prose judgement | Pack — `principles-loop-rig` (option), plus the three ADRs as project work | There is no `docs/adr/` tree, so the architect reasons from the codebase and its own priors. It did that unusually well on `ip-ef6`, but "unusually well" is not a property you can rely on twice | Architect output cites a numbered principle or ADR per finding, and a change that violates one is rejected with that citation rather than flagged for a human | One slot, plus writing 3 ADRs (`ip-rsd`) |
| 5 | Render its own agent prompts without errors | Pack — fix `setup` and `architect-rig` prompt templates | `propulsion-refinery` and `approval-fallacy-polecat` are undefined, so `{{ template … }}`, `capability-ledger-merge`, `architecture` and `following-mol` render literally. The refinery diagnosed this about itself mid-run. Every result so far was produced by agents running on degraded prompts | `gc lint` reports no template errors for either pack, and `gc prime` output for polecat and refinery contains no literal `{{` | An hour; upstream PR to `sf-tutorial` |
| 6 | Stop binary changes reaching `main` unexamined | Formula — a check step that holds any diff touching a binary path | `ip-ef6` regenerated both preview PNGs, ~29 KB → ~69 KB each, and merged them. It was fine only because the polecat volunteered a byte-identity check on the existing rows and the architect verified the new one by pixel dimensions. Neither was required of them | A branch altering a PNG is held, the binary is named in the report, and the evidence that justifies it is stated rather than optional | Half a slot |
| 7 | Read the evidence it already writes about itself | Order — self-improvement loop (option; a loop, not a pack) | The architect found two manifest-versus-codebase contradictions and recorded them in bead notes. They surfaced only because I went looking. `FACTORY_LOG.md` accumulates order output nobody reads | A scheduled pass surfaces a finding I had not already read, in a place I will see it, without my opening `bd show` | One slot |

Seven rows. Rows 2, 4 and 7 are shipped options; rows 1, 3, 5 and 6 are mine, which is
where the factory stops being the tutorial's and starts being Identikit's.

Row 1 is deliberately not one of the six options, so it does not fit the L3 slot as
written. It is being built as pre-work instead: everything below it is safer to
experiment with once the factory can no longer land its own commits.

## Where these rows came from

- **The gate bounced a bead of mine, and its feedback said:** nothing bounced. That
  is the finding. `ip-ef6` was deliberately under-specified and passed through the
  entire pipeline unchallenged on the question of whether it was answerable. Row 1.

- **A reviewer produced an opinion rather than a verdict, because it had nothing to
  cite:** the architect had to reason about whether a new style needs a golden
  fixture by reading precedent in the codebase, because `PROJECT_MANIFEST.md` says
  every new style carries one while `goldens.json` is read only by
  `JdenticonParityTests` — neither `GitHubStyle` nor `MosaicStyle` has one. It
  reached a defensible answer and escalated rather than guessing. Rows 4 and 7.

- **I read a diff the factory wrote and would have written it differently, because:**
  it regenerated two binary preview sheets that no reviewer can diff (row 6), and it
  edited the README block directly above the wrong "Four built-in renderers" line
  without remarking on it — correct scoping, but it means adjacent defects stay
  invisible unless someone files them (`ip-x04`).

- **Something ran that should not have, or did not run that should have:** the merge
  ran. An approval step *did* fire — `mol-refinery-pr-patrol`'s `approval-review`,
  with the refinery as its own approver — and it cleared. What never ran is the
  manifest's Gate 2, a *human* approving a review report, because no installed pack
  implements it. Two items the architect addressed to me landed on `main` unread.
  Row 1.

## Project work these rows depend on

Not factory changes, so not rows — but row 4 is blocked without the first one.

- **Write the three foundational ADRs** (`ip-rsd`): dependency-free by choice,
  protocol seams for styles and renderers, byte-for-byte Jdenticon parity.
- **Reconcile the two manifest contradictions the architect found.** Decide whether
  a new style must carry a golden (and if so, why `GitHubStyle` and `MosaicStyle`
  do not), and whether "touches the public API" really means an ADR per style when
  the manifest also says the seams exist so new work extends along them. Until these
  are settled, a less careful agent will resolve them by guessing.
- **Fix the README renderer count** (`ip-x04`) — the specified control case, kept
  unslung so there is something to compare a gated run against.

## Out of scope, deliberately

- **Enforcing the `identikit-<feature>` branch convention.** Branch names are
  harness-assigned (`gc-base-factory.furiosa-*`) and not the polecat's choice. The
  manifest is wrong here, not the factory. Fix the manifest.
- **Multi-vendor reviewers** (`multi-vendor-rig`). One reviewer is enough at this
  scale, and the single architect on `ip-ef6` was better than a second opinion would
  have been worth. Revisit if review quality drops.
- **Release tagging and anything deploy-shaped.** SPM distribution means a git tag
  is the closest thing to a deploy, and `burrows` consumes this library. A human
  tags releases.
- **Specialized domain reviewers** (`domain-reviewers-rig`). 20 source files in one
  domain. There are no domains to split.
- **Rig hygiene: `.gc/` and `FACTORY_LOG.md` reaching git.** Already fixed in
  `f196c44`; noted here so it is not re-litigated. The underlying gap — that
  `gc rig add` writes a `.gitignore` block covering only `.beads/*` — is upstream.
