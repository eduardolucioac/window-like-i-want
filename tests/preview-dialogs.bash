#!/bin/bash
#
# preview-dialogs.bash - Show the dialogs so you can look at them.
#
# The project draws its dialogs as a Konsole window with one of four colour
# schemes. Only the "error" one is ever reached in normal use, and only when
# something has already gone wrong, which makes the other three hard to see and
# all four awkward to work on.
#
# This opens them on demand, through the real code path: the same
# "f_define_color_scheme", "f_dialog_runtime_prepare", "c_dialog.f_start_dialog"
# and "c_dialog.f_configure_dialog" the project uses. What you see here is what
# a user would see.
#
# USAGE
#
#     ./tests/preview-dialogs.bash                 # all four, one at a time
#     ./tests/preview-dialogs.bash warning         # just one
#     ./tests/preview-dialogs.bash error warning   # just these
#     ./tests/preview-dialogs.bash --all-at-once   # all four together
#
# Each dialog waits for a key press, in its own window. The next one opens once
# you have closed the previous one, unless "--all-at-once" is given.
#
# window-like-i-want - Window Like I Want "inverted (c)" BSD-3-Clause
# Eduardo Lucio Amorim Costa
#

TESTS_DIRECTORY="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" && pwd )"

# The dialog code resolves its own files against "$SCRIPT_DIRECTORY", exactly
# as it does during a real run.
SCRIPT_DIRECTORY="$( cd -- "$TESTS_DIRECTORY/.." && pwd )"

# shellcheck source=../bash-script/utils/qdbus.bash
source "$SCRIPT_DIRECTORY/bash-script/utils/qdbus.bash"
# shellcheck source=../bash-script/utils/prog-concepts.bash
source "$SCRIPT_DIRECTORY/bash-script/utils/prog-concepts.bash"
# shellcheck source=../bash-script/dialog/dialog-box.bash
source "$SCRIPT_DIRECTORY/bash-script/dialog/dialog-box.bash"
# shellcheck source=../bash-script/dialog/color-scheme.bash
source "$SCRIPT_DIRECTORY/bash-script/dialog/color-scheme.bash"
# shellcheck source=../bash-script/dialog/dialog.bash
source "$SCRIPT_DIRECTORY/bash-script/dialog/dialog.bash"

# "c_dialog.f_configure_dialog" appends to this, and the project's trap uses it
# to unload the KWin scripts it loaded. There is no trap here, so this script
# cleans up after itself below.
declare -a EXECUTION_UUIDS=()

# Private Konsole directories handed out to the dialogs, so they can be cleared
# up even when a dialog is killed rather than closed.
declare -a PREVIEW_RUNTIME_DIRECTORIES=()

ALL_AT_ONCE=0
declare -a TYPES_TO_SHOW=()

while [[ $# -gt 0 ]] ; do
    case "$1" in
        --all-at-once) ALL_AT_ONCE=1 ; shift ;;
        -h|--help)
            sed -n '3,26p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        info|success|warning|error) TYPES_TO_SHOW+=("$1") ; shift ;;
        *)
            echo "ERROR! Unknown dialog type or option: $1" >&2
            echo "       Valid types: info, success, warning, error." >&2
            exit 1
            ;;
    esac
done

if ((${#TYPES_TO_SHOW[@]} == 0)) ; then
    TYPES_TO_SHOW=(info success warning error)
fi

function preview_cleanup() {
    local execution_uuid
    for execution_uuid in "${EXECUTION_UUIDS[@]}" ; do
        if [ -n "$QDBUS_COMMAND" ] ; then
            "$QDBUS_COMMAND" org.kde.KWin /Scripting \
                org.kde.kwin.Scripting.unloadScript "$execution_uuid" > /dev/null 2>&1
        fi
        rm -f "/tmp/$execution_uuid.js"
    done

    # Each dialog removes its own private directory when it closes, but this
    # tool kills them to move on, so it clears up after them too.
    local runtime_directory
    for runtime_directory in "${PREVIEW_RUNTIME_DIRECTORIES[@]}" ; do
        rm -rf "$runtime_directory"
    done
}
trap 'preview_cleanup' EXIT

# The body text for one dialog type.
#
# NOTE: Just text. The box, the heading and the width are drawn inside the
# dialog window itself, against the width that terminal reports.
function preview_content() {
    local dialog_type="$1"

    case "$dialog_type" in
        info)
            echo 'The configuration "sensors" was loaded. The window will be placed at the top right of screen 2, sized 563x440.'
            ;;
        success)
            echo 'The window was placed exactly where you asked. The KWin script has been unloaded and its temporary file removed.'
            ;;
        warning)
            echo '"KWIN_SCRIPT_CONFIGURATION_LATENCY" is not set, so the default of 1.0 second is being used. If your application is slow to start, its window may appear after the script has already been unloaded.'
            ;;
        error)
            echo 'Unable to load the KWin script through D-Bus. Is this a KWin session?'
            ;;
    esac

    echo ""
    echo "This is a preview. Nothing has actually happened."
}

