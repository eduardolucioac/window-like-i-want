declare -a EXECUTION_UUIDS
function f_trap() {
    : 'Clean up whatever a run may have left behind: the KWin scripts it
    loaded, and their temporary files.
    '

    local execution_uuid
    for execution_uuid in "${EXECUTION_UUIDS[@]}"; do
        if [ -n "$QDBUS_COMMAND" ] ; then
            "$QDBUS_COMMAND" org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript "$execution_uuid" > /dev/null 2>&1
        fi
        rm -f "/tmp/$execution_uuid.js"
    done

    # NOTE: This used to delete four ".colorscheme" files from
    # "~/.local/share/konsole", because the dialog linked them in there. It no
    # longer does: each dialog gets a private directory of its own, which it
    # removes itself. Nothing of ours belongs in the user's Konsole directory,
    # and removing files from it was never ours to do.

}

# Execute code asynchronously using a subshell.
# With disown the background job continues running independently of the parent shell.
trap "(
    if [ -n \"\$KWIN_SCRIPT_CONFIGURATION_LATENCY\" ] ; then
        TRAP_LATENCY=\$(awk -v val=\"\$KWIN_SCRIPT_CONFIGURATION_LATENCY\" 'BEGIN {print val + 0.5}')
    else
        TRAP_LATENCY=1.5
    fi
    sleep \"\$TRAP_LATENCY\"
    f_trap
) & disown" EXIT INT TERM HUP

