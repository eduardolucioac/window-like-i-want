# Changelog

## 2026-10-21 — `json-like` split out, bugs fixed, project documented

Backups of every file replaced in this round are kept beside the originals as
`*_BAK_20261021.1638.0`.

### `json-like` moved out into its own project

[bash-script/utils/](bash-script/utils/) carried a general purpose nested data
structure library, `json-like`, plus its AWK back end, its test suite and a
try/catch helper. **Nothing in this project used it:** the entry point does not
source it, and there was not a single `json_like.*` call outside the library and
its own tests.

It was moved to [../json-like](../json-like), together with its history and the
`docs/json-like.md` reference, which became that project's README. Removing it
cost this project nothing and took about 90 KB of unused code and a whole
reference document out of the repository.

`awk` is still a requirement here, but for the decimal latency arithmetic in
[bash-script/window/window.bash](bash-script/window/window.bash) and
[bash-script/trap/trap.bash](bash-script/trap/trap.bash), not for `json-like`.

### `window-like-i-want` — the main flow

1. **Two paths were resolved against the current working directory**, so the
    project only worked when started from its own folder:
    `./kwin-script/dist/window.js` in
    [bash-script/window/window.bash](bash-script/window/window.bash) and
    `./your-configs/...` in
    [bash-script/options/options.bash](bash-script/options/options.bash). Both
    now use `$SCRIPT_DIRECTORY`.

2. **A successful run always ended with an error dialog.**
    `f_error_handling` was called unconditionally at the end of
    `f_controller`. It now takes a message and is reached only from a failed
    step. Its body was also a copy of the support notice; it now says what
    went wrong, wrapped to the box width with `printf` rather than through
    heredoc backslash escaping, which is what had the ASCII art misaligned by
    one column.

3. **The hide/show latency was always 0.**
    `c_window.f_prepare_configuration` assigned the default only when the
    configuration left the value empty, with no `else`, so when it *was* set
    the local stayed empty and `(a * 1000) / 4` was computed from `""`.

4. **Failures fell through silently.** `f_controller` ignored the return code
    of every step, so a failed start or a KWin that refused the script left the
    run going. Each step is now checked and reports what failed; the steps
    themselves return non-zero and check their own preconditions — a missing
    bundle, a missing `qdbus`, an empty command, a command that reported no PID
    (the `&` mistake), a `loadScript` or `start` that KWin rejected.

5. **`options.bash` cleanups.** It printed a profane debug line on the success
    path; it named an undefined `$file` in its error message; `-h` exited `1`;
    a missing `-c` was not detected, so the run continued and failed later
    sourcing a nonexistent config. It now validates, rejects a configuration
    name containing `/` or `..`, lists the available configurations in `--help`,
    and exits `0` for `-h`.

6. **The example configuration was broken, and silently.**
    In [your-configs/sensors.bash](your-configs/sensors.bash) the heredoc body
    and its `HEREDOC` terminator were indented. `<<` — unlike `<<-` — only
    recognises a terminator at column 0, so the heredoc **never closed** and
    swallowed the remaining 83 lines of the file. The effect:

    - `SCREEN_INDEX`, `WINDOW_POSITION`, `WINDOW_MODE`, `KEEP_ABOVE`,
      `WINDOW_X_POSITION`, `WINDOW_Y_POSITION`,
      `KWIN_SCRIPT_CONFIGURATION_LATENCY`, `KILL_WINDOW_FOR_DEBUG` and
      `I_SUPPORT_FREE_SOFTWARE_N_THIS_WORK` were **all unset**, so none of them
      ever reached the KWin script;
    - `APPLICATION_STARTUP_COMMAND` held the rest of the file, and
      `f_start_application` `eval`'d it.

    `bash -n` had been reporting this as *"here-document at line 17 delimited
    by end-of-file"*. Un-indented, with a comment explaining why it has to stay
    that way.

