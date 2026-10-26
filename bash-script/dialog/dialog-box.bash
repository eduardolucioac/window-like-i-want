# dialog-box.bash - Draw the block of text a dialog is made of.
#
# Used in two places:
#
#   . by the shell running INSIDE a dialog window, to draw its message;
#   . by the project itself, for the support notice it prints to the terminal.
#
# THE SHAPE, and why it is this one:
#
#     ------------------------------------------------------------------------
#       A HEADING
#     ------------------------------------------------------------------------
#       Body text, indented, wrapped to fit.
#     ------------------------------------------------------------------------
#
# Rules across the top, the middle and the bottom; everything else simply
# indented. There are no side borders and nothing is padded out to the right.
#
# That is deliberate. A bordered box has to end every line in exactly the right
# column, so anything that makes a line come out a different length than
# expected - a wider font, a narrower window, one long word - breaks the
# drawing and the result is unreadable. With no right hand border there is
# nothing to line up against: a line that turns out too long just wraps, like
# any other text.
#
# window-like-i-want - Window Like I Want "inverted (c)" BSD-3-Clause
# Eduardo Lucio Amorim Costa
#

# THE WIDTH IS FIXED. A rule is 72 dashes, always, whatever terminal the
# drawing ends up in. It is not measured and it does not adapt.
#
# This is the whole point. Deriving it from the terminal meant the same message
# came out differently depending on the size of the window and the font, which
# is exactly the moving target the shape above was chosen to be rid of. One
# number, one result.
_DIALOG_BOX_RULE=72

# Everything else follows from it:
#
#     " "   + RULE   ->  TOTAL = RULE + 1
#     "   " + TEXT   ->  TEXT  = TOTAL - 3
_DIALOG_BOX_TOTAL=$((_DIALOG_BOX_RULE + 1))
_DIALOG_BOX_TEXT=$((_DIALOG_BOX_TOTAL - 3))

function f_dialog_box_rule() {
    : 'Print one horizontal rule.'

    local fill
    printf -v fill '%*s' "$_DIALOG_BOX_RULE" ''
    printf ' %s\n' "${fill// /-}"
}

function f_dialog_box_line() {
    : 'Print one indented text line.

    NOTE: Not padded out to any width, and an empty line stays truly empty
    rather than becoming three spaces. Nothing here has to end in a particular
    column, which is what makes the drawing impossible to break.
    '

    if [ -z "$1" ] ; then
        printf '\n'
        return 0
    fi

    printf '   %s\n' "$1"
}

function f_dialog_box_wrap() {
    : 'Print a paragraph as however many lines it needs.'

    local message="$1"

    local current_line=""
    local word
    for word in $message ; do
        if [ -z "$current_line" ] ; then
            current_line="$word"
        elif ((${#current_line} + 1 + ${#word} <= _DIALOG_BOX_TEXT)) ; then
            current_line="$current_line $word"
        else
            f_dialog_box_line "$current_line"
            current_line="$word"
        fi
    done

    if [ -n "$current_line" ] ; then
        f_dialog_box_line "$current_line"
    fi

    # A single word longer than the text width cannot be broken by the loop
    # above, so it is left to overflow rather than silently truncated. With no
    # right hand border to break, it simply wraps.
}

function f_dialog_box_draw() {
    : 'Draw a complete block.

    $1 - The heading.
    $2 - The body. Blank lines separate paragraphs and are kept.
    $3 - Optional text to set beside Tux.
    '

    local heading="$1"
    local body="$2"
    local tux_tagline="$3"

    f_dialog_box_rule
    f_dialog_box_line "$heading"
    f_dialog_box_rule

    local body_line
    while IFS= read -r body_line ; do
        if [ -z "${body_line//[[:space:]]/}" ] ; then
            f_dialog_box_line ""
        else
            f_dialog_box_wrap "$body_line"
        fi
    done <<< "$body"

    f_dialog_box_line ""
    f_dialog_box_line '  .~.'
    f_dialog_box_line '  /V\'
    f_dialog_box_line " // \\\\${tux_tagline:+  $tux_tagline}"
    f_dialog_box_line '/(   )\ Tux'
    f_dialog_box_line ' ^`~'"'"'^'
    f_dialog_box_rule
}

function f_dialog_box_show() {
    : 'Clear the terminal and draw the block.

    $1 - the heading
    $2 - the body
    $3 - an optional prompt, printed just after the block
    $4 - optional text to set beside Tux
    '

    # Home the cursor, clear the screen, and clear the SCROLLBACK as well.
    #
    # NOTE: All three. "\033[2J" alone only erases what is currently visible:
    # anything an earlier drawing had already pushed above the top of the
    # window stayed there, and scrolled back into view as a stray duplicate of
    # the heading. "\033[3J" drops it for good.
    #
    # Plain ANSI rather than "tput clear" or "clear", so this does not depend
    # on ncurses being installed inside the dialog.
    printf '\033[H\033[2J\033[3J'

    f_dialog_box_draw "$1" "$2" "$4"

    if [ -n "$3" ] ; then
        printf '%s' "$3"
    fi
}

