# Workflow-aware upstream synchronization — 2026-09-21

The scheduled upstream merge could include `.github/workflows/` changes that
the repository's `GITHUB_TOKEN` cannot push. The workflow now prepares the
candidate locally and compares workflow paths against both the maintained
base and the published sync branch. Such changes produce an explicit manual
decision, candidate patch and exact commit IDs. No branch push or PR creation
occurs in that path. An unchanged already-current sync branch can still have
its PR opened; ordinary candidates retain the existing force-with-lease and
manual PR-merge behavior. Merge conflicts remain failures, before any push.

The maintained `pve-dual` branch is never automatically merged. No new token,
secret or permission was added. A maintainer reviews the artifact, checks that
the recorded refs still match, then uses their existing authorized identity
to merge/push and open the PR. A successful detection job is **not** evidence
that the upstream update has landed: its manual-required summary is pending
work. The 14-day diagnostic artifact is a proposed CI retention setting that
only takes effect after a separately authorized workflow publication/run.

Four offline local-Git tests cover no change, ordinary updates, workflow
addition/deletion, drift from the published sync branch and invalid refs.
Independent validation also executed the workflow's actual Prepare Bash block
against three disposable Git histories and local bare origins, with external
Git protocols disabled: an ordinary update pushed only to that local origin;
a workflow update preserved the origin ref and produced all three review files;
a real merge conflict returned nonzero before any push. No real repository ref
was changed. Workflow YAML and shell blocks were parsed locally; no GitHub
push, PR, CI run or permission change was performed.
Rollback is a scoped source revert; neither current firmware nor release tags
are altered by this workflow change.
