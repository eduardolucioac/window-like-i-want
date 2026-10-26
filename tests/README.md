# Testing window-like-i-want

The project's output is a side effect inside a running compositor, which is
awkward to assert on. It splits cleanly into two halves, though, and each one
can be tested properly.

```bash
./tests/test-bash-side.bash      # anywhere, no KWin needed      (~15 s)
./tests/test-kwin-side.bash      # needs a live KWin session      (~45 s)
./tests/test-kwin-side.bash --all   # and the 8 docking positions (~80 s)
```

Both exit 0 only if everything passed, so either drops into a hook or a CI job.

Both also set **`WLIW_NO_DIALOG=1`**. A dialog waits for a key press, so one
opened by an unattended run is never closed; the headless suite has no business
opening a window at all. With the variable set the message still goes to
stderr, which is what the assertions read, and
[preview-dialogs.bash](preview-dialogs.bash) is where the dialogs are looked
at on purpose.

---

## Layer 1 — the BASH half, headless

[test-bash-side.bash](test-bash-side.bash) — **30 assertions, no display, no
D-Bus, no KWin.**

What makes this possible is the `--dry-run` flag: the project does everything
it normally would — parses the options, loads the configuration, substitutes
the run's values into the compiled KWin bundle, writes the result — but never
starts the application and never talks to KWin. It prints where it put the
generated script, and the test then reads it.

```bash
$ ./window-like-i-want.bash -c myapp --dry-run
CONFIGURATION TO USE: myapp
DRY RUN: KWin script written to "/tmp/3871187d-....js" and NOT loaded.
```

It covers:

| Group | What it checks |
|---|---|
| Command line | `--help` exits 0 and lists the configurations; a missing, empty or unknown `-c` fails; unknown options fail; four path traversal attempts are refused |
| Configuration model | every variable below its heredoc is actually set, and its command runs in the background |
| Dry run | the script is generated, is valid JavaScript, has no placeholder left over, carries the configured values, has its `BEGIN`/`END` markers stripped, and starts nothing |
| Validation | an empty startup command fails; an unset latency warns and defaults |
| Build artefacts | the bundle is present, and **every `$placeholder` in it has a matching `local` in `window.bash`** |
| Shell hygiene | every BASH file parses, with no warnings |

Two of those earn their keep:

- **Placeholder matching.** The compiled bundle carries `$placeholder` strings
  that BASH substitutes through a heredoc. Add one to `main.ts` and forget the
  matching `local` in `c_window.f_prepare_configuration` and BASH expands it to
  the **empty string** — the value silently becomes `""` and KWin misbehaves
  with no useful message. The test compares the two sides directly. (Verified
  by deleting a `local` and watching it fail.)
- **No parser warnings.** `bash -n` reports an unterminated heredoc as a
  *warning* while still exiting 0, which is exactly how the indented heredoc in
  the bundled configuration stayed hidden while silently swallowing 83 lines
  of the file.
  Any warning is treated as a failure.

Every test runs the project from an unrelated working directory, so a path
that accidentally goes back to being resolved against `$PWD` fails immediately.

## Layer 2 — the KWin half, against a live session

[test-kwin-side.bash](test-kwin-side.bash) — **real geometry assertions.**

This is the half that cannot be faked, and it turns out it does not have to be.
KWin scripts can `print()`, and that lands in the user journal, which gives a
full observability channel with no extra tooling, on both X11 and Wayland:

```
                 ┌─────────────────────────────────────────┐
  the test ──1──▶│ window-like-i-want -c <generated config>│
                 └─────────────────────────────────────────┘
                                  │ places a konsole whose
                                  │ tabtitle is a unique marker
                                  ▼
                 ┌─────────────────────────────────────────┐
  the test ──2──▶│ a probe KWin script, loaded over D-Bus  │
                 │  . find the window whose caption         │
                 │    contains the marker                   │
                 │  . print() its frameGeometry             │
                 └─────────────────────────────────────────┘
                                  │
                                  ▼
  the test ──3──▶  journalctl --user   ──▶  x, y, width, height
                                  │
                                  ▼
                 compare with the rectangle recomputed
                 independently, in BASH, from the screen geometry
```

**The expected rectangles are recomputed in the test, not taken from the
TypeScript.** A test that reuses the implementation it is testing only proves
the code agrees with itself; an independent reimplementation of
`window-position.ts` catches a wrong formula.

It covers the 9 regular positions exactly, the 8 docking positions loosely
(see below), absolute `WINDOW_X/Y_POSITION` precedence, `WINDOW_MODE=fs`,
whether anything was left loaded in KWin or left behind in `/tmp`, and whether
an invalid position code is reported rather than silently applied.

```bash
./tests/test-kwin-side.bash --screen 1      # pick the screen
./tests/test-kwin-side.bash --only trd,c    # just these codes
./tests/test-kwin-side.bash --all           # include docking
```

It skips cleanly, exit 0, when there is no `qdbus`, no `org.kde.KWin` on the
session bus, no readable journal, or no `konsole`.

> **It opens and closes a real window per case, on your actual desktop.** It is
> quick, but it is visible. Do not run it in the middle of something.

### Two things it taught us

**Geometry is fractional on scaled outputs.** KWin reports *logical* pixels, so
on a 1.5x display a window asked to be 823 wide comes back as
`823.3333333333335`. BASH arithmetic rejects that outright. Every value read
from KWin is rounded, and compared with a 2 px tolerance — a fractionally
scaled output simply cannot represent an arbitrary logical size exactly.

**Docking cannot be asserted exactly.** KWin decides the size when it tiles,
and it works off the *available* area rather than the full screen, so a panel
changes the answer. Those cases only assert which edge or corner the window
was tiled against, which is robust and still catches a wrong `slot*` call.

