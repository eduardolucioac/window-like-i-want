#!/bin/bash
#
# test-kwin-side.bash - End to end tests against a live KWin session.
#
# This is the half that cannot be faked. For each position code it starts a
# window through the project, reads back the geometry KWin actually gave it, and
# compares that with the rectangle the code was supposed to produce.
#
# HOW THE GEOMETRY IS READ BACK
#
# KWin scripts can "print()", and that lands in the user journal. So a probe
# script is loaded over D-Bus, asked to find the window by its caption, and told
# to print its "frameGeometry"; the journal is then read for the answer. No
# extra tooling is needed, and it works on both X11 and Wayland.
#
# WHY THE EXPECTED VALUES ARE RECOMPUTED HERE
#
# The expected rectangles are worked out independently, in BASH, instead of
# being taken from the TypeScript. A test that reuses the implementation it is
# testing only proves the code agrees with itself.
#
# USAGE
#
#     ./tests/test-kwin-side.bash                 # the 9 regular positions
#     ./tests/test-kwin-side.bash --all           # and the 8 docking ones
#     ./tests/test-kwin-side.bash --screen 1      # on a given screen
#     ./tests/test-kwin-side.bash --only trd,c    # just these codes
#
# BE AWARE: this opens and closes a real window per case, on your actual
# desktop. It is quick but it is visible, so do not run it in the middle of
# something.
#
# window-like-i-want - Window Like I Want "inverted (c)" BSD-3-Clause
# Eduardo Lucio Amorim Costa
#

TESTS_DIRECTORY="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIRECTORY="$( cd -- "$TESTS_DIRECTORY/.." && pwd )"
MAIN_SCRIPT="$PROJECT_DIRECTORY/window-like-i-want.bash"

# shellcheck source=../bash-script/utils/qdbus.bash
source "$PROJECT_DIRECTORY/bash-script/utils/qdbus.bash"

# The window size asked for in every generated configuration. Deliberately not
# a round fraction of any screen, so a coincidental match is unlikely.
TEST_WINDOW_WIDTH=823
TEST_WINDOW_HEIGHT=617

# How long to wait for the window to appear and be configured.
TEST_LATENCY=1.5

SCREEN_INDEX=0
RUN_DOCKING=0
ONLY_CODES=""

while [[ $# -gt 0 ]] ; do
    case "$1" in
        --all)    RUN_DOCKING=1 ; shift ;;
        --screen) SCREEN_INDEX="$2" ; shift 2 ;;
        --only)   ONLY_CODES="$2" ; shift 2 ;;
        -h|--help)
            sed -n '3,33p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) echo "ERROR! Unknown option: $1" >&2 ; exit 1 ;;
    esac
done

# Rounds a possibly fractional number to the nearest integer.
#
# NOTE: KWin reports geometry in LOGICAL pixels, and on a fractionally scaled
# output those are not whole numbers: asking for 823 wide on a 1.5x display
# comes back as 823.3333333333335. BASH arithmetic rejects that outright, so
# every value read from KWin goes through here first.
function t_round() {
    awk -v n="$1" 'BEGIN { printf("%d", (n < 0 ? n - 0.5 : n + 0.5)) }'
}

# True when two numbers are within TEST_TOLERANCE of each other.
#
# A fractionally scaled output cannot represent an arbitrary logical size
# exactly, so an exact match is the wrong thing to demand.
TEST_TOLERANCE=2
function t_near() {
    local difference=$(( $1 - $2 ))
    ((difference < 0)) && difference=$(( -difference ))
    ((difference <= TEST_TOLERANCE))
}

# No dialogs. This suite drives the real tool many times over, and a dialog
# waits for a key press that never comes when nothing is watching.
export WLIW_NO_DIALOG=1

declare -a CREATED_CONFIGS=()
declare -a STARTED_MARKERS=()

function t_cleanup() {
    local name
    for name in "${CREATED_CONFIGS[@]}" ; do
        rm -f "$PROJECT_DIRECTORY/configs/$name.bash"

        # NOTE: And the private state directory the run gave it. Each
        # configuration gets one, so a suite that invents throwaway
        # configurations would otherwise leave a trail of them behind.
        rm -rf "${XDG_STATE_HOME:-$HOME/.local/state}/window-like-i-want/$name"
    done
    local marker
    for marker in "${STARTED_MARKERS[@]}" ; do
        pkill -f "$marker" 2>/dev/null
    done
}
trap 't_cleanup' EXIT

TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0
declare -a TESTS_FAILED_NAMES=()

