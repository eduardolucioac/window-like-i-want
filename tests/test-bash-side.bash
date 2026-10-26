#!/bin/bash
#
# test-bash-side.bash - Headless tests for the BASH half of window-like-i-want.
#
# Covers everything that happens BEFORE KWin is involved: option parsing,
# configuration loading and validation, path resolution, and the substitution
# of the run's values into the compiled KWin script. It needs no KWin, no
# D-Bus and no display, so it runs anywhere and is safe in a hook or a CI job.
#
#     ./tests/test-bash-side.bash
#
# Exits 0 when every test passed, 1 otherwise.
#
# The KWin half is covered by "test-kwin-side.bash", which does need a live
# session.
#
# window-like-i-want - Window Like I Want "inverted (c)" BSD-3-Clause
# Eduardo Lucio Amorim Costa
#

TESTS_DIRECTORY="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIRECTORY="$( cd -- "$TESTS_DIRECTORY/.." && pwd )"
MAIN_SCRIPT="$PROJECT_DIRECTORY/window-like-i-want.bash"

# No windows. One case here drives the real failure path, which ends in a
# dialog that waits for a key press: unattended, that dialog is never closed
# and every run leaves one behind. The message still reaches stderr, which is
# what the assertions read.
export WLIW_NO_DIALOG=1

# Scratch area for the generated configurations and KWin scripts.
WORK_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/wliw-tests.XXXXXX")"

# Configurations have to live in "configs", so the ones built here are put
# there and removed again on the way out.
declare -a CREATED_CONFIGS=()

function t_cleanup() {
    local config_name
    for config_name in "${CREATED_CONFIGS[@]}" ; do
        rm -f "$PROJECT_DIRECTORY/configs/$config_name.bash"
    done
    rm -rf "$WORK_DIRECTORY"
}
trap 't_cleanup' EXIT

TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0
declare -a TESTS_FAILED_NAMES=()

function t_report() {
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    if (($1 == 0)) ; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        printf ' [ PASS ] %s\n' "$2"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        TESTS_FAILED_NAMES+=("$2")
        printf ' [ FAIL ] %s\n' "$2"
        if [ -n "$3" ] ; then
            printf '          %s\n' "$3"
        fi
    fi
}

function t_equals() {
    if [[ "$2" == "$3" ]] ; then
        t_report 0 "$1"
    else
        t_report 1 "$1" "expected [$2] but got [$3]"
    fi
}

# Runs the main script, capturing both streams and the exit status.
T_RUN_STDOUT=""
T_RUN_STDERR=""
T_RUN_RTN_CODE=0
function t_run_main() {
    local stdout_file="$WORK_DIRECTORY/stdout"
    local stderr_file="$WORK_DIRECTORY/stderr"

    # NOTE: Run from an unrelated directory on purpose. Every path the project
    # uses has to resolve against the script's own location, never against the
    # current working directory.
    ( cd "$WORK_DIRECTORY" && bash "$MAIN_SCRIPT" "$@" ) \
        > "$stdout_file" 2> "$stderr_file"
    T_RUN_RTN_CODE="$?"

    T_RUN_STDOUT=$(< "$stdout_file")
    T_RUN_STDERR=$(< "$stderr_file")
}

# Writes a configuration into "configs" and registers it for clean up.
#
#     t_make_config <name> <body>
function t_make_config() {
    local config_name="$1"
    local config_body="$2"

    printf '%s\n' "$config_body" > "$PROJECT_DIRECTORY/configs/$config_name.bash"
    CREATED_CONFIGS+=("$config_name")
}

# The body shared by most of the configurations below.
function t_config_body() {
    cat <<'CONFIG_BODY'
read -r -d '' APPLICATION_STARTUP_COMMAND << 'HEREDOC'
BEGIN
true &
END
HEREDOC

WINDOW_WIDTH=800
WINDOW_HEIGHT=600
SCREEN_INDEX=0
WINDOW_POSITION="trd"
WINDOW_MODE=""
KEEP_ABOVE=1
WINDOW_X_POSITION=
WINDOW_Y_POSITION=
KWIN_SCRIPT_CONFIGURATION_LATENCY=1.0
I_SUPPORT_FREE_SOFTWARE_N_THIS_WORK=1
CONFIG_BODY
}

