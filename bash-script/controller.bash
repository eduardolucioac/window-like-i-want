function f_controller() {
    : 'Drive one run: start the application, then have KWin place its window.

    The configuration variables read here come from the file that
    "window-like-i-want.bash" sourced out of "configs".
    '

    # NOTE: "f_class_constructor" treats a required attribute as satisfied by an
    # empty string, and an empty latency reaches "sleep" below as "sleep """.
    # Fall back to the documented default instead.
    if [ -z "$KWIN_SCRIPT_CONFIGURATION_LATENCY" ] ; then
        echo "WARNING! \"KWIN_SCRIPT_CONFIGURATION_LATENCY\" is not set. Using \"1.0\"." >&2
        KWIN_SCRIPT_CONFIGURATION_LATENCY=1.0
    fi

    local -A window_obj
    c_window.f_new window_obj \
        application_startup_command "$APPLICATION_STARTUP_COMMAND" \
        config_to_use "$CONFIG_TO_USE" \
        execution_uuid "$EXECUTION_UUID" \
        keep_above "$KEEP_ABOVE" \
        kwin_script_configuration_latency "$KWIN_SCRIPT_CONFIGURATION_LATENCY" \
        screen_index "$SCREEN_INDEX" \
        window_height "$WINDOW_HEIGHT" \
        window_mode "$WINDOW_MODE" \
        window_position "$WINDOW_POSITION" \
        window_width "$WINDOW_WIDTH" \
        window_x_position "$WINDOW_X_POSITION" \
        window_y_position "$WINDOW_Y_POSITION" || {
            f_error_handling "The configuration \"$CONFIG_TO_USE\" is incomplete or invalid."
            return 1
        }

    if ((DRY_RUN == 1)) ; then
        # Nothing is started, so there is no real PID to substitute. A sentinel
        # keeps the generated script valid and obviously inert.
        window_obj['konsole_pid']=0
    else
        c_window.f_start_application window_obj || {
            f_error_handling "Unable to start the application of the configuration \"$CONFIG_TO_USE\"."
            return 1
        }
    fi

    # NOTE: Every step is checked. Letting a failed step fall through used to
    # leave the KWin script loaded and the window unconfigured.
    c_window.f_prepare_configuration window_obj || {
        f_error_handling "Unable to prepare the KWin script for the configuration \"$CONFIG_TO_USE\"."
        return 1
    }

    c_window.f_set_configuration window_obj || {
        f_error_handling "Unable to load the KWin script through D-Bus. Is this a KWin session?"
        return 1
    }

    if ((DRY_RUN == 1)) ; then
        return 0
    fi

    # Execute code asynchronously using a subshell.
    (
        sleep "$KWIN_SCRIPT_CONFIGURATION_LATENCY"

        c_window.f_unset_configuration window_obj

        if [ -n "$KILL_WINDOW_FOR_DEBUG" ] &&\
                [ "$KILL_WINDOW_FOR_DEBUG" -eq 1 ]; then
            sleep 1
            kill "${window_obj['konsole_pid']}"
        fi
    ) &

    f_ask_support

}

f_controller || exit 1

