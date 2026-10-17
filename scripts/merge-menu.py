#!/usr/bin/env python3
"""Add the Obrii entry to the Omarchy menu if it is not there yet.

Omarchy merges a single additive file,
~/.config/omarchy/extensions/omarchy-menu.jsonc, over the stock menu. There is
no drop-in directory, so the entry has to be inserted into that file. The file
is JSONC (comments allowed), so this script inserts before the final closing
brace instead of parsing and rewriting it, which would drop the comments.

If the key already exists it is left untouched: a user who renamed the entry
keeps their label.
"""
import os
import sys
from pathlib import Path

KEY = '"style.wallpaper-editor"'
ENTRY = """  "style.wallpaper-editor": {
    "icon": "",
    "label": "Obrii",
    "aliases": ["obrii", "wallpaper-editor", "шпалери", "редактор шпалер"],
    "action": "omarchy-shell shell summon elinchi.wallpaper-editor '{}'"
  }"""


def menu_path():
    config_home = os.environ.get("XDG_CONFIG_HOME") or (Path.home() / ".config")
    return Path(config_home) / "omarchy" / "extensions" / "omarchy-menu.jsonc"


def main():
    path = menu_path()
    path.parent.mkdir(parents=True, exist_ok=True)

    text = path.read_text(encoding="utf-8") if path.exists() else "{\n}\n"

    if KEY in text:
        print(f"Obrii menu entry already present in {path}; left unchanged")
        return 0

    closing = text.rfind("}")
    if closing == -1:
        print(f"Could not find the closing brace in {path}; add the entry manually", file=sys.stderr)
        return 1

    before = text[:closing].rstrip()
    after = text[closing:]

    if before.endswith("{") or before.endswith(","):
        separator = "\n"
    else:
        separator = ",\n"

    updated = before + separator + ENTRY + "\n" + after

    if path.exists():
        backup = path.with_name(path.name + ".bak.obrii")
        backup.write_text(text, encoding="utf-8")
        print(f"backup: {backup}")

    tmp = path.with_name(path.name + ".obrii-tmp")
    tmp.write_text(updated, encoding="utf-8")
    tmp.replace(path)
    print(f"added the Obrii menu entry to {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