function t_report() {
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    if (($1 == 0)) ; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        printf ' [ PASS ] %s\n' "$2"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        TESTS_FAILED_NAMES+=("$2")
        printf ' [ FAIL ] %s\n' "$2"
        [ -n "$3" ] && printf '          %s\n' "$3"
    fi
}

# Runs a KWin script and returns the lines it printed to the journal.
#
#     t_kwin_probe <marker> <javascript>
function t_kwin_probe() {
    local marker="$1"
    local javascript="$2"

    local probe_uuid
    probe_uuid=$(cat /proc/sys/kernel/random/uuid)
    local probe_file="/tmp/wliw-probe-$probe_uuid.js"

    printf '%s\n' "$javascript" > "$probe_file"

    "$QDBUS_COMMAND" org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript \
        "$probe_file" "$probe_uuid" > /dev/null 2>&1
    "$QDBUS_COMMAND" org.kde.KWin /Scripting org.kde.kwin.Scripting.start > /dev/null 2>&1

    sleep 0.7

    "$QDBUS_COMMAND" org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript \
        "$probe_uuid" > /dev/null 2>&1
    rm -f "$probe_file"

    journalctl --user --since "-10s" 2>/dev/null | grep -F "$marker" | tail -20
}

# Fills in SCREEN_X, SCREEN_Y, SCREEN_W and SCREEN_H for "$1", and
# SCREEN_COUNT.
SCREEN_X=0 ; SCREEN_Y=0 ; SCREEN_W=0 ; SCREEN_H=0 ; SCREEN_COUNT=0
function t_read_screen_geometry() {
    local wanted_index="$1"
    local marker="WLIW_TEST_SCREENS"

    local output
    output=$(t_kwin_probe "$marker" "
print(\"$marker count=\" + workspace.screens.length);
for (var i = 0; i < workspace.screens.length; i++) {
    var g = workspace.screens[i].geometry;
    print(\"$marker screen \" + i + \" \" + g.x + \" \" + g.y + \" \" + g.width + \" \" + g.height);
}
")

    SCREEN_COUNT=$(printf '%s\n' "$output" | sed -n "s/.*$marker count=\([0-9]*\).*/\1/p" | tail -1)
    local line
    line=$(printf '%s\n' "$output" | grep -E "$marker screen $wanted_index " | tail -1)
    if [ -z "$line" ] ; then
        return 1
    fi
    read -r SCREEN_X SCREEN_Y SCREEN_W SCREEN_H \
        <<< "$(printf '%s\n' "$line" | sed -n "s/.*$marker screen $wanted_index //p")"

    SCREEN_X=$(t_round "$SCREEN_X")
    SCREEN_Y=$(t_round "$SCREEN_Y")
    SCREEN_W=$(t_round "$SCREEN_W")
    SCREEN_H=$(t_round "$SCREEN_H")
}

# Fills in WINDOW_X, WINDOW_Y, WINDOW_W and WINDOW_H for the window whose
# caption contains "$1".
WINDOW_X=0 ; WINDOW_Y=0 ; WINDOW_W=0 ; WINDOW_H=0
function t_read_window_geometry() {
    local caption_marker="$1"

    # NOTE: The window's own unique marker is part of what the probe prints, and
    # is what the journal is then searched for.
    #
    # A shared tag was used here at first, with "tail -1" picking the most
    # recent line. That silently read the geometry of a PREVIOUS measurement
    # whenever the current window was not found, since the earlier line was
    # still inside the journal window being searched. It produced failures that
    # looked exactly like a real defect, and cost a wrong bug report.
    local marker="WLIW_TEST_GEOM_$caption_marker"

    local output
    output=$(t_kwin_probe "$marker" "
var list = workspace.windowList ? workspace.windowList() : workspace.clientList();
var found = 0;
for (var i = 0; i < list.length; i++) {
    var w = list[i];
    if (w.caption && w.caption.indexOf(\"$caption_marker\") !== -1) {
        found = 1;
        var g = w.frameGeometry;
        print(\"$marker \" + g.x + \" \" + g.y + \" \" + g.width + \" \" + g.height);
    }
}
if (found === 0) { print(\"$marker NOT_FOUND\"); }
")

    local line
    line=$(printf '%s\n' "$output" | grep -F "$marker " | tail -1)
    if [ -z "$line" ] || [[ "$line" == *NOT_FOUND* ]] ; then
        return 1
    fi
    read -r WINDOW_X WINDOW_Y WINDOW_W WINDOW_H \
        <<< "$(printf '%s\n' "$line" | sed -n "s/.*$marker //p")"

    WINDOW_X=$(t_round "$WINDOW_X")
    WINDOW_Y=$(t_round "$WINDOW_Y")
    WINDOW_W=$(t_round "$WINDOW_W")
    WINDOW_H=$(t_round "$WINDOW_H")
}

# The expected rectangle for a regular position code.
#
# NOTE: An independent reimplementation of "window-position.ts" on purpose.
EXPECTED_X=0 ; EXPECTED_Y=0
function t_expected_position() {
    local code="$1"
    local w="$2"
    local h="$3"

    local left=$SCREEN_X
    local top=$SCREEN_Y
    local centre_x=$((SCREEN_X + (SCREEN_W - w) / 2))
    local centre_y=$((SCREEN_Y + (SCREEN_H - h) / 2))
    local right=$((SCREEN_X + (SCREEN_W - w)))
    local bottom=$((SCREEN_Y + (SCREEN_H - h)))

    case "$code" in
        tld) EXPECTED_X=$left     ; EXPECTED_Y=$top ;;
        tc)  EXPECTED_X=$centre_x ; EXPECTED_Y=$top ;;
        trd) EXPECTED_X=$right    ; EXPECTED_Y=$top ;;
        cl)  EXPECTED_X=$left     ; EXPECTED_Y=$centre_y ;;
        c)   EXPECTED_X=$centre_x ; EXPECTED_Y=$centre_y ;;
        cr)  EXPECTED_X=$right    ; EXPECTED_Y=$centre_y ;;
        bld) EXPECTED_X=$left     ; EXPECTED_Y=$bottom ;;
        bc)  EXPECTED_X=$centre_x ; EXPECTED_Y=$bottom ;;
        brd) EXPECTED_X=$right    ; EXPECTED_Y=$bottom ;;
        *)   return 1 ;;
    esac

    # The implementation clamps negatives to 0.
    ((EXPECTED_X < 0)) && EXPECTED_X=0
    ((EXPECTED_Y < 0)) && EXPECTED_Y=0
    return 0
}

