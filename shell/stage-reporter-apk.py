#!/usr/bin/env python3
"""Stage an already checksum-verified reporter APK under its repository filename."""
import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess


def stage(apk: Path, package: Path, destination: Path) -> Path:
    # adbdump reads metadata only: no package install, hooks or repository update.
    result = subprocess.run([str(apk), "adbdump", "--format", "json", str(package)],
                            check=True, capture_output=True, text=True)
    info = json.loads(result.stdout)["info"]
    name, version = info["name"], info["version"]
    if name != "po0-outbound-ip-report" or not isinstance(version, str) or not re.fullmatch(r"[0-9][A-Za-z0-9._+~-]*", version):
        raise ValueError("Unexpected reporter APK identity")
    # ImageBuilder's packages.adb uses APK's default ${name}-${version}.apk.
    target = destination / f"{name}-{version}.apk"
    if target.exists():
        raise ValueError("Reporter APK destination already exists")
    destination.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(package, target)
    return target


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk", type=Path)
    parser.add_argument("package", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    print(stage(args.apk, args.package, args.destination))