7. **An unset latency reached `sleep` as `sleep ""`.**
    `f_class_constructor` treats a required attribute as satisfied by an empty
    string — which is correct, since `WINDOW_MODE=""` is a legitimate value — so
    the empty latency from (31) passed validation. `f_controller` now warns and
    falls back to `1.0`.

8. **`qdbus` is not called `qdbus` on Plasma 6, so nothing worked at all.**
    Every D-Bus call was hardcoded to `qdbus`. Qt 6 renames the tool: on
    Arch based systems (CachyOS included) the only copy on `PATH` is
    **`qdbus6`**, and the unsuffixed one sits in `/usr/lib/qt6/bin`, which is
    not on `PATH`. On the development machine for this project
    `command -v qdbus` finds nothing, so **every run failed** at
    `loadScript`.

    New [bash-script/utils/qdbus.bash](bash-script/utils/qdbus.bash) resolves
    the binary once into `$QDBUS_COMMAND`, trying `qdbus6`, `qdbus-qt6`,
    `qdbus`, `qdbus-qt5` and then four known libexec paths. All six call sites
    in [window.bash](bash-script/window/window.bash),
    [dialog.bash](bash-script/dialog/dialog.bash) and
    [trap.bash](bash-script/trap/trap.bash) now go through it, and it is sourced
    first in [window-like-i-want.bash](window-like-i-want.bash).

9. **The error dialog could itself collapse into raw shell errors.**
    `c_dialog.f_configure_dialog` called `qdbus` unguarded, so when D-Bus was
    the thing that had failed, the dialog reporting it printed three
    `qdbus: command not found` lines of its own. The D-Bus part only *centres*
    the dialog, so it is now skipped on failure: the Konsole window still
    appears, just wherever the window manager puts it.

### Dialogs

16. **Every dialog announced itself as an error.** The Konsole tab title was
    hardcoded to `"WINDOW-LIKE-I-WANT ERROR"` in `c_dialog.f_start_dialog`,
    regardless of type, so an informational or warning dialog would have been
    titled `ERROR`. New `f_define_dialog_title` maps the type to its title,
    the way `f_define_color_scheme` already mapped it to its colours.

17. **A leftover colour scheme link broke the colours, silently.**
    `f_set_color_scheme` used a bare `ln -s`, which fails with `File exists`
    when a link is left behind by an interrupted run; the dialog then opened
    with Konsole's default colours and nothing said why. It also assumed
    Konsole's data directory existed. Now `mkdir -p` and `ln -sf`, both
    checked.

18. **The three non-error dialogs had never been seen.** Only `error` is
    reached in normal use, so the `info`, `success` and `warning` colour
    schemes shipped unexercised. New
    [tests/preview-dialogs.bash](tests/preview-dialogs.bash) opens any of them
    on demand, through the real code path.

19. **The dialog content wrapped, and became unreadable.** The box was drawn
    ahead of time at a fixed 73 columns, but the dialog window is sized as a
    fraction of the screen, so whether 73 columns fitted depended on the font
    size and the display scaling. When it did not, EVERY line wrapped: the
    borders ended up on lines of their own and the box fell apart.

    New [bash-script/dialog/dialog-box.bash](bash-script/dialog/dialog-box.bash)
    draws the box from **inside** the dialog, against the width that terminal
    reports (`tput cols`), clamped to a sensible range. `f_show_dialog` now
    takes plain text and the box is built around it at display time, so the
    question of whether it fits cannot arise.

20. **Konsole's toolbar was showing in the dialogs.** The dialog passed
    `--hide-menubar --hide-tabbar`, but modern Konsole keeps a toolbar (New
    Tab, Split View, Copy, Paste, Find, and a hamburger menu) regardless.
    `--hide-toolbars` exists and is now passed as well.

