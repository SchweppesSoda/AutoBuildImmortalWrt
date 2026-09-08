# Firmware repository maintenance

- Read `docs/MAINTENANCE.md` before changing the PVE customization.
- `master` is the upstream synchronization baseline; `pve-dual` owns the
  reusable Router/Gateway customization. Keep that division and work in the
  existing appropriate checkout. Do not rename branches or create a worktree
  merely to organize files.
- Check branch, worktree, existing changes and remote status before edits.
  Use one writer per repository; preserve and identify existing changes.
- Keep this public repository generic. No production addresses, inventories,
  credentials, subscription capability URLs or private recovery data.
- Validate changed shell and workflow code, and distinguish static checks,
  successful firmware builds, published releases and imported device images.
- Commit completed changes by function. Push, Release and deployment use
  their own authorization; cleanup alone does not trigger a firmware build.
- Use ignored `.tmp/` for local validation; inspect and preserve recovery
  dependencies outside the repository before removing existing leftovers.
