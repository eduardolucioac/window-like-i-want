function c_window.f_new() {
    : 'Build a "window" object.

    $1 - name of the associative array to fill in.
    $2+ - the attributes, as alternating names and values.

    The declaration below is the authoritative list: "!" marks an attribute as
    required, and the value is its default.
    '

    local -rA window=(
        [!application_startup_command]=""
        [!config_to_use]=""
        [!execution_uuid]=""
        [!keep_above]=0
        [konsole_pid]=0
        [!kwin_script_configuration_latency]=0
        [kwin_script_file_content]=""
        [!screen_index]=0
        [!window_height]=0
        [!window_mode]=""
        [!window_position]=""
        [!window_width]=0
        [!window_x_position]=0
        [!window_y_position]=0
    )
    f_class_constructor window "$@"
}

function c_window.f_start_application() {
    : 'Start the configured application and record the PID of the new process.

    The KWin script matches the window to configure by that PID, so this has to
    succeed before anything else is attempted.
    '

    local -n this_obj=$1

    # Prepare the command string, start up the application and get its PID.
    # Remove the "BEGIN" and "END" delimiters, which exist so the command can be
    # written over several lines in the configuration file.
    #
    # NOTE: The markers are MATCHED, not counted off. The old "${var:6:-4}"
    # assumed the exact byte length of both markers and failed outright with
    # "substring expression < 0" whenever the command between them was empty,
    # which is precisely the case the check below is meant to report.
    local application_startup_command="${this_obj['application_startup_command']}"
    application_startup_command="${application_startup_command#BEGIN}"
    application_startup_command="${application_startup_command%END}"

    if [ -z "${application_startup_command//[[:space:]]/}" ] ; then
        echo "ERROR! \"APPLICATION_STARTUP_COMMAND\" is empty." >&2
        return 1
    fi

    # Keep what this run does to the window out of the settings of the user.
    #
    # WHY: a toolkit records the size and position of its last window so the
    # next one can reopen the same way. Konsole writes them to
    # "$XDG_STATE_HOME/konsolestaterc". The window this project starts is then
    # resized and moved by KWin, the application writes THAT down when it
    # closes, and the next window the user opens by hand comes up the size this
    # project chose. Their own sizing is silently replaced.
    #
    # Pointing XDG_STATE_HOME at a directory of our own stops that. It is kept
    # per configuration rather than thrown away, so an application still
    # remembers whatever it legitimately wants to between runs of the SAME
    # configuration; it simply does not share that with the rest of the
    # desktop of the user.
    local application_state_directory=""
    if ((${ISOLATE_APPLICATION_STATE:-1} != 0)) ; then
        application_state_directory="${XDG_STATE_HOME:-$HOME/.local/state}/window-like-i-want/${this_obj['config_to_use']}"
        mkdir -p "$application_state_directory" || {
            echo "ERROR! Unable to create \"$application_state_directory\"." >&2
            return 1
        }
    fi

    # NOTE: Exported around the "eval" rather than prefixed to it, because the
    # command comes from the configuration file and may be anything at all: a
    # prefix would only reach the first word of it. The previous value is put
    # back immediately afterwards, so nothing else in this run sees it.
    local had_xdg_state_home=0
    local previous_xdg_state_home=""
    if [[ -v XDG_STATE_HOME ]] ; then
        had_xdg_state_home=1
        previous_xdg_state_home="$XDG_STATE_HOME"
    fi

    if [ -n "$application_state_directory" ] ; then
        export XDG_STATE_HOME="$application_state_directory"
    fi

    eval "$application_startup_command"
    this_obj['konsole_pid']=$!

    if [ -n "$application_state_directory" ] ; then
        if ((had_xdg_state_home == 1)) ; then
            export XDG_STATE_HOME="$previous_xdg_state_home"
        else
            unset XDG_STATE_HOME
        fi
    fi

    # The KWin script matches the new window by PID, so without one there is
    # nothing to configure. This happens when the command in the configuration
    # file is not put in the background with a trailing "&".
    if [ -z "${this_obj['konsole_pid']}" ] ; then
        echo "ERROR! The application did not report a PID. Does \"APPLICATION_STARTUP_COMMAND\" end with \"&\"?" >&2
        return 1
    fi

}