21. **An empty startup command crashed the marker stripping.** The `BEGIN` and
    `END` markers around `APPLICATION_STARTUP_COMMAND` were removed by counting
    bytes off both ends (`${var:6:-4}`). With nothing between the markers the
    count went negative and BASH failed with `substring expression < 0`,
    instead of the empty-command error that was meant to fire. The markers are
    now matched rather than counted.

22. **The dialogs changed the size of the user's own Konsole windows.**
    Konsole records the size of its last window in
    `~/.local/state/konsolestaterc`, keyed by the screen layout. The dialog
    was forced to 40% of the screen by its KWin script, Konsole wrote that
    down, and the next Konsole the user opened came up at the size of our
    dialog — their own sizing silently replaced.

    Each dialog now runs with `XDG_STATE_HOME` and `XDG_DATA_HOME` pointing
    into a private directory of its own, which it removes when it closes.
    Nothing it does reaches the profile of the user.

23. **The dialog stopped linking files into the Konsole directory of the
    user.** The colour scheme used to be symlinked into
    `~/.local/share/konsole` and deleted afterwards — by name, so a file of
    the user with the same name would have been removed. The scheme now lives
    in the private directory above, and
    [bash-script/trap/trap.bash](bash-script/trap/trap.bash) no longer deletes
    anything from there.

24. **The box wrapped on the first showing and not the second.** The shell
    inside the dialog measured the terminal (19) at startup, but the KWin
    script then resized the window to 40% of the screen: the box was drawn for
    one width and displayed at another. Whether it happened depended on the
    size Konsole restored from (22), which is why running the dialogs twice
    "fixed" it.

    The dialog now asks Konsole for exactly the columns and rows its content
    needs, so the window already fits when it appears, and
    [dialog.js](bash-script/dialog/kwin-script/dialog.js) only CENTRES it
    rather than resizing it. As a side effect the window is no longer mostly
    empty space.

25. **A nameref was shadowed by a local of the same name.**
    `f_dialog_runtime_prepare` wrote its result through a nameref while also
    holding a local called `runtime_directory`; a caller using that same
    variable name got an empty string back and no error. Found by the test
    written for (22). The internal names now carry the same suffix the nameref
    does, which is what that convention is for.

26. **The box did not follow the window when it was resized.** It was drawn
    once, at whatever width the dialog opened with. Widen the window and a
    band of dead space appeared to the right of the box; narrow it and every
    line wrapped again.

    The dialog now redraws on `SIGWINCH`, so the box tracks the window: wider
    and it widens, narrower and the text re-wraps.

27. **BASH does not run a trap while it is blocked inside `read`.** The first
    attempt at (26) installed the `SIGWINCH` trap and then waited for a key
    with a plain `read -n1`. The trap never fired: it was dead code. The wait
    is now `read -n1 -t 1`, which returns every second and lets a pending trap
    run. Proven in isolation: with the timeout the handler fires and redraws at
    the new width, without it nothing happens at all.

    > The box is still capped at `_DIALOG_BOX_MAX_TOTAL` (100 columns), on
    > purpose — past that the lines get hard to follow. Widening a dialog
    > beyond that leaves space to the right by design.

28. **The font property value repeated the property name.** The dialog passed
    `-p Font="Font=Monospace,12,..."`. Konsole tolerates it — measured: the
    window comes out the same size either way — but it reads as a mistake and
    invited one. Now `-p Font="Monospace,12,..."`.

    What the font is actually for was measured too, since it is easy to assume
    the wrong thing. Asking Konsole for 42 columns and changing only the font:

    | font | window width | per column |
    |---|---|---|
    | `Monospace,14` | 475 px | 11.3 px |
    | `DejaVu Sans,14` (proportional) | 690 px | 16.4 px |

    Konsole sized **both** windows to exactly 42 columns: it derives one fixed
    cell width per font and lays everything out on that grid. So the box
    borders line up whatever the font is; a proportional one only makes the
    glyphs sit badly inside their cells. The font is about legibility. What
    decides whether the box FITS is the column count, which is pinned
    separately.

