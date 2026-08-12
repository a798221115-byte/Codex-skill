# Agent routing

## Contents

- 1. Ownership model
- 2. Stage responsibility matrix
- 3. Luna delegation packet
- 4. Parallelism and state safety
- 5. Human gates and external actions
- 6. Completion evidence

## 1. Ownership model

Use one persistent primary Agent as the project orchestrator. It owns the current workflow state, reads user intent, selects the branch, makes judgment calls, integrates worker results, updates the user, and declares completion.

Use the global named custom Agent `Luna` only as a bounded execution worker. The registered Luna configuration is `gpt-5.6-luna` with `model_reasoning_effort=max`. Spawn Luna by its named role so its custom agent file loads; do not silently substitute an inherited or default model.

Do not hand Luna the complete Skill and ask it to finish the project. Give it exactly one stage with explicit inputs and outputs. The primary Agent remains responsible for checking that the stage was allowed to start and deciding whether its result unlocks the next state.

When Luna cannot be spawned, the primary Agent may perform the work directly. Record the actual execution path internally and never describe a main-Agent run as Luna work.

## 2. Stage responsibility matrix

| Stage | Primary Agent responsibility | Luna responsibility | Unlock condition |
| --- | --- | --- | --- |
| Intake routing | Interpret text/link/book/topic input, detect direct-final-script intent, choose branch | Preserve supplied files, initialize folders and metadata after routing is fixed | Intake mode is explicit |
| Link acquisition | Decide whether link verification is required and enforce TikHub-only rule | Download, extract audio, run Whisper, hash and register artifacts | Link-only intake and required credentials exist |
| Text normalization | Decide which corrections are context-supported | Copy verbatim raw text, apply only instructed punctuation/correction rules, compute metadata | Source text is preserved first |
| Reference diagnosis | Judge reusable abstract mechanism, copying risk and unsupported claims | Structure approved findings and write deterministic artifacts when requested | Evidence is available |
| Book identity | Decide whether title/edition confidence is sufficient and resolve ambiguity | Query and normalize WeRead/Douban candidates, dates, identifiers, URLs and covers | Main accepts a unique identity or stops |
| G01 source package | Decide whether evidence is sufficient to lock and whether fallback text is acceptable | Fetch, order and serialize highlights and provenance without changing quotation boundaries | Main locks G01 |
| Derivative copy and O01 | Design narrative, evidence use, emotional line, final wording and accept/reject the originality gate | Run mechanical overlap, length and quotation-boundary checks; execute deterministic Wenpipi comparison and persist report/screenshot | Valid Wenpipi result explicitly says `鉴定结果：原创` |
| G02 | Present copy plus raw O01 similarity/verdict/evidence, explain evidence and process the user's approval or rollback | No user-facing action | O01 passed, then explicit user approval |
| C01 | Decide whether findings block production and what revision is acceptable | Run `media-publish-check`, preserve immutable input and serialize the full report | Main records pass |
| Titles/topics | Choose formula directions, audience promise and recommendation criteria; review the adopted trio | Expand and validate L01–L10, S01–S10 and T01–T10; write complete `titles.json` | C01 passed and G02 approved |
| Selection feedback | Send the complete 10+10+10 list and handle reselection | Return all candidates and validation evidence to main | Candidate file is complete |
| V01 narration | Decide variant only when user overrides the default and approve exceptions | Generate locked narration, measure timing and update voice/recipe/caption timing artifacts | C01 passed and G02 approved |
| Semantic storyboard | Decide segmentation, narrative function, subject need, visual diversity and safe zones | Materialize the approved plan into storyboard JSON and deterministic prompts | Titles and real timing complete |
| G03 style sample | Decide representative frame and accept/reject aesthetic direction | Generate exactly one sample through the configured API kit and run automatic QA | Main accepts a passing sample |
| G04 image batch | Decide which failures require regeneration and inspect the complete set | Generate/edit remaining images, preserve continuity and run required QA | Main presents all images to user |
| G04 | Present all images and process approval or rollback | No user-facing action | Explicit user approval |
| G05 post-production | Decide exceptions and assess final viewing quality | Generate captions, mix audio, render MP4/cover and run technical validation | G04 approved |
| C02 and delivery | Decide whether risk blocks registration and review the final package | Run C02, create manifest and register complete delivery artifacts after a main-recorded pass | Main records pass |
| Draft upload | Confirm explicit draft request and selected account | Execute the exact draft-only adapter call and return evidence | Explicit draft request |
| Formal publication | Obtain account selection and explicit irreversible authorization; verify declaration requirements | Execute only the authorized platform/account/version operations with idempotency | Per-task authorization exists |
| Analytics review | Decide the next creative or operational experiment | Collect 24h/72h/7d snapshots and calculate defined rates | Published record exists |
| Rollback | Explain downstream impact, select retained/superseded artifacts and clear approvals | Perform the specified reversible file/state updates and rerun assigned checks | User confirms rollback scope |