# Pulls the generated script path out of the dry run output.
function t_generated_script_path() {
    local line
    line=$(printf '%s\n' "$T_RUN_STDOUT" | grep '^DRY RUN: ')
    line="${line#*\"}"
    printf '%s' "${line%%\"*}"
}

echo
echo "============================================================"
echo " WINDOW-LIKE-I-WANT - BASH SIDE TESTS"
echo "============================================================"
echo

echo " --- Command line ---"

t_run_main --help
if ((T_RUN_RTN_CODE == 0)) && [[ "$T_RUN_STDOUT" == *"Usage:"* ]] ; then
    t_report 0 "--help prints the usage and exits 0"
else
    t_report 1 "--help prints the usage and exits 0" "rc=$T_RUN_RTN_CODE"
fi

# NOTE: Its own configuration, not one that happens to be installed. Whatever
# is in "configs/" belongs to whoever owns the machine.
t_make_config "wliw_test_listed" "$(t_config_body)"
t_run_main --help
if [[ "$T_RUN_STDOUT" == *"Available configurations:"* ]] \
        && [[ "$T_RUN_STDOUT" == *"wliw_test_listed"* ]] ; then
    t_report 0 "--help lists the available configurations"
else
    t_report 1 "--help lists the available configurations"
fi

if [[ "$T_RUN_STDOUT" != *"_config_model"* ]] ; then
    t_report 0 "--help leaves the model out of the listing"
else
    t_report 1 "--help leaves the model out of the listing"
fi

t_run_main
if ((T_RUN_RTN_CODE != 0)) && [[ "$T_RUN_STDERR" == *"No configuration given"* ]] ; then
    t_report 0 "no arguments is an error"
else
    t_report 1 "no arguments is an error" "rc=$T_RUN_RTN_CODE: $T_RUN_STDERR"
fi

t_run_main -c
if ((T_RUN_RTN_CODE != 0)) ; then
    t_report 0 "-c without a value is an error"
else
    t_report 1 "-c without a value is an error"
fi

t_run_main -c no_such_configuration
if ((T_RUN_RTN_CODE != 0)) && [[ "$T_RUN_STDERR" == *"not found"* ]] ; then
    t_report 0 "an unknown configuration is an error"
else
    t_report 1 "an unknown configuration is an error" "rc=$T_RUN_RTN_CODE"
fi

t_run_main -c --dry-run
if ((T_RUN_RTN_CODE != 0)) ; then
    t_report 0 "an option is not accepted as the value of -c"
else
    t_report 1 "an option is not accepted as the value of -c"
fi

t_run_main -c --flag-that-does-not-exist
if ((T_RUN_RTN_CODE != 0)) ; then
    t_report 0 "an unknown option is an error"
else
    t_report 1 "an unknown option is an error"
fi

# A configuration name becomes a file path, so it must not be able to walk out
# of "configs".
for traversal in "../../etc/passwd" "../elsewhere" "a/b" ".." ; do
    t_run_main -c "$traversal" --dry-run
    if ((T_RUN_RTN_CODE != 0)) ; then
        t_report 0 "a path traversal is refused: \"$traversal\""
    else
        t_report 1 "a path traversal is refused: \"$traversal\"" "it was accepted"
    fi
done

echo
echo " --- Installation ---"

# The suite always invoked the script as "bash <path>", so it never noticed the
# script was shipped without its execute bit and "./window-like-i-want.bash"
# failed with "Permission denied".
if [[ -x "$MAIN_SCRIPT" ]] ; then
    t_report 0 "window-like-i-want.bash is executable"
else
    t_report 1 "window-like-i-want.bash is executable" \
        "chmod +x it, or \"./window-like-i-want.bash\" fails with Permission denied"
fi

non_executable=""
while read -r test_file ; do
    [[ -x "$test_file" ]] || non_executable="${non_executable}${non_executable:+ }${test_file##*/}"
done < <(find "$TESTS_DIRECTORY" -name '*.bash')
if [ -z "$non_executable" ] ; then
    t_report 0 "every test script is executable"
else
    t_report 1 "every test script is executable" "$non_executable"
fi

echo
echo " --- The configuration model ---"

