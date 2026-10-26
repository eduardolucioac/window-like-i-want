function f_define_color_scheme() {
    : 'Map a dialog type to the name of its Konsole colour scheme.

    $1 - "info", "success", "warning" or "error". Anything else falls back to
         "info".
    '

    local DIALOG_TYPE
    DIALOG_TYPE=$1

    local DIALOG_COLOR_SCHEME
    case "$DIALOG_TYPE" in
        info)
            DIALOG_COLOR_SCHEME="WindowLikeIWantInfo"
            ;;
        success)
            DIALOG_COLOR_SCHEME="WindowLikeIWantSuccess"
            ;;
        warning)
            DIALOG_COLOR_SCHEME="WindowLikeIWantWarning"
            ;;
        error)
            DIALOG_COLOR_SCHEME="WindowLikeIWantError"
            ;;
        *)
            DIALOG_COLOR_SCHEME="WindowLikeIWantInfo"
            ;;
    esac

    echo -n "$DIALOG_COLOR_SCHEME"
}

function f_dialog_runtime_prepare() {
    : 'Build a private Konsole environment for one dialog.

    $1 - name of the variable to receive the directory
    $2 - the colour scheme to make available

    WHY THIS EXISTS: Konsole records the size of its last window in
    "$XDG_STATE_HOME/konsolestaterc", keyed by the screen layout. Every dialog
    the project opened therefore OVERWROTE the size the user had chosen for
    their own Konsole windows, and the next one they opened came up the size of
    our dialog. Pointing XDG_STATE_HOME somewhere private keeps that bookkeeping
    out of the profile of the user entirely.

    XDG_DATA_HOME goes with it so the colour scheme can be dropped in beside it,
    instead of being linked into the Konsole data directory of the user and
    deleted again afterwards, which meant creating and removing files in a
    directory that is none of our business.
    '

    local -n runtime_directory_rtn_7b21="$1"
    local dialog_color_scheme="$2"

    # NOTE: Suffixed, like the nameref. A plain "runtime_directory" here would
    # SHADOW a caller variable of that name, so the nameref would resolve to
    # this local instead and the caller would silently get nothing back.
    local runtime_directory_7b21
    runtime_directory_7b21=$(mktemp -d "${TMPDIR:-/tmp}/wliw-dialog.XXXXXX") || {
        echo "ERROR! Unable to create the dialog runtime directory." >&2
        return 1
    }

    mkdir -p "$runtime_directory_7b21/state" "$runtime_directory_7b21/data/konsole" || {
        echo "ERROR! Unable to populate \"$runtime_directory_7b21\"." >&2
        rm -rf "$runtime_directory_7b21"
        return 1
    }

    local scheme_source_7b21="$SCRIPT_DIRECTORY/bash-script/dialog/color-schemes/$dialog_color_scheme.colorscheme"
    if [[ ! -r "$scheme_source_7b21" ]] ; then
        echo "ERROR! Colour scheme not found: \"$scheme_source_7b21\"." >&2
        rm -rf "$runtime_directory_7b21"
        return 1
    fi

    cp "$scheme_source_7b21" "$runtime_directory_7b21/data/konsole/" || {
        echo "ERROR! Unable to install the colour scheme \"$dialog_color_scheme\"." >&2
        rm -rf "$runtime_directory_7b21"
        return 1
    }

    runtime_directory_rtn_7b21="$runtime_directory_7b21"
}

function f_define_dialog_title() {
    : 'Map a dialog type to the title its window should carry.

    NOTE: This used to be hardcoded to "WINDOW-LIKE-I-WANT ERROR" in
    "c_dialog.f_start_dialog", so a warning or an informational dialog
    announced itself as an error.
    '

    local DIALOG_TYPE
    DIALOG_TYPE=$1

    local DIALOG_TITLE
    case "$DIALOG_TYPE" in
        info)    DIALOG_TITLE="WINDOW-LIKE-I-WANT INFORMATION" ;;
        success) DIALOG_TITLE="WINDOW-LIKE-I-WANT SUCCESS" ;;
        warning) DIALOG_TITLE="WINDOW-LIKE-I-WANT WARNING" ;;
        error)   DIALOG_TITLE="WINDOW-LIKE-I-WANT ERROR" ;;
        *)       DIALOG_TITLE="WINDOW-LIKE-I-WANT" ;;
    esac

    echo -n "$DIALOG_TITLE"
}
