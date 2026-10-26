# qdbus.bash - Locate the "qdbus" binary.
#
# The name is not stable across distributions and Qt versions. Qt 5 shipped it
# as "qdbus"; Qt 6 renames it, and on Arch based systems (CachyOS included) the
# only copy on PATH is "qdbus6", while the unsuffixed one lives in
# "/usr/lib/qt6/bin" which is NOT on PATH.
#
# Hardcoding "qdbus" therefore makes the project fail on a perfectly normal
# Plasma 6 install, which is why every caller goes through "$QDBUS_COMMAND".
#

# The resolved command. Empty when none was found.
QDBUS_COMMAND=""

function f_resolve_qdbus_command() {
    : 'Find a usable "qdbus" and store it in "$QDBUS_COMMAND".

    Returns 1 when none is available.
    '

    if [ -n "$QDBUS_COMMAND" ] ; then
        return 0
    fi

    local candidate

    # Names that may be on PATH, newest Qt first.
    for candidate in qdbus6 qdbus-qt6 qdbus qdbus-qt5 ; do
        if command -v "$candidate" > /dev/null 2>&1 ; then
            QDBUS_COMMAND="$candidate"
            return 0
        fi
    done

    # Known locations that are usually not on PATH.
    for candidate in \
            /usr/lib/qt6/bin/qdbus \
            /usr/lib/qt/bin/qdbus \
            /usr/lib64/qt6/bin/qdbus \
            /usr/lib/x86_64-linux-gnu/qt6/bin/qdbus ; do
        if [[ -x "$candidate" ]] ; then
            QDBUS_COMMAND="$candidate"
            return 0
        fi
    done

    return 1
}

f_resolve_qdbus_command || {
    echo "WARNING! No \"qdbus\" binary found (tried \"qdbus6\", \"qdbus-qt6\", \"qdbus\", \"qdbus-qt5\")." >&2
    echo "         On Arch based systems install \"qt6-tools\"." >&2
}