# The regression test for the indented heredoc. "<<" only recognises a
# terminator at column 0, so an indented one swallows the rest of the file and
# leaves every variable below it unset.
#
# NOTE: Against the MODEL, which ships with the project. The configurations
# beside it describe the machine of whoever owns it, and may be anything.
(
    # shellcheck source=/dev/null
    source "$PROJECT_DIRECTORY/configs/_config_model.bash" 2>/dev/null
    missing=""
    for config_var in APPLICATION_STARTUP_COMMAND WINDOW_POSITION KEEP_ABOVE \
            KWIN_SCRIPT_CONFIGURATION_LATENCY ISOLATE_APPLICATION_STATE ; do
        if [ -z "${!config_var}" ] ; then
            missing="${missing}${missing:+ }$config_var"
        fi
    done
    if [ -n "$missing" ] ; then
        echo "MISSING:$missing"
    fi
) > "$WORK_DIRECTORY/model_check" 2>&1
model_missing=$(grep '^MISSING:' "$WORK_DIRECTORY/model_check" || true)
if [ -z "$model_missing" ] ; then
    t_report 0 "the model sets every variable below its heredoc"
else
    t_report 1 "the model sets every variable below its heredoc" "$model_missing"
fi

# A debug flag left enabled in a shipped configuration makes the project look
# broken: the window opens and then closes a second later, for no visible
# reason.
debug_flags_on=""
for shipped_config in "$PROJECT_DIRECTORY/configs/"*.bash ; do
    [[ -f "$shipped_config" ]] || continue
    [[ "$shipped_config" == *_BAK_* ]] && continue
    if grep -qE '^[[:space:]]*KILL_WINDOW_FOR_DEBUG=1[[:space:]]*$' "$shipped_config" ; then
        debug_flags_on="${debug_flags_on}${debug_flags_on:+ }${shipped_config##*/}"
    fi
done
if [ -z "$debug_flags_on" ] ; then
    t_report 0 "no shipped configuration has KILL_WINDOW_FOR_DEBUG enabled"
else
    t_report 1 "no shipped configuration has KILL_WINDOW_FOR_DEBUG enabled" \
        "$debug_flags_on (the window will open and close again)"
fi

# The command must end with "&": the window is matched by PID, and a foreground
# command never reports one.
model_command=$(
    # shellcheck source=/dev/null
    source "$PROJECT_DIRECTORY/configs/_config_model.bash" 2>/dev/null
    printf '%s' "${APPLICATION_STARTUP_COMMAND#BEGIN}"
)
if [[ "$(printf '%s' "${model_command%END}" | tr -d '[:space:]')" == *"&" ]] ; then
    t_report 0 "the model runs its command in the background"
else
    t_report 1 "the model runs its command in the background" "[$model_command]"
fi

echo
echo " --- Dry run and value substitution ---"

t_make_config "wliw_test_basic" "$(t_config_body)"
t_run_main -c wliw_test_basic --dry-run
if ((T_RUN_RTN_CODE == 0)) && [[ "$T_RUN_STDOUT" == *"DRY RUN:"* ]] ; then
    t_report 0 "a dry run succeeds and says where it wrote the script"
else
    t_report 1 "a dry run succeeds and says where it wrote the script" \
        "rc=$T_RUN_RTN_CODE: $T_RUN_STDERR"
fi

generated_script=$(t_generated_script_path)
if [[ -r "$generated_script" ]] ; then
    t_report 0 "the generated KWin script exists and is readable"
else
    t_report 1 "the generated KWin script exists and is readable" "[$generated_script]"
fi

