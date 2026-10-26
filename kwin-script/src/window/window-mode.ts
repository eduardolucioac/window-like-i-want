import { ScriptSettings } from "../settings/script-settings";

/**
 * Class to configure window's mode.
 *
 * Handles maximizing, minimizing, and setting the window to fullscreen.
 * Also manages whether the window stays above other windows.
 */
class WindowMode {
    /** The values this run was configured with. */
    private scriptSettings: ScriptSettings;

    /** The window whose mode is being set. */
    private windowNow: Window;

    /**
     * @param scriptSettings - The script settings containing window
     * mode configurations.
     * @param windowNow - The current window object to be manipulated.
     */
    constructor(scriptSettings: ScriptSettings, windowNow: Window) {
        this.scriptSettings = scriptSettings;
        this.windowNow = windowNow;
    }

    /**
     * Configure the window mode based on script settings.
     *
     * Sets the window to maximized, minimized, or fullscreen.
     * Also sets the window to stay above other windows if specified.
     */
    public configureWindowMode(): void {
        switch (this.scriptSettings.windowMode) {
            case "mx":
                // Maximized
                this.windowNow.setMaximize(true, true);
                break;
            case "mn":
                // Minimized
                this.windowNow.minimized = true;
                break;
            case "fs":
                // Full Screen
                this.windowNow.fullScreen = true;
                break;
        }

        // Keep the window above all other windows.
        this.windowNow.keepAbove = this.scriptSettings.keepAbove;
    }
}

export { WindowMode };

