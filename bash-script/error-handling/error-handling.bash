function f_error_handling() {
    : 'Report a failure: on stderr, and as a dialog.

    $1 - A short description of what went wrong.

    NOTE: This used to be called unconditionally at the end of "f_controller",
    so a perfectly successful run always ended with an error dialog. It is now
    only reached from a failed step.
    '

    local error_reason="$1"
    if [ -z "$error_reason" ] ; then
        error_reason="An unexpected error occurred."
    fi

    echo "ERROR! $error_reason" >&2

    # NOTE: Plain text, not a drawn box. The dialog draws itself, against the
    # width of the terminal it ends up in.
    local MESSAGE_CONTENT
    MESSAGE_CONTENT="$error_reason

Check the configuration you passed with \"-c\" and make sure the KWin script bundle was built (\"cd kwin-script && yarn build\").

If you believe this is a bug, please report it."

    f_show_dialog "$MESSAGE_CONTENT" "error"

}

