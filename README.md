# AgentMode

A macOS menu bar switch between **human mode** 🧑 (you're at the keyboard) and **agent mode** 🤖 (you're away and an AI agent drives the screen).

Clicking 🧑 switches to agent mode:
- quits distracting apps (configurable; closed politely, never force-quit)
- lowers the display resolution so UI elements are bigger for computer-use agents
- keeps the display awake

Clicking 🤖 switches back: restores your resolution, reopens the apps it closed, and lets the display sleep again. Right-click for a menu.

## Pieces

- `agent-mode`: the script that does the work. `agent-mode on | off | toggle [--by WHO] [--why REASON]`, plus `status`, `presence` and `history`
- `helper.swift`: small CLI for display modes and quitting apps by bundle id
- `main.swift`: the menu bar app, which just runs the script
- `agent-mode presence` reports idle time, lock state, and whether a video or call is holding the display awake, ending in a verdict (`away`, `present`, `busy`, `locked`). Agents can use it to decide whether to take over the screen or ask first.
- Every switch is logged with who did it and why (`agent-mode history`). The right-click menu shows the last few, so when you come back to 🤖 you can see an agent switched while you were away.

## Build

Needs the Xcode command line tools (`swiftc`); no Xcode project.

```sh
./build.sh --install   # links agent-mode into ~/.local/bin, copies AgentMode.app to /Applications
```

Edit the settings at the top of `agent-mode` (apps to close, agent/human resolution). The app registers itself to start at login.

## Notes

Agent mode only helps if the Mac stays unlocked: a locked or sleeping screen is useless to a computer-use agent.