## 3. Luna delegation packet

Every Luna task must include all fields below:

```yaml
agent: Luna
stage: V01-narration-timing
projectDir: <absolute project path>
objective: <one bounded result>
inputs:
  - <absolute input path or immutable state>
allowedWrites:
  - <exact files or directories>
forbidden:
  - <state transitions, user gates, external actions, unrelated files>
requiredReferences:
  - <only the stage-relevant Skill references>
outputs:
  - <required artifacts>
validation:
  - <commands or measurable checks>
return:
  - completed work
  - affected files and counts
  - validation results
  - skipped or ambiguous items
  - decisions required from primary Agent
```

The primary Agent must resolve absolute paths before delegation. Luna must inspect exact sources and targets before writing, preserve unrelated files, and stop rather than inventing missing criteria.

## 4. Parallelism and state safety

After C01 passes, allow exactly these two independent branches to run concurrently:

1. `titles-topics`: candidate expansion, structural validation and `titles.json`.
2. `V01-narration-timing`: voice rendering, measured timing and timing artifacts.

The primary Agent must wait for both, validate their artifacts, and reconcile any changed script/version identifiers before starting the storyboard.

Do not parallelize stages that write the same state or depend on a shared acceptance decision. In particular:

- do not run G03 before both title selection and timing complete;
- do not run remaining images before G03 is accepted;
- do not run post-production before G04 approval;
- do not run C02 before final media and cover validation;
- do not run upload or publication while rollback, C02 or authorization is unresolved.

For the G04 image batch, one Luna worker may manage concurrent provider requests when the configured API kit supports them, but it remains one logical stage and one storyboard version. Preserve deterministic frame IDs and prevent two workers from overwriting the same image or QA record.

## 5. Human gates and external actions

Only the primary Agent may interpret or record:

- G02 copy approval;
- G04 all-image approval;
- ambiguous book identity resolution;
- compliance acceptance or content revision decisions;
- rollback authorization and downstream invalidation;
- draft-upload intent;
- formal publication account selection and irreversible authorization;
- whether a task is complete.

Luna may execute a draft upload or formal publication only after the delegation packet contains the exact authorized platform, account, asset version, metadata version, declaration requirements and idempotency key. It must stop before any unmatched account, unchecked declaration, duplicate risk or unverified publish action.

## 6. Completion evidence

For every Luna stage, the primary Agent must verify:

- the named Luna Agent actually ran with the custom role;
- expected artifacts exist at the declared paths;
- artifact versions match the current script, title, storyboard and media versions;
- required validation passed or failures are explicitly returned;
- Luna did not advance a gate, contact the user, publish externally or modify unrelated state;
- the primary workflow record contains the accepted result before the next stage begins.

Subagent activity alone is not completion. The primary Agent accepts the result only after integrating it into the persistent project state.