29. **The dialog is 82 columns wide**, giving an 81 wide box, at the request
    of the author. It was 74/73 before. The error message now fits on a single
    line instead of wrapping.

29. **The box lost its side borders.** It is now rules across the top, the
    middle and the bottom, with everything else simply indented:

    ```
     ------------------------------------------------------------------------
       WINDOW-LIKE-I-WANT ERROR
     ------------------------------------------------------------------------
       Unable to load the KWin script through D-Bus. Is this a KWin session?
    ```

    This is what finally settles the formatting, and it settles it by removing
    the problem rather than managing it. A bordered box has to end every line
    in exactly the right column, so anything that changes a line's length
    breaks the drawing. With no right hand border there is nothing to line up
    against: a line that comes out long simply wraps, like any other text.

    The test invariant changed with it, from "every line is exactly the
    requested width" to "no line exceeds it".

30. **The support notice is drawn the same way.** `f_ask_support` carried its
    own hand drawn box of a fixed 73 columns inside a HEREDOC, carved out with
    `${ASK_SUPPORT:6:-3}` — the same magic offsets as (21), and the same
    breakage in a narrow terminal. It now uses the shared helpers and follows
    the width of the terminal it is printed into. Its address also moved onto
    a line of its own: wrapped narrow, `( url ).` came out as three lines, and
    brackets stop some terminals making an address clickable.

31. **`f_dialog_box_show` clears the scrollback too.** `\033[2J` erases only
    what is currently visible, so whatever the previous drawing had pushed
    above the top of the window stayed in the scrollback and reappeared as a
    stray duplicate of the heading. It now sends `\033[H\033[2J\033[3J`.

32. **The width is fixed: a rule is 72 dashes, always.** It was derived from
    the terminal, so the same message came out differently depending on the
    size of the window and the font — the very moving target the shape in (29)
    was chosen to be rid of. One number now drives everything:

    ```bash
    _DIALOG_BOX_RULE=72
    _DIALOG_BOX_TOTAL=$((_DIALOG_BOX_RULE + 1))   # 73
    _DIALOG_BOX_TEXT=$((_DIALOG_BOX_TOTAL - 3))   # 70
    ```

    The dialog asks Konsole for `_DIALOG_BOX_TOTAL + 1` columns, so a full
    width rule cannot reach the last column, which is where some terminals
    wrap.

33. **The machinery that existed only to measure the terminal is gone.**
    `f_dialog_box_detect_width`, `f_dialog_box_set_width`, the minimum, maximum
    and fallback widths, and `_DIALOG_PREFERRED_COLUMNS` all went with it, and
    so did the `SIGWINCH` redraw of (26)/(27) and the timed `read` it needed:
    with a fixed width there is nothing to redraw. A test now fails if anything
    goes back to asking the terminal how wide it is.

34. **A run replaced the window size the user had chosen.** The same defect as
    (22), but through the LAUNCHED application rather than the dialog: Konsole
    records the size of its last window in `$XDG_STATE_HOME/konsolestaterc`,
    this project resizes that window through KWin, and the application writes
    the new size down when it closes. The next Konsole opened by hand came up
    563x440.

    Reproduced: a manual `954x623` became `563x412` after one
    `-c sensors`. The application now runs with `XDG_STATE_HOME` pointing at
    `~/.local/state/window-like-i-want/<configuration>/` — kept per
    configuration rather than thrown away, so an application still remembers
    what it legitimately wants to between runs of the same one. New
    `ISOLATE_APPLICATION_STATE` turns it off.

    Not Konsole specific: verified with KWrite too, whose geometry went to the
    private directory with no global `kwritestaterc` ever written. Every KDE
    application keeps window state in `$XDG_STATE_HOME/<app>staterc`, so the
    one variable covers them all.

35. **`sensors.bash` carried the header of `_template.bash`.** It announced
    itself as a template that could not be run.

### Tests