if [[ -r "$generated_script" ]] ; then
    generated_content=$(< "$generated_script")

    # A placeholder that survives into the output means the HEREDOC did not
    # expand it at all, for instance because it was written "${name}" in a way
    # the substitution step does not reach.
    #
    # NOTE: This does NOT catch a placeholder with no matching local. BASH
    # expands an undefined variable to the EMPTY STRING, so the value silently
    # becomes "" instead of staying literal. The "Build artefacts" section
    # below is what catches that, by comparing the two sides directly.
    leftovers=$(printf '%s' "$generated_content" \
        | grep -o '\$[a-z_][a-z_]*' | sort -u || true)
    if [ -z "$leftovers" ] ; then
        t_report 0 "no \$placeholder was left unsubstituted"
    else
        t_report 1 "no \$placeholder was left unsubstituted" \
            "still present: $(printf '%s' "$leftovers" | tr '\n' ' ')"
    fi

    # The configured values have to actually reach the script.
    for expected in '"800"' '"600"' '"trd"' '"1"' ; do
        if [[ "$generated_content" == *"$expected"* ]] ; then
            t_report 0 "the generated script carries the value $expected"
        else
            t_report 1 "the generated script carries the value $expected"
        fi
    done

    # A dry run must not have a real PID, and must not be loadable by accident.
    if [[ "$generated_content" == *'"0"'* ]] ; then
        t_report 0 "a dry run substitutes the inert PID sentinel"
    else
        t_report 1 "a dry run substitutes the inert PID sentinel"
    fi

    # The BEGIN/END markers are organisational and must be stripped.
    if [[ "$generated_content" != BEGIN* ]] && [[ "$generated_content" != *END ]] ; then
        t_report 0 "the BEGIN/END markers were stripped"
    else
        t_report 1 "the BEGIN/END markers were stripped"
    fi

    # It has to be syntactically valid JavaScript, or KWin will reject it.
    if command -v node > /dev/null 2>&1 ; then
        if node --check "$generated_script" > /dev/null 2>&1 ; then
            t_report 0 "the generated script is valid JavaScript"
        else
            t_report 1 "the generated script is valid JavaScript" \
                "$(node --check "$generated_script" 2>&1 | head -3)"
        fi
    else
        echo " [ SKIP ] the generated script is valid JavaScript (no node)"
    fi

    rm -f "$generated_script"
fi

# A dry run must leave the desktop completely alone.
t_make_config "wliw_test_noside" "$(t_config_body | sed 's|^true &$|touch "'"$WORK_DIRECTORY"'/SHOULD_NOT_EXIST" \&|')"
t_run_main -c wliw_test_noside --dry-run
if [[ ! -e "$WORK_DIRECTORY/SHOULD_NOT_EXIST" ]] ; then
    t_report 0 "a dry run does not start the application"
else
    t_report 1 "a dry run does not start the application" "the command ran"
fi
rm -f "$(t_generated_script_path)"

echo
echo " --- Configuration validation ---"

t_make_config "wliw_test_nocmd" "$(t_config_body | sed "s|^true &$||")"
t_run_main -c wliw_test_nocmd
if ((T_RUN_RTN_CODE != 0)) && [[ "$T_RUN_STDERR" == *"is empty"* ]] ; then
    t_report 0 "an empty APPLICATION_STARTUP_COMMAND is an error"
else
    t_report 1 "an empty APPLICATION_STARTUP_COMMAND is an error" \
        "rc=$T_RUN_RTN_CODE: $T_RUN_STDERR"
fi

# A heredoc with NOTHING between the markers. This is distinct from the case
# above, which leaves a blank line: the marker stripping used to count bytes
# off both ends, and with nothing in between the count went negative and BASH
# failed with "substring expression < 0" instead of reporting the empty
# command.
t_make_config "wliw_test_truly_empty" "read -r -d '' APPLICATION_STARTUP_COMMAND << 'HEREDOC'
BEGIN
END
HEREDOC

WINDOW_WIDTH=
WINDOW_HEIGHT=
SCREEN_INDEX=0
WINDOW_POSITION=\"c\"
WINDOW_MODE=\"\"
KEEP_ABOVE=0
WINDOW_X_POSITION=
WINDOW_Y_POSITION=
KWIN_SCRIPT_CONFIGURATION_LATENCY=1.0
I_SUPPORT_FREE_SOFTWARE_N_THIS_WORK=1"
t_run_main -c wliw_test_truly_empty --dry-run
if [[ "$T_RUN_STDERR" == *"substring expression"* ]] ; then
    t_report 1 "an empty heredoc does not break the marker stripping" \
        "$T_RUN_STDERR"
else
    t_report 0 "an empty heredoc does not break the marker stripping"
fi
rm -f "$(t_generated_script_path)"

# An unset latency used to reach "sleep" as 'sleep ""'.
t_make_config "wliw_test_nolatency" \
    "$(t_config_body | sed 's|^KWIN_SCRIPT_CONFIGURATION_LATENCY=1.0$|KWIN_SCRIPT_CONFIGURATION_LATENCY=|')"
t_run_main -c wliw_test_nolatency --dry-run
if ((T_RUN_RTN_CODE == 0)) && [[ "$T_RUN_STDERR" == *"Using \"1.0\""* ]] ; then
    t_report 0 "an unset latency warns and falls back to 1.0"
