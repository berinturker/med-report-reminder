#!/usr/bin/env python3
"""Fails when a String Catalog entry has no translated Turkish text."""
import json
import sys
from pathlib import Path

CATALOG = Path(__file__).resolve().parent.parent / "MedReport/Resources/Localizable.xcstrings"


def translated(unit):
    return (
        isinstance(unit, dict)
        and unit.get("state") == "translated"
        and bool(str(unit.get("value", "")).strip())
    )


def unit_ok(node):
    """node is a localization of one language: a stringUnit or plural/device variations."""
    if "stringUnit" in node:
        return translated(node["stringUnit"])
    variations = node.get("variations")
    if variations:
        for kind in variations.values():
            for variant in kind.values():
                if not unit_ok(variant):
                    return False
        return True
    return False


def main():
    strings = json.loads(CATALOG.read_text(encoding="utf-8"))["strings"]
    missing = []
    for key, entry in strings.items():
        if entry.get("shouldTranslate") is False:
            continue
        tr = entry.get("localizations", {}).get("tr")
        if tr is None or not unit_ok(tr):
            missing.append(key)
    if missing:
        print("Missing Turkish translation:")
        for key in missing:
            print(f"  {key}")
        sys.exit(1)


main()