38. **The test suites left an error dialog open on every run.** One headless
    case drives the real failure path, which ends in a dialog that waits for a
    key press — and nothing was watching, so it was never closed. Eight had
    piled up.

    New `WLIW_NO_DIALOG`, which both suites export. The message still reaches
    stderr, which is what the assertions read; the dialogs are looked at on
    purpose by `preview-dialogs.bash`, which is unaffected. A new assertion
    counts dialogs around the failing case, so the suite now fails if it ever
    opens a window again.

39. **The suites no longer depend on a configuration of the machine.** The
    headless one checked `configs/sensors.bash` — the `sensors` command is
    `lm_sensors`, not something a KDE install necessarily has. The checks that
    belong to "the file that ships with the project" moved to
    `configs/_config_model.bash`, which does ship, and the rest build their own
    fixtures. `configs/sensors.bash` went back to being untracked, like any
    other configuration of a machine, and the worked examples in the
    documentation now use `free -h` rather than `sensors`.

### Installation

36. **The project could not be installed the way the others are.** It resolved
    its own directory with `dirname "${BASH_SOURCE[0]}"`, which does not follow
    a symlink: linked into `~/.local/bin` as `ez_smb_sync` and `nppstub` are,
    every `source` looked in `~/.local/bin` and failed. It now resolves the
    link first, the same way `nppstub` does:

    ```bash
    SCRIPT_PATH="$( readlink -f "${BASH_SOURCE[0]}" 2> /dev/null || echo "${BASH_SOURCE[0]}" )"
    ```

37. **Brought into line with the other projects**, so the layout is the one
    already in `~/.scripts/bash`:

    - `your-configs/` is now `configs/`, and `_template.bash` is
      `_config_model.bash`;
    - new `.gitignore`, scoped to the folder rather than by name, so only the
      model is tracked and no configuration of the machine can slip into a
      commit;
    - `LICENSE` at the root, not only under `kwin-script/`;
    - the README gained an `Installation` section with the same four steps:
      prerequisites, create your configuration, turn it into a command, bind it
      to a shortcut.

    Verified by installing it: copied to
    `~/.scripts/bash/window-like-i-want`, linked to
    `~/.local/bin/window-like-i-want`, and run from an unrelated directory —
    the window landed at 4984,0 sized 563x440, exactly as from the source tree.

### Documentation

New: [README.md](README.md), [docs/configuration.md](docs/configuration.md)
and this file. The source files also carry proper header comments; the
`: 'DOC'` and `: 'BLAH BLAH BLAH ...'` placeholders are gone from the files
that were touched.

The `json-like` reference went with the library: see
[../json-like/README.md](../json-like/README.md).

### Testing

New `--dry-run` flag: the project generates everything it normally would —
option parsing, configuration loading, substitution of the run's values into
the compiled bundle — writes the result, says where, and never starts the
application or touches KWin. It makes the whole BASH half testable headlessly.

New [tests/](tests/):

- [tests/test-bash-side.bash](tests/test-bash-side.bash) — **30 assertions**,
  no display, no D-Bus, no KWin. Command line handling, path traversal refusal,
  configuration validation, dry run output (valid JavaScript, no leftover
  placeholder, correct values, markers stripped, nothing started), build
  artefacts and shell hygiene. Every case runs the project from an unrelated
  working directory, so a path that goes back to resolving against `$PWD`
  fails at once.
- [tests/test-kwin-side.bash](tests/test-kwin-side.bash) — **14 assertions**
  against a live KWin session. It places a real window, reads back the geometry
  KWin actually gave it, and compares that with the rectangle recomputed
  independently in BASH. The read-back works by loading a probe KWin script
  that `print()`s the window's `frameGeometry` and reading it out of the user
  journal, which needs no extra tooling and works on X11 and Wayland.
- [tests/README.md](tests/README.md) — how it all fits together.

