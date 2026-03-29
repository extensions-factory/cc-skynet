---
name: check-version
description: Display the currently installed version of the Skynet plugin
tools: Read, Grep
---

# check-version

Display the currently installed version of the Skynet plugin.

## Usage

Invoke this skill to verify the installed Skynet version after installation or update.

## Instructions

1. Read `~/.claude/plugins/installed_plugins.json`
2. Find the entry where `name` is `"skynet"` and marketplace is `"cc-skynet"`
3. Extract the `version` field from that entry
4. Display the results in this format:

```
Skynet Version Check
────────────────────
Plugin:      skynet
Marketplace: cc-skynet
Version:     {version from installed_plugins.json}
Registry:    extensions-factory/cc-skynet
Status:      ✓ Installed
```

5. If no matching entry is found in `installed_plugins.json`, report:

```
Status: ✗ Not installed — run the install script or see the install guide
```

## Notes

- This skill reads the LOCAL installed version only
- Remote version comparison is out of scope for this skill