else
    t_report 1 "an unset latency warns and falls back to 1.0" \
        "rc=$T_RUN_RTN_CODE: $T_RUN_STDERR"
fi
rm -f "$(t_generated_script_path)"

echo
echo " --- Dialog box drawing ---"

# shellcheck source=../bash-script/dialog/dialog-box.bash
source "$PROJECT_DIRECTORY/bash-script/dialog/dialog-box.bash"

# THE rule: 72 dashes, always. The width is fixed, not measured, so the same
# message comes out the same way in every terminal.
rule_lengths=$(f_dialog_box_draw "A HEADING" "body" | grep -- '^ -*$' | awk '{ print length($0) - 1 }' | sort -u)
t_equals "every rule is exactly 72 dashes" "72" "$rule_lengths"
t_equals "the rule constant is 72" "72" "$_DIALOG_BOX_RULE"

rule_count=$(f_dialog_box_draw "H" "body" | grep -c -- '^ -*$')
t_equals "a drawing has three rules" "3" "$rule_count"

# The derived widths have to stay consistent with it.
t_equals "the line width follows the rule" "$((_DIALOG_BOX_RULE + 1))" "$_DIALOG_BOX_TOTAL"
t_equals "the text width follows the line width" "$((_DIALOG_BOX_TOTAL - 3))" "$_DIALOG_BOX_TEXT"