# Starts one window through the project and reads its geometry back.
#
#     t_place <code> <extra config lines>
#
# Leaves the answer in WINDOW_X/Y/W/H, and the marker in LAST_MARKER.
LAST_MARKER=""
function t_place() {
    local code="$1"
    local extra="$2"

    local marker="WLIW_T_${code}_$$_${RANDOM}"
    local config_name="wliw_kwin_test_$$"

    LAST_MARKER="$marker"
    STARTED_MARKERS+=("$marker")

    cat > "$PROJECT_DIRECTORY/configs/$config_name.bash" <<CONFIG
read -r -d '' APPLICATION_STARTUP_COMMAND << 'HEREDOC'
BEGIN
konsole -p tabtitle="$marker" -e bash -c 'sleep 120' &
END
HEREDOC

WINDOW_WIDTH=$TEST_WINDOW_WIDTH
WINDOW_HEIGHT=$TEST_WINDOW_HEIGHT
SCREEN_INDEX=$SCREEN_INDEX
WINDOW_POSITION="$code"
WINDOW_MODE=""
KEEP_ABOVE=0
WINDOW_X_POSITION=
WINDOW_Y_POSITION=
KWIN_SCRIPT_CONFIGURATION_LATENCY=$TEST_LATENCY
I_SUPPORT_FREE_SOFTWARE_N_THIS_WORK=1
$extra
CONFIG
    CREATED_CONFIGS+=("$config_name")

    bash "$MAIN_SCRIPT" -c "$config_name" > /dev/null 2>&1

    # Wait for the window to map and for the KWin script to have acted.
    #
    # NOTE: Generous on purpose. Reading too early catches the window at its
    # own initial geometry, before the script has had its say, which shows up
    # as a confusing one-off failure.
    sleep "$(awk -v a="$TEST_LATENCY" 'BEGIN { print a + 2.5 }')"

    local rtn_code=0
    t_read_window_geometry "$marker" || rtn_code=1

    pkill -f "$marker" 2>/dev/null
    rm -f "$PROJECT_DIRECTORY/configs/$config_name.bash"

    return "$rtn_code"
}

echo
echo "============================================================"
echo " WINDOW-LIKE-I-WANT - KWIN SIDE TESTS"
echo "============================================================"
echo

if [ -z "$QDBUS_COMMAND" ] ; then
    echo " SKIPPED: no \"qdbus\" binary found." >&2
    exit 0
fi
if ! "$QDBUS_COMMAND" org.kde.KWin > /dev/null 2>&1 ; then
    echo " SKIPPED: \"org.kde.KWin\" is not on the session bus." >&2
    echo "          These tests need a running KWin session." >&2
    exit 0
