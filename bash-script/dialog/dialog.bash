function c_dialog.f_new() {
    : 'Validate the arguments of a dialog.

    $1 - name of the associative array to fill in.
    $2+ - the attributes, as alternating names and values.

    NOTE: The array it fills in is DISCARDED by the only caller. What is
    wanted here is the check: both attributes are required, so a dialog with
    no message or no type is refused before a window is opened for it. Three
    further attributes used to be declared - "dialog_pid", "execution_uuid"
    and "dialog_color_scheme" - and nothing ever set or read any of them.
    '

    local -rA dialog=(
        [!message_content]=""
        [!dialog_type]=""
    )
    f_class_constructor dialog "$@"
}

function c_dialog.f_start_dialog() {
    : 'Open the dialog window.

    $1 - the message body, as plain text
    $2 - the colour scheme name
    $3 - name of the variable to receive the process id
    $4 - the window title
    $5 - the private runtime directory from "f_dialog_runtime_prepare"
    '

    local MESSAGE_CONTENT=$1
    local DIALOG_COLOR_SCHEME=$2
    local -n DIALOG_PID_REF=$3
    local DIALOG_TITLE=$4
    local DIALOG_RUNTIME_DIRECTORY=$5
    if [ -z "$DIALOG_TITLE" ] ; then
        DIALOG_TITLE="WINDOW-LIKE-I-WANT"
    fi

    # Work out how big the window has to be, by drawing the box here and
    # counting it.
    #
    # NOTE: Konsole is then ASKED for exactly that many columns and rows, and
    # sizes its own window accordingly. The window therefore already fits when
    # it appears, and the shell inside it measures the width it will really
    # have. Letting KWin impose a fraction of the screen instead is what made
    # the box wrap: the shell measured one width and the window then became
    # another.
    # One column wider than the drawing, so a full width rule cannot reach the
    # last column, which is where some terminals wrap.
    local DIALOG_COLUMNS=$((_DIALOG_BOX_TOTAL + 1))

    local DIALOG_DRAWN
    DIALOG_DRAWN="$(f_dialog_box_draw "$DIALOG_TITLE" "$MESSAGE_CONTENT")"

    # The drawn box, plus the prompt line and one to spare.
    local DIALOG_ROWS
    DIALOG_ROWS=$(( $(printf '%s\n' "$DIALOG_DRAWN" | wc -l) + 2 ))

    # NOTE: The drawing is a fixed width, so there is nothing to measure and
    # nothing to redraw when the window is resized. The window is merely asked
    # to be big enough for it.
    # NOTE: INT/TERM/HUP as well as EXIT. Konsole being closed from the window
    # manager, or killed, takes the shell down with a signal, and an EXIT-only
    # trap does not run then; the private directory would be left behind.
    local DIALOG_COMMANDS="trap 'rm -rf \"$DIALOG_RUNTIME_DIRECTORY\"' EXIT INT TERM HUP
source \"$SCRIPT_DIRECTORY/bash-script/dialog/dialog-box.bash\"
read -r -d '' WLIW_DIALOG_BODY << 'WLIW_DIALOG_BODY_END'
$MESSAGE_CONTENT
WLIW_DIALOG_BODY_END
f_dialog_box_show \"$DIALOG_TITLE\" \"\$WLIW_DIALOG_BODY\" ' Press any key to close this dialog...'
read -n1 -r"

    # NOTE: "--hide-toolbars" as well. Hiding only the menubar leaves Konsole's
    # toolbar in place (New Tab, Split View, Copy, Paste, Find and a hamburger
    # menu), which has no business being in a dialog.
    #
    # NOTE: XDG_STATE_HOME and XDG_DATA_HOME point into the private runtime
    # directory. See "f_dialog_runtime_prepare" for why that matters.
    # WHAT KEEPS THE LAYOUT CORRECT, and it is two separate things:
    #
    #   . the FONT is pinned to the "Monospace" fontconfig generic, which
    #     always resolves to a fixed width family. Without it the dialog would
    #     inherit whatever font the user has set for their own Konsole, and a
    #     proportional one makes the box art unreadable;
    #
    #   . the COLUMN COUNT is pinned, just below. The box is drawn to the
    #     width the terminal reports, and the terminal is told how wide to be,
    #     so the two cannot disagree.
    #
    # NOTE: Konsole lays every character out on a fixed cell grid regardless of
    # the font, so the borders line up either way; the font is what decides
    # whether the result is legible. It is the column count that decides
    # whether the box FITS.
    XDG_STATE_HOME="$DIALOG_RUNTIME_DIRECTORY/state" \
    XDG_DATA_HOME="$DIALOG_RUNTIME_DIRECTORY/data" \
    konsole --hide-menubar --hide-tabbar --hide-toolbars \
        --notransparency -p tabtitle="$DIALOG_TITLE" \
        -p Font="Monospace,12,-1,5,900,0,0,0,0,0,0,0,0,0,0,1" \
        -p ColorScheme="$DIALOG_COLOR_SCHEME" \
        -p TerminalColumns="$DIALOG_COLUMNS" \
        -p TerminalRows="$DIALOG_ROWS" \
        -p ScrollBarPosition=2 \
        -e bash -c "$DIALOG_COMMANDS" &
    DIALOG_PID_REF=$!

}

