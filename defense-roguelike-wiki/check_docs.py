"""Check this project's wiki links, required profile locators and source identities."""
from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]
WIKI = Path(__file__).resolve().parent


def main() -> int:
    errors: list[str] = []
    required = ("index.md", "policy.md", "development.md", "visual-direction.md", "workflow.md")
    for name in required:
        if not (WIKI / name).is_file():
            errors.append(f"missing wiki page: {name}")
    links = 0
    for page in WIKI.glob("*.md"):
        for destination in re.findall(r"\]\(([^)]+)\)", page.read_text(encoding="utf-8")):
            destination = destination.strip().strip("<>").split("#", 1)[0]
            if not destination or re.match(r"^[a-z][a-z0-9+.-]*:", destination):
                continue
            target = (page.parent / unquote(destination)).resolve()
            if not target.is_relative_to(ROOT) or not target.exists():
                errors.append(f"invalid link: {page.name}: {destination}")
            links += 1
    profile = (ROOT / "planning/game-workflow-profile.md").read_text(encoding="utf-8")
    settings = {
        "knowledge.enabled": "true",
        "knowledge.projectName": "defense-roguelike",
        "knowledge.root": "defense-roguelike-wiki/",
        "knowledge.indexPath": "defense-roguelike-wiki/index.md",
        "knowledge.policyPath": "defense-roguelike-wiki/policy.md",
        "modelRoutingProfilePath": "planning/model-routing-profile.json",
    }
    for key, value in settings.items():
        row = re.search(r"^\| `" + re.escape(key) + r"` \| ([^|]+)\|", profile, re.MULTILINE)
        if not row or row.group(1).strip() != f"`{value}`":
            errors.append(f"missing or conflicting profile setting: {key}")
    try:
        sources = json.loads((WIKI / "sources.json").read_text(encoding="utf-8"))["sources"]
        if not sources:
            errors.append("source identity list is empty")
        for source in sources:
            path = (ROOT / source["path"]).resolve()
            if not path.is_relative_to(ROOT) or not path.is_file():
                errors.append(f"invalid source: {source['path']}")
            elif hashlib.sha256(path.read_bytes()).hexdigest() != source["sha256"]:
                errors.append(f"source drift: {source['path']}")
    except (OSError, ValueError, KeyError, TypeError) as exc:
        errors.append(f"invalid source manifest: {exc}")
        sources = []
    if errors:
        print("\n".join(errors))
        return 1
    print(f"PASS: {len(required)} required pages, {len(settings)} settings, {links} local links, {len(sources)} source identities")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
