# Configuration reference

A configuration is a plain BASH file in [../configs/](../configs/)
that sets the variables below. You pick one by name, without the `.bash`
extension:

```bash
./window-like-i-want.bash -c myapp     # runs configs/myapp.bash
```

Start by copying [../configs/_config_model.bash](../configs/_config_model.bash).
Names starting with `_` are models: not listed by `--help`, and not runnable.
Worked examples are at the end of this page.

> The file is **sourced**, so it is ordinary BASH and anything you write in it
> runs with your privileges. Only keep configurations you wrote yourself.

---

## Table of contents

- [The application](#the-application)
- [Size](#size)
- [Position](#position)
- [Screen](#screen)
- [Window mode and stacking](#window-mode-and-stacking)
- [Timing](#timing)
- [Debugging and the support notice](#debugging-and-the-support-notice)
- [Worked examples](#worked-examples)

---

## The application

### `APPLICATION_STARTUP_COMMAND` — required

The command that starts your application, written between `BEGIN` and `END`
markers so it can span several lines:

```bash
read -r -d '' APPLICATION_STARTUP_COMMAND << 'HEREDOC'
BEGIN
konsole -p tabtitle="MY MEMORY WATCH" -e "watch -tn 1 free -h" &
END
HEREDOC
```

Two rules:

- **It must end with `&`.** The window is matched by the PID of the process you
  start, and a foreground command never reports one. Without the `&` the run
  stops with *"The application did not report a PID"*.
- **It must be the process that owns the window.** A launcher that hands the
  request to an already running instance, as most browsers do, exits
  immediately and its PID owns nothing.

The `BEGIN`/`END` markers exist so the heredoc can hold blank lines and keep
the configuration readable; they are stripped before the command runs.

> **Do not indent any of it, the `HEREDOC` terminator included.** `<<` (unlike
> `<<-`) only recognises a terminator at column 0. An indented one does not
> close the heredoc at all: it swallows the rest of the file, and every
> variable below is silently left unset.

## Size

### `WINDOW_WIDTH`, `WINDOW_HEIGHT` — optional, integer

The size in pixels.

```bash
WINDOW_WIDTH=563
WINDOW_HEIGHT=440
```

To read the numbers off a window you have already sized by hand, see
[Finding a window's size in pixels](../README.md#finding-a-windows-size-in-pixels).

Leave both empty to let the size be worked out instead:

- if `SCREEN_INDEX` names a screen the window is not already on, the window
  becomes **70% of that screen** in each dimension;
- otherwise the window keeps the size it opened with.

```bash
WINDOW_WIDTH=
WINDOW_HEIGHT=
```

> Setting only one of the two is not useful: as soon as either is set, both are
> taken from the configuration, and the unset one resolves to an invalid size.
> Set both, or neither.

## Position

### `WINDOW_POSITION` — optional, string

Where to put the window, as a short code. There are two families.

**Regular positions** — the window keeps the size decided above and is parked
at one of nine spots:

```
    tld ───────── tc ───────── trd
     │             │             │
     cl ───────── c ─────────── cr
     │             │             │
    bld ───────── bc ───────── brd
```

| Code | Meaning | Code | Meaning | Code | Meaning |
|---|---|---|---|---|---|
| `tld` | Top Left Diagonal | `tc` | Top Centered | `trd` | Top Right Diagonal |
| `cl` | Centered Left | `c` | Centered | `cr` | Centered Right |
| `bld` | Bottom Left Diagonal | `bc` | Bottom Centered | `brd` | Bottom Right Diagonal |

**Docking positions** — the window is tiled against an edge or into a corner by
KWin itself, which **also decides its size**, so `WINDOW_WIDTH` and
`WINDOW_HEIGHT` have no effect:

```
    dtl ───────── dt ───────── dtr
     │                          │
     dl                        dr
     │                          │
    dbl ───────── db ───────── dbr
```

| Code | Meaning | Code | Meaning |
|---|---|---|---|
| `dt` | Docking Top | `db` | Docking Bottom |
| `dl` | Docking Left | `dr` | Docking Right |
| `dtl` | Docking Top Left | `dtr` | Docking Top Right |
| `dbl` | Docking Bottom Left | `dbr` | Docking Bottom Right |

```bash
WINDOW_POSITION="trd"
```

Leaving it empty keeps the position the window opened with, unless
`SCREEN_INDEX` sends it to another screen, in which case it is centred there.

### `WINDOW_X_POSITION`, `WINDOW_Y_POSITION` — optional, integer

Absolute pixel coordinates. **These take precedence over
`WINDOW_POSITION`.**

```bash
WINDOW_X_POSITION=1920
WINDOW_Y_POSITION=0
```

Coordinates are in KWin's combined desktop space, so on a multi-monitor setup
the second screen starts where the first one ends. Leave both empty to use
`WINDOW_POSITION` instead.

> As with the size, set both or neither.

## Screen

### `SCREEN_INDEX` — optional, integer

Which screen to place the window on, **0-based**.

```bash
SCREEN_INDEX=2
```

The order is KWin's own and need not match the arrangement shown in *System
Settings -> Display*. If the window lands on the wrong monitor, try the other
indexes. An index past the last screen is rejected with a message naming the
highest valid one.

Leave it empty to use whichever screen the window opened on.

## Window mode and stacking

### `WINDOW_MODE` — optional, string

| Code | Meaning |
|---|---|
| `mx` | Maximized |
| `mn` | Minimized |
| `fs` | Full Screen |

```bash
WINDOW_MODE="mx"
```

Leave it empty for a normal window. The mode is applied **after** the geometry,
so it wins: `mx` with a `WINDOW_WIDTH` ends up maximized.

### `KEEP_ABOVE` — required, `1` or `0`

Whether the window stays above the others.

```bash
KEEP_ABOVE=0
```

## Timing

### `KWIN_SCRIPT_CONFIGURATION_LATENCY` — required, decimal seconds

How long the generated KWin script stays loaded, waiting for your window to
appear.

```bash
KWIN_SCRIPT_CONFIGURATION_LATENCY=1.0
```

This is the one value worth tuning. The script hooks `workspace.windowAdded`
and is then unloaded; if your application takes longer than this to map its
window, the script is already gone and nothing is configured. A slow starting
application wants `2.0` or more.

It also drives two derived delays:

- the window is hidden while it is moved and faded back in after **a quarter**
  of this value;
- the cleanup trap waits this value **plus 0.5 s** before sweeping up, so an
  interrupted run cannot delete a script that is still being applied.

## Debugging and the support notice

### `KILL_WINDOW_FOR_DEBUG` — optional, `1` or `0`

Closes the window one second after it has been configured. Handy while trying
out positions, since you are not left with a pile of windows.

```bash
KILL_WINDOW_FOR_DEBUG=1
```

Leave it unset or `0` for normal use.

### `ISOLATE_APPLICATION_STATE` — optional, `1` or `0`, default `1`

Keeps what a run does to the window out of your own settings.

```bash
ISOLATE_APPLICATION_STATE=1
```

A toolkit records the size and position of its last window so the next one can
reopen the same way — Konsole writes them to `$XDG_STATE_HOME/konsolestaterc`.
The window this project starts is then resized and moved by KWin, the
application writes **that** down when it closes, and the next window you open
by hand comes up the size this project chose. Your own sizing is silently
replaced.

With this set, the application runs with `XDG_STATE_HOME` pointing at

```
~/.local/state/window-like-i-want/<configuration>/
```

so it still remembers whatever it legitimately wants to between runs of the
same configuration, but shares none of it with the rest of your desktop.

Set it to `0` only if you want the application to share its state normally.

Verified with Konsole and KWrite: in both, the geometry this project imposes
goes to the private directory and the file of the user is left alone. Every KDE
application keeps its window state the same way, in
`$XDG_STATE_HOME/<app>staterc`.

### `I_SUPPORT_FREE_SOFTWARE_N_THIS_WORK` — optional, `1` or `0`

Set to `1` to stop the note printed on every run — a line about the project
and an invitation to get in touch.

```bash
I_SUPPORT_FREE_SOFTWARE_N_THIS_WORK=1
```

## Worked examples

### A terminal at the top right of the third screen

```bash
read -r -d '' APPLICATION_STARTUP_COMMAND << 'HEREDOC'
BEGIN
konsole -p tabtitle="MY MEMORY WATCH" -e "watch -tn 1 free -h" &
END
HEREDOC

WINDOW_WIDTH=563
WINDOW_HEIGHT=440
SCREEN_INDEX=2
WINDOW_POSITION="trd"
WINDOW_MODE=""
KEEP_ABOVE=0
WINDOW_X_POSITION=
WINDOW_Y_POSITION=
KWIN_SCRIPT_CONFIGURATION_LATENCY=1.0
```

### An always-on-top notes pad docked to the right

```bash
read -r -d '' APPLICATION_STARTUP_COMMAND << 'HEREDOC'
BEGIN
kate ~/notes.md &
END
HEREDOC

# Docking lets KWin size the window, so these are left empty.
WINDOW_WIDTH=
WINDOW_HEIGHT=
SCREEN_INDEX=0
WINDOW_POSITION="dr"
WINDOW_MODE=""
KEEP_ABOVE=1
WINDOW_X_POSITION=
WINDOW_Y_POSITION=
KWIN_SCRIPT_CONFIGURATION_LATENCY=2.0
```

### A fullscreen player at an exact spot, slow to start

```bash
read -r -d '' APPLICATION_STARTUP_COMMAND << 'HEREDOC'
BEGIN
mpv --player-operation-mode=pseudo-gui &
END
HEREDOC

WINDOW_WIDTH=1280
WINDOW_HEIGHT=720
SCREEN_INDEX=
WINDOW_POSITION=
WINDOW_MODE="fs"
KEEP_ABOVE=0

# Absolute coordinates win over WINDOW_POSITION.
WINDOW_X_POSITION=320
WINDOW_Y_POSITION=180

# mpv can take a while to show up.
KWIN_SCRIPT_CONFIGURATION_LATENCY=3.0
```

---

## Validation

The values are validated on the KWin side, in
[../kwin-script/src/settings/script-settings.ts](../kwin-script/src/settings/script-settings.ts),
and a bad one aborts with a message in the journal rather than a half-placed
window:

```bash
journalctl --user -f -t kwin_wayland   # or kwin_x11
```

Look for the `[WINDOW_LIKE_I_WANT <config> <uuid>]` prefix.

| Variable | Rule |
|---|---|
| `WINDOW_WIDTH`, `WINDOW_HEIGHT` | a non-negative integer, if set |
| `WINDOW_X_POSITION`, `WINDOW_Y_POSITION` | a non-negative integer, if set |
| `SCREEN_INDEX` | a non-negative integer below the number of screens |
| `WINDOW_POSITION` | one of the regular or docking codes |
| `WINDOW_MODE` | `mx`, `mn` or `fs` |
| `KEEP_ABOVE` | `1` enables it; anything else disables it |
