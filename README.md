# shenanigans

Short, empirically-burned **"read before you write X"** notes on the surfaces that fail **silently or
destructively** — where the failure isn't a loud error but a script that ran halfway, a command that
did nothing, or an irreversible action you didn't know you took.

Each file is a fast pre-flight checklist for one tool/surface, written for **coding agents and the
humans who supervise them**. They're deliberately terse: the golden rule up top, then the specific
traps with the minimal fix.

## Why "shenanigans"?

Because these aren't bugs in *your* code — they're the tool doing something surprising *around* your
code. A markdown comment that spams a permanent backlink. A reply that lands under the wrong thread because an array index moved. A `move` that destroys a browser tab. A
zsh loop that silently does nothing. A `pip install -e .` that exits 0 and installs nothing.

Most of these fail *destructively*. One (`claude-code-shenanigans.md`) fails the opposite way — the
command never runs at all, and an overnight agent is still sitting at an approval prompt in the morning.
Same genus: the surprise is in the tool, not your code.

## The files

| File | Read before… |
|---|---|
| [`gfm-shenanigans.md`](gfm-shenanigans.md) | writing any GitHub comment / PR / review / commit message |
| [`github-api-shenanigans.md`](github-api-shenanigans.md) | any scripted GitHub mutation (`gh api`, GraphQL, Octokit) — replying, deleting, addressing objects by id |
| [`git-shenanigans.md`](git-shenanigans.md) | any irreversible git op (branch -D, mass-delete, force-push, rebase) |
| [`shell-shenanigans.md`](shell-shenanigans.md) | writing any shell loop, or a hardware/irreversible script (zsh or bash) |
| [`python-shenanigans.md`](python-shenanigans.md) | writing or installing Python |
| [`cpp-shenanigans.md`](cpp-shenanigans.md) | writing or reviewing C or C++ (undefined behavior a green `-O2` build can hide) |
| [`applescript-shenanigans.md`](applescript-shenanigans.md) | any osascript / AppleScript automation on macOS |
| [`macos-shenanigans.md`](macos-shenanigans.md) | any filename / path / asset check on a Mac that a Linux server will re-run |
| [`claude-code-shenanigans.md`](claude-code-shenanigans.md) | letting an agent run **unattended** — the command shapes that halt it at an approval prompt |

## Using these with an AI coding agent

Point your agent's instructions (e.g. `CLAUDE.md`, `AGENTS.md`) at the relevant file: *"before writing
any shell loop, read `shell-shenanigans.md`."* The value is **zero-recall** — the rule fires when the
agent is about to act, not only if it thinks to look it up.

## Contributing

Hit a silent-or-destructive trap that isn't here? PRs welcome. Keep the shape: **golden rule first,
then the trap + the minimal fix**, and note whether it's empirically reproduced. One file per
tool/surface.

## License

Released under the [MIT License](LICENSE). Copy, adapt, and paste these into your own agent
instructions freely.
