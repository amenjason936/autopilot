# Independent supplemental review — source 47a89cd

Reviewer: fresh independent forward-testing context. Static inspection only;
no new runtime tests, cloud calls, credential access or candidate edits.

The reviewer compared the candidate against the eleven items under Codex 重审
in the supplied optimization plan and identified these concrete gaps:

1. Evidence header/body/footer writes were unchecked, so an incomplete existing
   partial could be renamed/hashed after a later write failure. The proposed
   detector makes an already-created partial unwritable during a successful gate.
2. Any noninfra nonzero mutant exit could become KILLED without a frozen failure
   signature, including syntax or unrelated dependency errors.
3. The Codex launcher did not enforce a restrictive gate policy; it must enforce
   an equivalent reviewer boundary or park cloud dispatch.
4. Caller-provided record paths could exclude source directories. Exclusions must
   match committed dedicated policy paths. Freshness must cover code/dependencies,
   runners, flags, inputs and environments, not only file names.
5. A one-line authentication/deletion/guard edit could pass the lite threshold.
   Risk admission must keep those changes in full mode.
6. Review results lacked job/base/head/scope/input identity and could be reused
   after structural validation alone.
7. Interrupted side effects lacked a safe/idempotent/receipt prerequisite, and
   publication needed explicit proven/current/blocker admission conditions.

Each failure condition above is an independently identified target. The author
concretized patches for evidence-write refusal, signature binding, record scope,
review identity/policy, risk admission and retry refusal. A source mutation is not
proof of LLM behavior or an external numerical re-rating.

The reviewer recognized the existing pinned worktrees, serialized evidence,
process-group cleanup and Git trust anchors, while retaining these limitations:
deliberately detached descendants, power-loss durability, cross-platform execution
and model prompt-injection robustness were not established by that review.

Follow-up fixes and exact commits/tests belong in VALIDATION.md; this file retains
the findings rather than replacing them with a claim of approval.
