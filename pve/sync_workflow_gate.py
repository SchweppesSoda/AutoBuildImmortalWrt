"""Read-only gate for a candidate Git tree; never push or alter permissions."""
from __future__ import annotations

import argparse
import subprocess


def changed_workflows(base: str, candidate: str, published: str | None = None) -> list[str]:
    paths: set[str] = set()
    for previous in dict.fromkeys(value for value in (base, published) if value):
        result = subprocess.run(
            ["git", "diff", "--name-only", "-z", previous, candidate, "--", ".github/workflows/"],
            check=True, stdout=subprocess.PIPE,
        )
        paths.update(path.decode("utf-8", errors="strict") for path in result.stdout.split(b"\0") if path)
    return sorted(paths)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", required=True)
    parser.add_argument("--candidate", default="HEAD")
    parser.add_argument("--published")
    args = parser.parse_args()
    paths = changed_workflows(args.base, args.candidate, args.published)
    print("manual_required=" + str(bool(paths)).lower())
    if paths:
        print("Workflow changes require a human-reviewed synchronization; no token scope is added.")
        for path in paths:
            print(path)


if __name__ == "__main__":
    main()
