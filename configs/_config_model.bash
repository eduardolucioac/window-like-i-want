# _template.bash - Copy this to start a new configuration.
#
#     cp _template.bash myapp.bash
#     ../window-like-i-want.bash -c myapp
#
# Names starting with "_" are templates: they are not listed by "--help" and
# cannot be run. Full reference: ../docs/configuration.md

# REQUIRED. The command to run. It MUST end with "&": the window is matched by
# its PID, and a foreground command never reports one. An application that
# hands the request to an already running instance (most browsers) cannot be
# targeted this way.
read -r -d '' APPLICATION_STARTUP_COMMAND << 'HEREDOC'
BEGIN
your-command-here &
END
HEREDOC

# Size in pixels. Empty for both keeps the size the window opens with.
WINDOW_WIDTH=
WINDOW_HEIGHT=

# Which screen, 0-based, in KWin's order rather than the one shown in System
# Settings. Empty keeps the screen the window opened on.
SCREEN_INDEX=

# Where on that screen.
#   regular .. tld tc trd / cl c cr / bld bc brd
#   docking .. dtl dt dtr / dl    dr / dbl db dbr   (KWin picks the size)
WINDOW_POSITION="c"

# mx maximized | mn minimized | fs fullscreen | empty for a normal window.
WINDOW_MODE=""

# 1 keeps the window above the others.
KEEP_ABOVE=0

# Absolute coordinates, which WIN over WINDOW_POSITION. Set both or neither.
WINDOW_X_POSITION=
WINDOW_Y_POSITION=

# Seconds to wait for the window to appear. Raise it for a slow application: a
# window that arrives after this has elapsed is never configured.
KWIN_SCRIPT_CONFIGURATION_LATENCY=1.0

# 1 closes the window a second after placing it. Useful while trying positions
# out, so you are not left with a pile of windows.
KILL_WINDOW_FOR_DEBUG=0

# 1 keeps what this run does to the window out of your own settings.
#
# An application records the size of its last window so the next one reopens
# the same way. Without this, the window THIS project resizes is what it
# records, and the next window you open by hand comes up that size. With it,
# that bookkeeping goes to a directory of this configuration instead.
#
# Set it to 0 only if you want the application to share its state with the rest
# of your desktop.
ISOLATE_APPLICATION_STATE=1

# 1 silences the support notice.
I_SUPPORT_FREE_SOFTWARE_N_THIS_WORK=0

# window-like-i-want - Window Like I Want "inverted (c)" BSD-3-Clause
# Eduardo Lucio Amorim Costa
# Brazil-ES
# https://www.linkedin.com/in/eduardo-software-livre/
