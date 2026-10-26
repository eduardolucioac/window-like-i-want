import { exceptionHandler } from "./exception-handling/exception-handler";
import { ScriptSettings, ScriptSettingsOptions } from "./settings/script-settings";
import { TimerChain } from "./utils/timer-chain";
import { WindowPosition } from "./window/window-position";
import { WindowDock } from "./window/window-dock";
import { WindowMode } from "./window/window-mode";

/**
 * Initializes and starts the main script of the application.
 *
 * Sets up necessary configurations and event handlers before executing the main
 * logic.
 * It initializes the script settings and connects to the 'windowAdded' signal of
 * the workspace to handle new windows.
 */
function startScript(): void {
    let scriptSettings: ScriptSettings;
    exceptionHandler(() => {
        const options: ScriptSettingsOptions = {
            keepAbove: "$keep_above",
            konsolePid: "$konsole_pid",
            hideShowWindowTransformationsLatency:
                "$hide_show_window_transformations_latency",
            screenIndex: "$screen_index",
            windowHeight: "$window_height",
            windowPosition: "$window_position",
            windowMode: "$window_mode",
            windowWidth: "$window_width",
            windowXPosition: "$window_x_position",
            windowYPosition: "$window_y_position",
        };
        scriptSettings = new ScriptSettings(options);
    });

    // @ts-ignore
    // print(scriptSettings.windowPosition);

    // Connects to the KWin workspace's "windowAdded" signal.
    workspace.windowAdded.connect((windowNow: Window) => {
        exceptionHandler(() => {
            if (windowNow.pid === Number(scriptSettings.konsolePid)) {
                const originalOpacity = windowNow.opacity;

                // Hide the window before applying any transformations for better
                // user visual experience.
                windowNow.opacity = 0;

                // Restore the window's opacity after transformations
                const timerChain = new TimerChain();
                timerChain.addTimerChainLink(() => {
                    windowNow.opacity = originalOpacity;
                }, Number(scriptSettings.hideShowWindowTransformationsLatency));
                timerChain.runTimerChain();

                // Configure the window's position and size.
                new WindowPosition(
                    scriptSettings,
                    windowNow
                ).configureWindowXYWidthNHeight();

                // Configure the window's docking position.
                new WindowDock(
                    scriptSettings,
                    windowNow,
                    workspace
                ).configureWindowDock();

                // Configure the window's mode.
                new WindowMode(scriptSettings, windowNow).configureWindowMode();
            }
        });
    });
}

// Start the script.
startScript();