Baseline on the author's machine: **30/30 headless, 14/14 against KWin**, with
all nine regular positions matching exactly.

Two assertions in the headless suite earn their keep. One compares every
`$placeholder` in the bundle against the `local` declarations in
`window.bash`: a placeholder with no matching local expands to the **empty
string**, so the value silently becomes `""` rather than staying literal, and
nothing downstream notices. The other treats any `bash -n` **warning** as a
failure, because an unterminated heredoc is reported as a warning while still
exiting 0 — which is exactly how (6) stayed hidden.

### What the tests found

10. **`frameGeometry` assignment is asynchronous.** Setting it and reading it
    back on the next line still returns the old rectangle; the new one appears
    a few tens of milliseconds later and then stays. Nothing in the project
    depends on reading it back, so no code changed, but it is worth knowing
    before writing anything that does.

11. **Not every application can be placed at all.** On Wayland the client has
    the final say over its own surface size. `alacritty` ignores both the
    position and the size and stays at KWin's default placement. A probe
    confirmed its window `pid` matches the one the project captured, so this is
    not a matching failure — the application simply refuses. Documented as a
    limitation.

12. **KWin reports geometry in logical pixels, which are fractional on scaled
    outputs.** A window asked to be 823 wide on a 1.5x display comes back as
    `823.3333333333335`, which BASH arithmetic rejects outright. Only the test
    harness had to deal with this, but it is worth knowing before writing
    anything else that reads KWin geometry.

13. **The main script shipped without its execute bit**, so
    `./window-like-i-want.bash` failed with `Permission denied`. The test suite
    had missed it by always invoking the script as `bash <path>`; there is now
    an assertion for it.

14. **Running a configuration directly did nothing, silently.** A configuration
    only sets variables, so `bash your-configs/sensors.bash` produced no output
    and no effect, which reads as "the project is broken". Configurations now
    detect direct execution and print the command to use instead.

15. **The bundled example shipped with a debug flag enabled.**
    `sensors.bash` had `KILL_WINDOW_FOR_DEBUG=1`, which closes the window about
    a second after it has been configured, so the example looked like it opened
    and then crashed. The variable also sat outside the configuration block,
    after its `# < ---` end marker, with no comment explaining it. It is now
    `0`, documented, and inside the block, and a test asserts that no shipped
    configuration enables it.

### Verified

- `bash -n` clean on every BASH file.
- The CLI works from an unrelated working directory; `--help`, a missing `-c`,
  an unknown configuration and a `../` traversal attempt all behave.
- `npm run build` in `kwin-script/` reproduces the committed
  `dist/window.js` **byte for byte**, so the bundle matches `src/`.
- **A full run of `-c sensors` completed cleanly** on a live Plasma 6 session
  once (33) was fixed: KWin reachable, script loaded, window configured, script
  unloaded, no errors. This was not possible before, since `qdbus` does not
  exist under that name on this machine.

### Not verified

The KWin half was exercised end to end once (see above), but only with the
bundled `sensors` configuration and with `KILL_WINDOW_FOR_DEBUG=1`. The
individual placements were **not** checked: whether each of the nine regular
and eight docking codes lands where it should, and whether `SCREEN_INDEX`
picks the monitor you expect, still wants eyes on a real multi-monitor desktop.
Changes to
[bash-script/window/window.bash](bash-script/window/window.bash),
[bash-script/controller.bash](bash-script/controller.bash) and
[bash-script/error-handling/error-handling.bash](bash-script/error-handling/error-handling.bash)
were verified by syntax check, by inspection, and — for the error dialog — by
rendering it with the dialog call stubbed out. Worth a run with
`-c sensors` before trusting them.

Nothing under `kwin-script/src/`, `bash-script/dialog/color-schemes/`,
`bash-script/dialog/kwin-script/`, `bash-script/utils/prog-concepts.bash`,
`bash-script/utils/utils.bash`, `_GOLD/` or `_BAK/` was modified.
