# options.bash - Command line option parsing.
#
# This file is SOURCED by "window-like-i-want.bash", so it sees the positional
# parameters of the main script and can export its results as plain variables.
# It expects "$SCRIPT_DIRECTORY" to be set already.
#

# Default values
CONFIG_TO_USE=""

# When 1, generate everything but never touch KWin and never start the
# application. Used by the test suite, and handy for inspecting what would be
# sent to KWin.
DRY_RUN=0

# Function to display usage
usage() {
    : 'Print how to run the project, and what configurations are available.

    $1 - the status to exit with (default 1).
    '

    local exit_code="${1:-1}"

    echo "Usage: window-like-i-want.bash -c <configuration> [options]"
    echo ""
    echo "Starts an application and has KWin place its window exactly where you"
    echo "want it, as described by one of the configurations in \"configs\"."
    echo ""
    echo "Options:"
    echo "  -c, --config-to-use . Name of the configuration to use, without the"
    echo "                        \".bash\" extension (required)"
    echo "  -h, --help .......... Display this help message"
    echo "      --dry-run ....... Generate the KWin script and print where it"
    echo "                        was written, without starting the application"
    echo "                        or loading anything into KWin"
    echo ""
    echo "Available configurations:"

    local config_file
    local found_any=0
    for config_file in "$SCRIPT_DIRECTORY/configs/"*.bash ; do
        if [[ -f "$config_file" ]] ; then
            config_file="${config_file##*/}"

            # NOTE: A leading "_" marks a template rather than a configuration
            # to run, so it is not offered here.
            [[ "$config_file" == _* ]] && continue

            echo "  . ${config_file%.bash}"
            found_any=1
        fi
    done
    if ((found_any == 0)) ; then
        echo "  (none found in \"$SCRIPT_DIRECTORY/configs\")"
    fi

    exit "$exit_code"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--config-to-use)
            if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                CONFIG_TO_USE="$2"
                shift 2
            else
                echo "ERROR! $1 requires a non-empty argument." >&2
                usage 1
            fi
            ;;
        -h|--help)
            usage 0
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --) # End of all options
            shift
            break
            ;;
        -*)
            echo "ERROR! Unknown option: $1" >&2
            usage 1
            ;;
        *) # For positional argument or unrecognized options.
            shift
            ;;
    esac
done

if [[ -z "$CONFIG_TO_USE" ]]; then
    echo "ERROR! No configuration given. Use \"-c <configuration>\"." >&2
    usage 1
fi

# A configuration name is turned into a file path, so it must not be able to
# walk out of "configs".
if [[ "$CONFIG_TO_USE" == */* ]] || [[ "$CONFIG_TO_USE" == *..* ]]; then
    echo "ERROR! Invalid configuration name: \"$CONFIG_TO_USE\"." >&2
    usage 1
fi

if [[ "$CONFIG_TO_USE" == _* ]]; then
    echo "ERROR! \"$CONFIG_TO_USE\" is a template, not a configuration. Copy it first." >&2
    usage 1
fi

# NOTE: Resolved against "$SCRIPT_DIRECTORY", never against the current working
# directory, so the script can be started from anywhere.
if [[ ! -f "$SCRIPT_DIRECTORY/configs/$CONFIG_TO_USE.bash" ]]; then
    echo "ERROR! Configuration file not found: \"$SCRIPT_DIRECTORY/configs/$CONFIG_TO_USE.bash\"." >&2
    usage 1
fi

echo "CONFIGURATION TO USE: $CONFIG_TO_USE"