# Opens one dialog and leaves its PID in DIALOG_PID.
#
# NOTE: This mirrors "c_dialog.f_show", calling the same functions in the same
# order. It is spelled out here only so the process id can be kept, which is
# what lets the preview wait for you to close one dialog before opening the
# next.
DIALOG_PID=""
function preview_show() {
    local dialog_type="$1"

    local message_content
    message_content="$(preview_content "$dialog_type")"

    local dialog_color_scheme
    dialog_color_scheme=$(f_define_color_scheme "$dialog_type")

    local dialog_title
    dialog_title=$(f_define_dialog_title "$dialog_type")

    local dialog_runtime_directory
    f_dialog_runtime_prepare dialog_runtime_directory "$dialog_color_scheme" || return 1
    PREVIEW_RUNTIME_DIRECTORIES+=("$dialog_runtime_directory")

    DIALOG_PID=""
    c_dialog.f_start_dialog "$message_content" "$dialog_color_scheme" \
        DIALOG_PID "$dialog_title" "$dialog_runtime_directory"

    c_dialog.f_configure_dialog "$DIALOG_PID"
}

# Offsets the open dialogs so they do not sit exactly on top of each other.
function preview_cascade() {
    if [ -z "$QDBUS_COMMAND" ] ; then
        return 0
    fi

    local cascade_uuid
    cascade_uuid=$(cat /proc/sys/kernel/random/uuid)
    local cascade_file="/tmp/$cascade_uuid.js"
    EXECUTION_UUIDS+=("$cascade_uuid")

    cat > "$cascade_file" <<'CASCADE_SCRIPT'
var list = workspace.windowList ? workspace.windowList() : workspace.clientList();
var step = 48;
var found = 0;
for (var i = 0; i < list.length; i++) {
    var w = list[i];
    if (w.caption && w.caption.indexOf("WINDOW-LIKE-I-WANT") !== -1) {
        var g = w.frameGeometry;
        var shift = (found - 1.5) * step;
        w.frameGeometry = {
            x: g.x + shift,
            y: g.y + shift,
            width: g.width,
            height: g.height
        };
        found++;
    }
}
CASCADE_SCRIPT

    "$QDBUS_COMMAND" org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript \
        "$cascade_file" "$cascade_uuid" > /dev/null 2>&1
    "$QDBUS_COMMAND" org.kde.KWin /Scripting org.kde.kwin.Scripting.start > /dev/null 2>&1

    sleep 0.5

    "$QDBUS_COMMAND" org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript \
        "$cascade_uuid" > /dev/null 2>&1
    rm -f "$cascade_file"
}

echo
echo "============================================================"
echo " WINDOW-LIKE-I-WANT - DIALOG PREVIEW"
echo "============================================================"
echo

if ! command -v konsole > /dev/null 2>&1 ; then
    echo " ERROR! \"konsole\" not found. The dialogs are drawn with it." >&2
    exit 1
fi
if [ -z "$QDBUS_COMMAND" ] ; then
    echo " WARNING! No \"qdbus\" binary found." >&2
    echo "          The dialogs will still open, but will not be centred." >&2
    echo >&2
fi

declare -a PREVIEW_PIDS=()

for dialog_type in "${TYPES_TO_SHOW[@]}" ; do

    printf ' %-8s  scheme %-24s title "%s"\n' \
        "$dialog_type" \
        "$(f_define_color_scheme "$dialog_type")" \
        "$(f_define_dialog_title "$dialog_type")"

    if ! preview_show "$dialog_type" ; then
        echo "          could not open it" >&2
        continue
    fi

    if ((ALL_AT_ONCE == 1)) ; then
        PREVIEW_PIDS+=("$DIALOG_PID")

        # Give this one time to be centred before opening the next, so the
        # cascade below has something to work with.
        sleep 1.2
    else
        echo "          close it to continue (press any key in the dialog)"
        wait "$DIALOG_PID" 2>/dev/null
    fi

done

if ((ALL_AT_ONCE == 1)) && ((${#PREVIEW_PIDS[@]} > 0)) ; then

    # The dialog KWin script centres every dialog, so all of them land on the
    # same spot and only the last one is visible. Cascade them, which is the
    # whole point of opening them together: the four colour schemes side by
    # side.
    preview_cascade

    echo
    echo " All of them are open. Close each one to finish."
    wait "${PREVIEW_PIDS[@]}" 2>/dev/null
fi

echo
echo " Done."
echo
