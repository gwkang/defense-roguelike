"""Resolve a portable capability tier against a project model profile."""
from __future__ import annotations

import argparse
import json
from pathlib import Path


TIERS = ("highest-judgment", "complex-execution", "balanced-execution", "high-volume")
EFFORTS = {"low", "medium", "high", "xhigh", "max", "ultra"}


class ProfileError(ValueError):
    pass


def load_profile(path):
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    if not isinstance(data, dict) or not {"schemaVersion", "revision", "tiers"} <= set(data):
        raise ProfileError("profile requires schemaVersion, revision and tiers")
    if data["schemaVersion"] != 1 or not isinstance(data["revision"], str) or not data["revision"]:
        raise ProfileError("unsupported model-routing profile")
    if not isinstance(data["tiers"], dict) or set(data["tiers"]) != set(TIERS):
        raise ProfileError("profile must define exactly the four capability tiers")
    for tier, row in data["tiers"].items():
        if not isinstance(row, dict) or set(row) != {"preferredModels", "reasoningEffort"}:
            raise ProfileError(f"invalid tier row: {tier}")
        models = row["preferredModels"]
        if (not isinstance(models, list) or not models or
                any(not isinstance(model, str) or not model for model in models) or
                len(models) != len(set(models))):
            raise ProfileError(f"invalid preferredModels: {tier}")
        if row["reasoningEffort"] not in EFFORTS:
            raise ProfileError(f"invalid reasoningEffort: {tier}")
    return data


def resolve(profile, tier, available_models, override_supported, explicit_model=None):
    available = set(available_models)
    if explicit_model:
        if not override_supported:
            return {"decision": "blocked", "capabilityTier": tier, "reasoningClass": None,
                    "resolvedModel": None, "resolutionSource": "explicit-user",
                    "overrideSupported": False, "fallbackReason": "explicit-model-override-unsupported"}
        if explicit_model not in available:
            return {"decision": "blocked", "capabilityTier": tier, "reasoningClass": None,
                    "resolvedModel": None, "resolutionSource": "explicit-user",
                    "overrideSupported": True, "fallbackReason": "explicit-model-unavailable"}
        return {"decision": "override", "capabilityTier": tier, "reasoningClass": None,
                "resolvedModel": explicit_model, "resolutionSource": "explicit-user",
                "overrideSupported": True, "fallbackReason": None}

    row = profile["tiers"][tier]
    if not override_supported:
        return {"decision": "host-default", "capabilityTier": tier,
                "reasoningClass": row["reasoningEffort"], "resolvedModel": "host-default",
                "resolutionSource": "host-default", "overrideSupported": False,
                "fallbackReason": "model-override-unsupported"}
    selected = next((model for model in row["preferredModels"] if model in available), None)
    if selected is None:
        return {"decision": "host-default", "capabilityTier": tier,
                "reasoningClass": row["reasoningEffort"], "resolvedModel": "host-default",
                "resolutionSource": "host-default", "overrideSupported": True,
                "fallbackReason": "no-tier-candidate-available"}
    preferred = row["preferredModels"][0]
    return {"decision": "override", "capabilityTier": tier,
            "reasoningClass": row["reasoningEffort"], "resolvedModel": selected,
            "resolutionSource": "profile-tier", "overrideSupported": True,
            "fallbackReason": None if selected == preferred else "preferred-model-unavailable"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("profile", type=Path)
    parser.add_argument("--tier", choices=TIERS, required=True)
    parser.add_argument("--available-model", action="append", default=[])
    parser.add_argument("--override-supported", action="store_true")
    parser.add_argument("--explicit-model")
    args = parser.parse_args()
    try:
        result = resolve(load_profile(args.profile), args.tier, args.available_model,
                         args.override_supported, args.explicit_model)
        print(json.dumps(result, ensure_ascii=False, indent=2))
        raise SystemExit(2 if result["decision"] == "blocked" else 0)
    except (ProfileError, OSError, json.JSONDecodeError, KeyError) as exc:
        parser.exit(1, f"{exc}\n")


if __name__ == "__main__":
    main()