fi
if ! journalctl --user --since "-1s" > /dev/null 2>&1 ; then
    echo " SKIPPED: the user journal is not readable, so KWin's" >&2
    echo "          \"print()\" output cannot be read back." >&2
    exit 0
fi
if ! command -v konsole > /dev/null 2>&1 ; then
    echo " SKIPPED: \"konsole\" not found; it is what these tests place." >&2
    exit 0
fi

echo " --- Environment ---"

if t_read_screen_geometry "$SCREEN_INDEX" ; then
    t_report 0 "KWin reports screen $SCREEN_INDEX geometry"
    printf '          %s screen(s); testing on screen %s at %s,%s sized %sx%s\n' \
        "$SCREEN_COUNT" "$SCREEN_INDEX" "$SCREEN_X" "$SCREEN_Y" "$SCREEN_W" "$SCREEN_H"
else
    t_report 1 "KWin reports screen $SCREEN_INDEX geometry" \
        "could not read it; is --screen $SCREEN_INDEX valid? ($SCREEN_COUNT screens)"
    echo
    echo " Cannot continue without the screen geometry."
    exit 1
fi

echo
echo " --- Regular positions (exact geometry) ---"

REGULAR_CODES=(tld tc trd cl c cr bld bc brd)
DOCKING_CODES=(dtl dt dtr dl dr dbl db dbr)

declare -a CODES_TO_RUN=()
if [ -n "$ONLY_CODES" ] ; then
    IFS=',' read -r -a CODES_TO_RUN <<< "$ONLY_CODES"
else
    CODES_TO_RUN=("${REGULAR_CODES[@]}")
    if ((RUN_DOCKING == 1)) ; then
        CODES_TO_RUN+=("${DOCKING_CODES[@]}")
    fi
fi

for code in "${CODES_TO_RUN[@]}" ; do

    is_docking=0
    if [[ " ${DOCKING_CODES[*]} " == *" $code "* ]] ; then
        is_docking=1
    fi

    if ((is_docking == 0)) && ! t_expected_position "$code" \
            "$TEST_WINDOW_WIDTH" "$TEST_WINDOW_HEIGHT" ; then
        t_report 1 "position \"$code\"" "not a known position code"
        continue
    fi

    if ! t_place "$code" ; then
        t_report 1 "position \"$code\"" \
            "the window never appeared, or KWin could not find it by caption"
        continue
    fi

    if ((is_docking == 1)) ; then
        # KWin decides the size when tiling, and it works off the AVAILABLE
        # area rather than the full screen, so only the edge the window was
        # tiled against can be asserted without being fragile about panels.
        centre_x=$((WINDOW_X + WINDOW_W / 2))
        centre_y=$((WINDOW_Y + WINDOW_H / 2))
        screen_mid_x=$((SCREEN_X + SCREEN_W / 2))
        screen_mid_y=$((SCREEN_Y + SCREEN_H / 2))

        want_left=0 ; want_right=0 ; want_top=0 ; want_bottom=0
        case "$code" in
            dl)  want_left=1 ;;
            dr)  want_right=1 ;;
            dt)  want_top=1 ;;
            db)  want_bottom=1 ;;
            dtl) want_top=1 ; want_left=1 ;;
            dtr) want_top=1 ; want_right=1 ;;
            dbl) want_bottom=1 ; want_left=1 ;;
            dbr) want_bottom=1 ; want_right=1 ;;
        esac

        problems=""
        ((want_left   == 1)) && ((centre_x >= screen_mid_x)) && problems="$problems not-left"
        ((want_right  == 1)) && ((centre_x <  screen_mid_x)) && problems="$problems not-right"
        ((want_top    == 1)) && ((centre_y >= screen_mid_y)) && problems="$problems not-top"
        ((want_bottom == 1)) && ((centre_y <  screen_mid_y)) && problems="$problems not-bottom"

        if [ -z "$problems" ] ; then
            t_report 0 "docking \"$code\" tiles against the right edge"
        else
            t_report 1 "docking \"$code\" tiles against the right edge" \
                "got ${WINDOW_X},${WINDOW_Y} ${WINDOW_W}x${WINDOW_H} ($problems)"
        fi
        continue
    fi

    problems=""
    t_near "$WINDOW_X" "$EXPECTED_X" || problems="$problems x=$WINDOW_X(want $EXPECTED_X)"
    t_near "$WINDOW_Y" "$EXPECTED_Y" || problems="$problems y=$WINDOW_Y(want $EXPECTED_Y)"
    t_near "$WINDOW_W" "$TEST_WINDOW_WIDTH"  || problems="$problems w=$WINDOW_W(want $TEST_WINDOW_WIDTH)"
    t_near "$WINDOW_H" "$TEST_WINDOW_HEIGHT" || problems="$problems h=$WINDOW_H(want $TEST_WINDOW_HEIGHT)"

    if [ -z "$problems" ] ; then
        t_report 0 "position \"$code\" -> ${WINDOW_X},${WINDOW_Y} ${WINDOW_W}x${WINDOW_H}"
    else
        t_report 1 "position \"$code\"" "$problems"
    fi