function c_window.f_prepare_configuration() {
    : 'Build the KWin script that will be handed to KWin.

    KWin scripts take no parameters, so the compiled bundle is written with
    "$placeholders" and is read here through a HEREDOC, which makes BASH
    substitute the values of this run into it. The result is kept in
    "kwin_script_file_content".
    '

    local -n this_obj=$1

    # NOTE: The "else" branch matters. Without it the local stayed empty
    # whenever the configuration DID provide a latency, and the transformation
    # latency below was always computed from an empty string, that is, 0.
    local kwin_script_configuration_latency
    if [ -z "${this_obj['kwin_script_configuration_latency']}" ] ; then
        kwin_script_configuration_latency=1.0
    else
        kwin_script_configuration_latency="${this_obj['kwin_script_configuration_latency']}"
    fi

    # The window is hidden while it is being moved and resized, and shown again
    # a quarter of the configuration latency later.
    local hide_show_window_transformations_latency
    hide_show_window_transformations_latency=$(awk -v a="$kwin_script_configuration_latency" 'BEGIN { printf("%d", (a * 1000) / 4) }')

    # UUID used for names and identifiers within each run.
    this_obj['execution_uuid']=$(cat /proc/sys/kernel/random/uuid)

    # Register the UUID so the trap can unload the script and delete its file if
    # the run is interrupted.
    #
    # NOTE: Not in a dry run. Nothing is loaded into KWin, so there is nothing to
    # unload, and the generated file is left in place on purpose so that it can
    # be inspected.
    if ((DRY_RUN != 1)) ; then
        EXECUTION_UUIDS+=("${this_obj['execution_uuid']}")
    fi

    local config_to_use="${this_obj['config_to_use']}"
    local execution_uuid="${this_obj['execution_uuid']}"
    local keep_above="${this_obj['keep_above']}"
    local konsole_pid="${this_obj['konsole_pid']}"
    local screen_index="${this_obj['screen_index']}"
    local window_height="${this_obj['window_height']}"
    local window_mode="${this_obj['window_mode']}"
    local window_position="${this_obj['window_position']}"
    local window_width="${this_obj['window_width']}"
    local window_x_position="${this_obj['window_x_position']}"
    local window_y_position="${this_obj['window_y_position']}"

    # NOTE: Resolved against "$SCRIPT_DIRECTORY", never against the current
    # working directory, so the script can be started from anywhere.
    local kwin_script_bundle="$SCRIPT_DIRECTORY/kwin-script/dist/window.js"
    if [[ ! -r "$kwin_script_bundle" ]] ; then
        echo "ERROR! KWin script bundle not found: \"$kwin_script_bundle\"." >&2
        echo "       Build it with \"cd kwin-script && yarn install && yarn build\"." >&2
        return 1
    fi

    # Create a structure with "read" and "HEREDOC" to expand BASH variables.
    local window
    local read_n_heredoc="read -r -d \"\" window << HEREDOC
BEGIN
$(cat "$kwin_script_bundle")
END
HEREDOC"

    # Run and expand my variable within the text.
    eval "$read_n_heredoc"

    # Remove the "BEGIN" and "END" delimiters. The "BEGIN" and "END" delimiters make
    # organization easier and allow for blank lines at the end of the file.
    this_obj['kwin_script_file_content']=${window:6:-3}

}

function c_window.f_set_configuration() {
    : 'Write the generated KWin script to /tmp and load it through D-Bus.
    '

    local -n this_obj=$1

    local kwin_script_file="/tmp/${this_obj['execution_uuid']}.js"

    # Create the KWin temporary script file.
    echo -n "${this_obj['kwin_script_file_content']}" > "$kwin_script_file" || {
        echo "ERROR! Unable to write \"$kwin_script_file\"." >&2
        return 1
    }

    if ((DRY_RUN == 1)) ; then
        echo "DRY RUN: KWin script written to \"$kwin_script_file\" and NOT loaded."
        return 0
    fi

    if [ -z "$QDBUS_COMMAND" ] ; then
        echo "ERROR! No \"qdbus\" binary found. It is needed to talk to KWin." >&2
        echo "       On Arch based systems install \"qt6-tools\"." >&2
        return 1
    fi

    # Load the KWin temporary script file via Dbus "org.kde.KWin" command.
    "$QDBUS_COMMAND" org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript \
    "$kwin_script_file" "${this_obj['execution_uuid']}" > /dev/null || {
        echo "ERROR! KWin refused to load the script. Is \"org.kde.KWin\" on the session bus?" >&2
        return 1
    }

    # Starts the KWin Script that was just loaded.
    "$QDBUS_COMMAND" org.kde.KWin /Scripting org.kde.kwin.Scripting.start > /dev/null || {
        echo "ERROR! KWin refused to start the loaded script." >&2
        return 1
    }

}

function c_window.f_unset_configuration() {
    : 'Unload the generated KWin script and remove its temporary file.

    Called once the window has been configured. The trap in "trap.bash" does
    the same for a run that was interrupted before reaching this point.
    '

    local -n this_obj=$1

    # Unload the "my_sensors_shortcut.js" KWin temporary script file as it is no longer
    # needed.
    "$QDBUS_COMMAND" org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript "${this_obj['execution_uuid']}" > /dev/null

    # Remove the KWin temporary script file as it is no longer needed.
    rm -f "/tmp/${this_obj['execution_uuid']}.js"

}