# No line may exceed the width, whatever it is asked to draw.
#
# NOTE: The invariant is "no longer than", not "exactly". There are no side
# borders and nothing is padded out to the right, which is the whole point:
# with nothing to line up against, a line that comes out long just wraps
# instead of breaking the drawing.
longest_line=$(f_dialog_box_draw "A HEADING" "Some body text that is long enough to need wrapping more than once, so that the wrapping itself is exercised rather than just the short case.

And a second paragraph." "A tagline" | awk '{ print length($0) }' | sort -n | tail -1)
if ((longest_line <= _DIALOG_BOX_TOTAL)) ; then
    t_report 0 "no drawn line exceeds the width ($longest_line <= $_DIALOG_BOX_TOTAL)"
else
    t_report 1 "no drawn line exceeds the width" \
        "longest was $longest_line, width is $_DIALOG_BOX_TOTAL"
fi

# A blank line has to be truly blank, not three spaces of trailing whitespace.
blank_lines_kept=$(f_dialog_box_draw "H" "one

two" | grep -c '^$')
if ((blank_lines_kept >= 2)) ; then
    t_report 0 "blank lines between paragraphs are kept, and are empty"
else
    t_report 1 "blank lines between paragraphs are kept, and are empty" \
        "found $blank_lines_kept"
fi

trailing_whitespace=$(f_dialog_box_draw "H" "one

two" "A tagline" | grep -c '[[:space:]]$')
t_equals "no line ends in trailing whitespace" "0" "$trailing_whitespace"

# Tux keeps both of his backslashes, and takes an optional tagline beside him.
if f_dialog_box_draw "H" "b" | grep -q '// \\\\' ; then
    t_report 0 "the Tux drawing survives the quoting"
else
    t_report 1 "the Tux drawing survives the quoting" \
        "$(f_dialog_box_draw "H" "b" | grep '//')"
fi

if f_dialog_box_draw "H" "b" "Have fun!" | grep -q '// \\\\  Have fun!' ; then
    t_report 0 "a tagline is set beside Tux"
else
    t_report 1 "a tagline is set beside Tux"
fi

# The support notice is drawn with the same helpers, so it adapts too.
# shellcheck source=../bash-script/utils/utils.bash
source "$PROJECT_DIRECTORY/bash-script/utils/utils.bash"
if grep -q 'f_dialog_box_draw' "$PROJECT_DIRECTORY/bash-script/utils/utils.bash" ; then
    t_report 0 "the support notice is drawn, not hand-made"
else
    t_report 1 "the support notice is drawn, not hand-made" \
        "it will not follow the width of the terminal"
fi

# NOTE: Looks for the ASSIGNMENT, not any mention of it. The function
# documents what it replaced, so a plain search for the old expression matches
# the explanation rather than any code.
if grep -qE "^[[:space:]]*read .*ASK_SUPPORT" "$PROJECT_DIRECTORY/bash-script/utils/utils.bash" ; then
    t_report 1 "the support notice no longer counts bytes off a HEREDOC"
else
    t_report 0 "the support notice no longer counts bytes off a HEREDOC"
fi

# Konsole keeps its toolbar when only the menubar is hidden, and it has no
# business being in a dialog.
if grep -q -- '--hide-toolbars' "$PROJECT_DIRECTORY/bash-script/dialog/dialog.bash" ; then
    t_report 0 "the dialog hides Konsole's toolbar as well as its menubar"
else
    t_report 1 "the dialog hides Konsole's toolbar as well as its menubar"
fi

# The dialog draws with the shared helpers rather than carrying its own copy.
if grep -q 'f_dialog_box_show' "$PROJECT_DIRECTORY/bash-script/dialog/dialog.bash" ; then
    t_report 0 "the dialog draws with the shared helpers"
else
    t_report 1 "the dialog draws with the shared helpers"
fi

# Nothing may go back to deriving the width from the terminal.
if grep -rqE 'tput cols|f_dialog_box_detect_width' \
        "$PROJECT_DIRECTORY/bash-script/" 2>/dev/null ; then
    t_report 1 "the width is fixed, not measured" \
        "something still asks the terminal how wide it is"
else
    t_report 0 "the width is fixed, not measured"
fi

echo
echo " --- Application state isolation ---"

# An application records the size of its last window so the next one reopens
# the same way. The window this project starts is resized by KWin, the
# application writes THAT down when it closes, and the next window the user
# opens by hand comes up the size this project chose: their own sizing
# silently replaced. The launched application therefore gets an
# XDG_STATE_HOME of its own.
window_module="$PROJECT_DIRECTORY/bash-script/window/window.bash"
if grep -q 'XDG_STATE_HOME=' "$window_module" ; then
    t_report 0 "the launched application keeps its window state to itself"
else
    t_report 1 "the launched application keeps its window state to itself" \
        "running a configuration will replace the window size of the user"
fi

# Kept per configuration, not thrown away, so an application still remembers
# what it legitimately wants to between runs of the same one.
if grep -q 'window-like-i-want/\${this_obj\[.config_to_use.\]}' "$window_module" ; then
    t_report 0 "that state is kept per configuration"
else
    t_report 1 "that state is kept per configuration"
fi

# The previous value has to come back, or everything started afterwards in the
# same run inherits it.
if grep -q 'previous_xdg_state_home' "$window_module" ; then
    t_report 0 "the previous XDG_STATE_HOME is restored afterwards"
else
    t_report 1 "the previous XDG_STATE_HOME is restored afterwards"
fi

# And it has to be possible to turn off.
if grep -q 'ISOLATE_APPLICATION_STATE' "$window_module" ; then
    t_report 0 "the isolation can be turned off from a configuration"
else
    t_report 1 "the isolation can be turned off from a configuration"
fi

# NOTE: The two files that ship with the project, named explicitly. Globbing
# "configs/" would also pick up the throwaway configurations this suite
# writes there while it runs.
undocumented=""
for shipped_config in _config_model ; do
    grep -q 'ISOLATE_APPLICATION_STATE' \
        "$PROJECT_DIRECTORY/configs/$shipped_config.bash" 2>/dev/null \
        || undocumented="${undocumented}${undocumented:+ }$shipped_config"
done
if [ -z "$undocumented" ] ; then
    t_report 0 "the shipped configurations document ISOLATE_APPLICATION_STATE"
else
    t_report 1 "the shipped configurations document ISOLATE_APPLICATION_STATE" \
        "$undocumented"
fi

echo
echo " --- Dialog font ---"

# The dialog must not inherit the font the user set for their own Konsole: a
# proportional one makes the box art unreadable. "Monospace" is the fontconfig
# generic, which always resolves to a fixed width family.
dialog_module="$PROJECT_DIRECTORY/bash-script/dialog/dialog.bash"
if grep -qE '\-p Font="Monospace,' "$dialog_module" ; then
    t_report 0 "the dialog pins a monospaced font"
else
    t_report 1 "the dialog pins a monospaced font" \
        "it will inherit whatever the user has configured"
fi

# The property value must not repeat the property name.
if grep -q 'Font="Font=' "$dialog_module" ; then
    t_report 1 "the font property value is not doubled" \
        'it reads -p Font="Font=..."'
else
    t_report 0 "the font property value is not doubled"
fi

if command -v fc-match > /dev/null 2>&1 ; then
    resolved_font=$(fc-match Monospace family 2>/dev/null)
    if [ -n "$resolved_font" ] ; then
        t_report 0 "\"Monospace\" resolves on this system (to \"$resolved_font\")"
    else
        t_report 1 "\"Monospace\" resolves on this system"
    fi
else
    echo " [ SKIP ] \"Monospace\" resolves on this system (no fc-match)"
fi

echo
echo " --- Dialog isolation ---"

# Konsole records the size of its last window in
# "$XDG_STATE_HOME/konsolestaterc", keyed by the screen layout. Without a
# private XDG_STATE_HOME, every dialog overwrites the size the user chose for
# their OWN Konsole windows.
dialog_module="$PROJECT_DIRECTORY/bash-script/dialog/dialog.bash"
if grep -q 'XDG_STATE_HOME=' "$dialog_module" ; then
    t_report 0 "the dialog keeps Konsole's window state out of the user's profile"
else
    t_report 1 "the dialog keeps Konsole's window state out of the user's profile" \
        "no private XDG_STATE_HOME; dialogs will resize the user's Konsole windows"
fi

if grep -q 'XDG_DATA_HOME=' "$dialog_module" ; then
    t_report 0 "the dialog carries its colour scheme in a private directory"
else
    t_report 1 "the dialog carries its colour scheme in a private directory"
fi

# Nothing of ours belongs in the user's Konsole directory, and removing files
# from it was never ours to do.
# NOTE: Comment lines are stripped first. Both files MENTION the old path, to
# explain what was removed and why; what matters is that no code touches it.
if grep -h -v '^[[:space:]]*#' \
        "$PROJECT_DIRECTORY/bash-script/trap/trap.bash" \
        "$PROJECT_DIRECTORY/bash-script/dialog/color-scheme.bash" \
        "$PROJECT_DIRECTORY/bash-script/dialog/dialog.bash" 2>/dev/null \
        | grep -q 'local/share/konsole' ; then
    t_report 1 "nothing writes into the user's Konsole directory" \
        "still referenced"
else
    t_report 0 "nothing writes into the user's Konsole directory"
fi

# The window is sized by asking Konsole for the columns and rows the content
# needs. Imposing a fraction of the screen on top is what made the box wrap.
if grep -q 'TerminalColumns=' "$dialog_module" \
        && grep -q 'TerminalRows=' "$dialog_module" ; then
    t_report 0 "the dialog sizes itself from its content"
else
    t_report 1 "the dialog sizes itself from its content"
fi

if grep -qE '0\.4|screenWidth \*' "$PROJECT_DIRECTORY/bash-script/dialog/kwin-script/dialog.js" ; then
    t_report 1 "the dialog KWin script only centres, it does not resize" \
        "it still computes a fraction of the screen"
else
    t_report 0 "the dialog KWin script only centres, it does not resize"
fi

# And the runtime directory itself has to actually work.
(
    # shellcheck source=../bash-script/dialog/color-scheme.bash
    SCRIPT_DIRECTORY="$PROJECT_DIRECTORY"
    source "$PROJECT_DIRECTORY/bash-script/dialog/color-scheme.bash"
    declare runtime_directory=""
    f_dialog_runtime_prepare runtime_directory "WindowLikeIWantError" || exit 1
    [[ -d "$runtime_directory/state" ]] || exit 1
    [[ -r "$runtime_directory/data/konsole/WindowLikeIWantError.colorscheme" ]] || exit 1
    rm -rf "$runtime_directory"
) 2>/dev/null
t_report "$?" "a dialog runtime directory is built with its colour scheme"

(
    SCRIPT_DIRECTORY="$PROJECT_DIRECTORY"
    source "$PROJECT_DIRECTORY/bash-script/dialog/color-scheme.bash"
    declare runtime_directory=""
    # An unknown scheme must fail, and must not leave the directory behind.
    f_dialog_runtime_prepare runtime_directory "NoSuchScheme" 2>/dev/null && exit 1
    exit 0
) 2>/dev/null
t_report "$?" "an unknown colour scheme is refused"

echo
echo " --- Build artefacts ---"

bundle="$PROJECT_DIRECTORY/kwin-script/dist/window.js"
if [[ -r "$bundle" ]] ; then
    t_report 0 "the compiled KWin bundle is present"
else
    t_report 1 "the compiled KWin bundle is present" "[$bundle]"
fi

# Each "$placeholder" in the bundle must have a matching local in
# "f_prepare_configuration", otherwise it reaches KWin unsubstituted. This
# catches the mismatch at its source, not just in the output above.
if [[ -r "$bundle" ]] ; then
    window_module="$PROJECT_DIRECTORY/bash-script/window/window.bash"
    unmatched=""
    while read -r placeholder ; do
        [ -z "$placeholder" ] && continue
        # NOTE: Matches both "local name=value" and a bare "local name"
        # followed by an assignment on the next line, which is how the
        # computed ones are written.
        if ! grep -qE "local ${placeholder#\$}(=|$)" "$window_module" ; then
            unmatched="${unmatched}${unmatched:+ }$placeholder"
        fi
    done < <(grep -o '\$[a-z_][a-z_]*' "$bundle" | sort -u)
    if [ -z "$unmatched" ] ; then
        t_report 0 "every bundle placeholder has a local in window.bash"
    else
        t_report 1 "every bundle placeholder has a local in window.bash" \
            "missing: $unmatched"
    fi
fi

echo
echo " --- Leaves nothing behind ---"

# The suite must not open a window. Counted around the one case that drives
# the real failure path, since a dialog of its own would be the one left open.
dialogs_before=$(pgrep -fc 'a[n]y key to close this dialog' 2>/dev/null || echo 0)
t_make_config "wliw_test_nodialog" "$(t_config_body | sed "s|^true &$||")"
t_run_main -c wliw_test_nodialog
sleep 1
dialogs_after=$(pgrep -fc 'a[n]y key to close this dialog' 2>/dev/null || echo 0)
t_equals "a failing run opens no dialog when WLIW_NO_DIALOG is set" \
    "$dialogs_before" "$dialogs_after"

if [[ "$T_RUN_STDERR" == *"is empty"* ]] ; then
    t_report 0 "the message still reaches stderr with the dialog suppressed"
else
    t_report 1 "the message still reaches stderr with the dialog suppressed" \
        "$T_RUN_STDERR"
fi

echo
echo " --- Shell hygiene ---"

syntax_failures=""
while read -r bash_file ; do
    if ! bash -n "$bash_file" 2>/dev/null ; then
        syntax_failures="${syntax_failures}${syntax_failures:+ }${bash_file##*/}"
    fi
done < <(find "$PROJECT_DIRECTORY" -name '*.bash' \
            -not -name '*_BAK_*' \
            -not -path '*/_GOLD/*' \
            -not -path '*/_BAK/*' \
            -not -path '*/_TRASH/*')
if [ -z "$syntax_failures" ] ; then
    t_report 0 "every BASH file parses, with no warnings"
else
    t_report 1 "every BASH file parses, with no warnings" "$syntax_failures"
fi

# "bash -n" reports an unterminated heredoc as a warning while still exiting 0,
# which is how the indented heredoc stayed hidden. Treat any warning as a
# failure.
warning_files=""
while read -r bash_file ; do
    if [ -n "$(bash -n "$bash_file" 2>&1)" ] ; then
        warning_files="${warning_files}${warning_files:+ }${bash_file##*/}"
    fi
done < <(find "$PROJECT_DIRECTORY" -name '*.bash' \
            -not -name '*_BAK_*' \
            -not -path '*/_GOLD/*' \
            -not -path '*/_BAK/*' \
            -not -path '*/_TRASH/*')
if [ -z "$warning_files" ] ; then
    t_report 0 "no BASH file produces a parser warning"
else
    t_report 1 "no BASH file produces a parser warning" "$warning_files"
fi

echo
echo "============================================================"
printf ' TOTAL %s | PASSED %s | FAILED %s\n' "$TESTS_TOTAL" "$TESTS_PASSED" "$TESTS_FAILED"
if ((TESTS_FAILED > 0)) ; then
    echo " FAILED TESTS:"
    for failed_name in "${TESTS_FAILED_NAMES[@]}" ; do
        printf '   . %s\n' "$failed_name"
    done
fi
echo "============================================================"
echo

((TESTS_FAILED == 0)) && exit 0
exit 1