function c_dialog.f_configure_dialog() {
    : 'Load the KWin script that centres the dialog, then unload it again.

    $1 - the process id of the dialog, which the script matches on.
    '

    local DIALOG_PID=$1

    # UUID used for names and identifiers.
    local EXECUTION_UUID
    EXECUTION_UUID=$(cat /proc/sys/kernel/random/uuid)

    # Generate a UUID for the temporary KWin script file name.
    EXECUTION_UUIDS+=("$EXECUTION_UUID")

    # Create a structure with "read" and "HEREDOC" to expand BASH variables.
    local DIALOG_JS
    local READ_N_HEREDOC
    READ_N_HEREDOC="read -r -d \"\" DIALOG_JS << HEREDOC
BEGIN
$(cat "$SCRIPT_DIRECTORY/bash-script/dialog/kwin-script/dialog.js")
END
HEREDOC"

    # Run and expand my variable within the text.
    eval "$READ_N_HEREDOC"

    # Create the KWin temporary script file.
    # Remove the "BEGIN" and "END" delimiters. The "BEGIN" and "END" delimiters make
    # organization easier and allow for blank lines at the end of the file.
    echo -n "${DIALOG_JS:6:-4}" > "/tmp/$EXECUTION_UUID.js"

    # NOTE: This only CENTRES the dialog. A dialog is often the last thing shown
    # before giving up, so a missing or unhappy "qdbus" must not turn it into a
    # pile of raw shell errors: the Konsole window is already up either way, it
    # just stays wherever the window manager put it.
    if [ -z "$QDBUS_COMMAND" ] ; then
        rm -f "/tmp/$EXECUTION_UUID.js"
        return 0
    fi

    # Load the KWin temporary script file via Dbus "org.kde.KWin" command.
    "$QDBUS_COMMAND" org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript \
    "/tmp/$EXECUTION_UUID.js" "$EXECUTION_UUID" > /dev/null 2>&1 || {
        rm -f "/tmp/$EXECUTION_UUID.js"
        return 0
    }

    # Starts the KWin Script that was just loaded.
    "$QDBUS_COMMAND" org.kde.KWin /Scripting org.kde.kwin.Scripting.start > /dev/null 2>&1

    # Execute code asynchronously using a subshell.
    (
        sleep 1.5

        # Unload the "my_sensors_shortcut.js" KWin temporary script file as it is no longer
        # needed.
        "$QDBUS_COMMAND" org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript "$EXECUTION_UUID" > /dev/null 2>&1

        # Remove the KWin temporary script file as it is no longer needed.
        rm -f "/tmp/$EXECUTION_UUID.js"

    ) &

}

function c_dialog.f_show() {
    : 'Show a dialog of a given type.

    $1 - the message body, as plain text
    $2 - "info", "success", "warning" or "error"
    '

    local MESSAGE_CONTENT=$1
    local DIALOG_TYPE=$2

    local DIALOG_COLOR_SCHEME
    DIALOG_COLOR_SCHEME=$(f_define_color_scheme "$DIALOG_TYPE")

    local DIALOG_TITLE
    DIALOG_TITLE=$(f_define_dialog_title "$DIALOG_TYPE")

    local DIALOG_RUNTIME_DIRECTORY
    f_dialog_runtime_prepare DIALOG_RUNTIME_DIRECTORY "$DIALOG_COLOR_SCHEME" || {
        return 1
    }

    local DIALOG_PID
    c_dialog.f_start_dialog "$MESSAGE_CONTENT" "$DIALOG_COLOR_SCHEME" \
        DIALOG_PID "$DIALOG_TITLE" "$DIALOG_RUNTIME_DIRECTORY"

    c_dialog.f_configure_dialog "$DIALOG_PID"

    # NOTE: Nothing to undo afterwards. The colour scheme lives inside the
    # private runtime directory, which the dialog removes when it closes.

}

function f_show_dialog() {
    : 'Show a dialog.

    $1 - The message body, as plain text. Blank lines separate paragraphs.
         It is NOT pre-drawn: the box, the heading and the width are all
         worked out further down.
    $2 - "info", "success", "warning" or "error".
    '

    local -A dialog_obj
    c_dialog.f_new dialog_obj message_content "$1" dialog_type "$2" || return 1

    # NOTE: "WLIW_NO_DIALOG" suppresses the window. A dialog waits for a key
    # press, so anything running unattended - the test suites, a CI job - would
    # leave one open for ever, and the headless suite has no business opening
    # windows at all. Nothing is lost: whatever asked for the dialog has
    # already written the same message to stderr.
    if [ -n "$WLIW_NO_DIALOG" ] && [ "$WLIW_NO_DIALOG" != "0" ] ; then
        return 0
    fi

    c_dialog.f_show "$1" "$2"
}