## Layer 3 — your eyes

Some things no assertion will catch: whether the fade-in is smooth, whether the
window flickers at its old position first, whether the right monitor *feels*
right, whether a colour scheme is readable.

### The dialogs

[preview-dialogs.bash](preview-dialogs.bash) opens them on demand:

```bash
./tests/preview-dialogs.bash                 # all four, one at a time
./tests/preview-dialogs.bash warning         # just one
./tests/preview-dialogs.bash --all-at-once   # all four, cascaded
```

This matters because only the **error** dialog is ever reached in normal use,
and only when something has already gone wrong. The other three colour schemes
ship with the project and had never been seen.

It is also what the dialog defects were found with. The worst of them was
invisible from inside the project: Konsole records its last window size in
`~/.local/state/konsolestaterc`, so a dialog forced to 40% of the screen
**replaced the size the user had chosen for their own Konsole windows**. Each
dialog now runs with a private `XDG_STATE_HOME`, and
`test-bash-side.bash` asserts it.

The others: Konsole's toolbar showing through (`--hide-menubar` does not hide
it; `--hide-toolbars` does), and the drawing breaking up. The drawing is now a
block with no side borders, at a **fixed** width of 72 dashes, and the window
is sized to fit it — so there is nothing to measure and nothing to misalign.

It goes through the real code path — the same `f_define_color_scheme`,
`f_dialog_runtime_prepare`, `c_dialog.f_start_dialog` and
`c_dialog.f_configure_dialog` the project calls — so what you see is what a
user would see. Each dialog waits for a key press; the next opens once you
close the previous one.

`--all-at-once` cascades them, because the dialog KWin script centres every
dialog and they would otherwise land exactly on top of each other, showing only
the last. Cascaded, the four schemes sit side by side for comparison.

### The window positions

For those, step through the codes by hand:

```bash
for code in tld tc trd cl c cr bld bc brd ; do
    sed -i "s/^WINDOW_POSITION=.*/WINDOW_POSITION=\"$code\"/" configs/myapp.bash
    echo "=== $code ==="
    ./window-like-i-want.bash -c myapp
    sleep 3
done
```

with `KILL_WINDOW_FOR_DEBUG=1` in the configuration so each window closes
itself.

---

## A wrong bug report, and what caused it

Worth keeping, because the lesson is about this harness rather than about the
project.

The suite was at one point reported as exposing a real defect: *"an
application's remembered size beats the KWin script — the first run after the
remembered size stops matching the configuration gets the right position and
the wrong size, and the next run passes."* It looked convincing. It was
reproducible. **It was not true.**

What actually happened was a bug in this file. Every geometry read tagged its
probe output with the same shared string, and the journal was then searched for
that tag with `tail -1`. When the current window was *not* found, the search
still matched a line from an **earlier** measurement that was within the journal
window being searched, and the test happily compared against the geometry of a
different window. The stale value came from whatever had been placed before,
which is why the symptom correlated so neatly with "the previous run used a
different size".

Instrumenting the compositor is what settled it. A script that mimics the
project and samples `frameGeometry` over time shows the assignment landing and
staying put:

```
EXP antes_de_setar   4305,320 563x440      <- the application's own geometry
EXP logo_apos_setar  4305,320 563x440      <- assignment has NOT taken effect yet
EXP t=50ms           3627,0   823x617      <- it has now
EXP t=150ms          3627,0   823x617
...
EXP t=4000ms         3627,0   823x617      <- and it stays
```

Two things come out of that, both real:

- **`frameGeometry` assignment is asynchronous.** Reading it back on the very
  next line still returns the old rectangle. Anything that sets it and then
  verifies it immediately will be wrong.
- **The application does not fight back.** Konsole does not restore its
  remembered size afterwards, and the geometry sticks indefinitely.

Each read is now tagged with the window's own unique marker, and the probe
prints an explicit `NOT_FOUND` so a missing window can never be mistaken for a
stale reading. A warm-up placement that had been added to "stabilise" the suite
was removed along with the imaginary defect it was hiding.

## Not every application can be placed

Worth knowing before blaming the project. On Wayland the **client** has the
final say over the size of its own surface; KWin can ask, but it cannot compel.
Tested here:

| Application | Position | Size | Notes |
|---|---|---|---|
| `konsole` | applied | applied | the project's own example; the geometry sticks |
| `alacritty` | **ignored** | **ignored** | left at KWin's default placement every time |

For alacritty the PID match is not the problem — a probe confirmed the window's
`pid` equals the one the project captured, so the script found the window and
alacritty simply refused what it was told. An application that sizes and places
itself cannot be targeted this way at all.

That is why these tests use `konsole`: it is the project's own example, and it
is known to accept the geometry.

## What is not covered

- **Only one monitor layout** — the author's, with three screens, one of them
  fractionally scaled. The screen-index logic in `defineScreenIndexNPosition`
  has several branches that depend on which screen the window opened on, and
  those are not exercised.
- **The error dialogs.** `dialog.bash` spawns a Konsole and has KWin centre it.
  Nothing asserts on it; it has only been eyeballed, and its text verified by
  rendering it with the dialog call stubbed out.
- **X11.** Only `kwin_wayland` was available. The journal mechanism is
  session-agnostic, but the geometry behaviour may not be.
- **The TypeScript in isolation.** There are no unit tests for
  `ScriptSettings`, `WindowPosition` and friends. They only run inside KWin,
  so testing them directly would need the KWin globals stubbed — worth doing,
  and `tsconfig.json` is already set up for it.