done

if [ -z "$ONLY_CODES" ] ; then

    echo
    echo " --- Absolute coordinates ---"

    # These must win over WINDOW_POSITION.
    absolute_x=$((SCREEN_X + 137))
    absolute_y=$((SCREEN_Y + 91))
    if t_place "c" "WINDOW_X_POSITION=$absolute_x
WINDOW_Y_POSITION=$absolute_y" ; then
        if t_near "$WINDOW_X" "$absolute_x" && t_near "$WINDOW_Y" "$absolute_y" ; then
            t_report 0 "WINDOW_X/Y_POSITION override WINDOW_POSITION"
        else
            t_report 1 "WINDOW_X/Y_POSITION override WINDOW_POSITION" \
                "got ${WINDOW_X},${WINDOW_Y}, wanted ${absolute_x},${absolute_y}"
        fi
    else
        t_report 1 "WINDOW_X/Y_POSITION override WINDOW_POSITION" "no window"
    fi

    echo
    echo " --- Window mode ---"

    if t_place "c" "WINDOW_MODE=\"fs\"" ; then
        # NOTE: Not "== SCREEN_W/H". A fullscreen window here comes back as
        # 1707x1005 on a 1707x1067 screen, so KWin does not hand the whole
        # output to the client. What matters is that the window covers most of
        # the screen and ignored the size the configuration asked for.
        minimum_width=$(( SCREEN_W * 90 / 100 ))
        minimum_height=$(( SCREEN_H * 90 / 100 ))
        if ((WINDOW_W >= minimum_width)) && ((WINDOW_H >= minimum_height)) ; then
            t_report 0 "WINDOW_MODE=fs fills the screen (${WINDOW_W}x${WINDOW_H})"
        else
            t_report 1 "WINDOW_MODE=fs fills the screen" \
                "got ${WINDOW_W}x${WINDOW_H}, wanted at least ${minimum_width}x${minimum_height} on a ${SCREEN_W}x${SCREEN_H} screen"
        fi
    else
        t_report 1 "WINDOW_MODE=fs fills the screen" "no window"
    fi

    echo
    echo " --- Cleanliness ---"

    # Nothing may be left loaded in KWin, and no generated file left in /tmp.
    leftover_scripts=$(find /tmp -maxdepth 1 -name '*.js' -newermt '-30 seconds' 2>/dev/null | wc -l)
    if ((leftover_scripts == 0)) ; then
        t_report 0 "no generated KWin script was left behind in /tmp"
    else
        t_report 1 "no generated KWin script was left behind in /tmp" \
            "$leftover_scripts recent .js file(s) still there"
    fi

    # A bad position code has to be rejected by the KWin side, which reports it
    # through the journal rather than placing the window anywhere.
    if t_place "nonsense_code" > /dev/null 2>&1 ; then
        validation_output=$(journalctl --user --since "-15s" 2>/dev/null \
            | grep "WINDOW_LIKE_I_WANT" | tail -5)
        if [[ "$validation_output" == *"WINDOW_POSITION"* ]] ; then
            t_report 0 "an invalid WINDOW_POSITION is reported by the KWin side"
        else
            t_report 1 "an invalid WINDOW_POSITION is reported by the KWin side" \
                "nothing about it in the journal"
        fi
    else
        # No window found is also acceptable here: the script threw before
        # placing anything.
        t_report 0 "an invalid WINDOW_POSITION does not place the window"
    fi

fi

echo
echo "============================================================"
printf ' TOTAL %s | PASSED %s | FAILED %s\n' "$TESTS_TOTAL" "$TESTS_PASSED" "$TESTS_FAILED"
if ((TESTS_FAILED > 0)) ; then
    echo " FAILED TESTS:"
    for failed_name in "${TESTS_FAILED_NAMES[@]}" ; do
        printf '   . %s\n' "$failed_name"
    done
fi
echo "============================================================"
echo

((TESTS_FAILED == 0)) && exit 0
exit 1
