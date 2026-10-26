#!/bin/bash

# Bash version check.
if ((BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 3))); then
    echo "window-like-i-want require BASH version 4.3 or higher."
    exit 1
fi

# Where this project lives, so every path below is resolved against it rather
# than against the directory the shell happens to be in.
#
# NOTE: The SYMLINK is resolved first. The usual way to install this is to link
# it into "~/.local/bin", and without "readlink -f" the directory would be the
# one holding the link, where none of the files below exist.
SCRIPT_PATH="$( readlink -f "${BASH_SOURCE[0]}" 2> /dev/null || echo "${BASH_SOURCE[0]}" )"
SCRIPT_DIRECTORY="$( cd "$( dirname "$SCRIPT_PATH" )" && pwd )"

source "$SCRIPT_DIRECTORY/bash-script/utils/qdbus.bash"
source "$SCRIPT_DIRECTORY/bash-script/utils/prog-concepts.bash"
source "$SCRIPT_DIRECTORY/bash-script/trap/trap.bash"
source "$SCRIPT_DIRECTORY/bash-script/dialog/dialog-box.bash"
source "$SCRIPT_DIRECTORY/bash-script/dialog/color-scheme.bash"
source "$SCRIPT_DIRECTORY/bash-script/dialog/dialog.bash"
source "$SCRIPT_DIRECTORY/bash-script/error-handling/error-handling.bash"
source "$SCRIPT_DIRECTORY/bash-script/options/options.bash"
source "$SCRIPT_DIRECTORY/configs/$CONFIG_TO_USE.bash"
source "$SCRIPT_DIRECTORY/bash-script/utils/utils.bash"
source "$SCRIPT_DIRECTORY/bash-script/window/window.bash"
source "$SCRIPT_DIRECTORY/bash-script/controller.bash"

exit 0

# https://blog.martin-graesslin.com/blog/2012/01/kwin-effects-written-in-javascript/
# https://develop.kde.org/docs/plasma/kwin/
# https://develop.kde.org/docs/plasma/kwin/api/
# https://develop.kde.org/docs/plasma/kwin/api/#kwinwindow
# https://develop.kde.org/docs/plasma/kwin/api/#kwinworkspacewrapper
# https://discuss.kde.org/t/kwin-script-to-set-window-positions-on-spawn-in-plasma-6/11804
# https://discuss.kde.org/t/kwin-script-window-framegeometry-seems-to-be-readonly-even-if-the-docs-states-otherwise/17175/2
# https://discuss.kde.org/t/kwin-scripting-from-5-x-to-6-x-compatible/2905/12
# https://discuss.kde.org/t/kwin-scripting-from-5-x-to-6-x-compatible/2905/32
# https://www.reddit.com/r/kde/comments/1as427n/comment/kqr655w/?utm_source=share&utm_medium=web3x&utm_name=web3xcss&utm_term=1&utm_content=share_button
# https://www.reddit.com/r/kde/comments/1bb2xo1/comment/ku794pg/
# https://www.reddit.com/r/kde/comments/wcfqqu/comment/iiknu4q/?utm_source=share&utm_medium=web3x&utm_name=web3xcss&utm_term=1&utm_content=share_button

