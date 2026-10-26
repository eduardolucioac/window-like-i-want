function f_ask_support() {
    : 'Print a note about the project, and an invitation to get in touch.

    NOTE: Drawn with the same helpers as the dialogs, at the same fixed width.
    It used to be a hand drawn box carved out of a HEREDOC with
    "${ASK_SUPPORT:6:-3}", whose magic offsets broke if the text ever changed
    length, and whose side borders fell apart the moment a line came out a
    different length than expected.
    '

    if [ -n "$I_SUPPORT_FREE_SOFTWARE_N_THIS_WORK" ] &&\
            [ "$I_SUPPORT_FREE_SOFTWARE_N_THIS_WORK" -eq 1 ]; then
        return
    fi

    # NOTE: The address is on a line of its own, with no brackets around it.
    # Wrapped at a narrow width, "( url )." came out as three separate lines,
    # and brackets also stop some terminals from making the address clickable.
    local support_body
    support_body="I'm just a regular everyday normal guy with bills and family.
This is an open-source project and will continue to be so forever.

If it was useful to you, come and say hello:
https://www.linkedin.com/in/eduardo-software-livre/"

    f_dialog_box_draw "SUPPORT FREE SOFTWARE AND MY WORK!" "$support_body" "Have fun!"
}

