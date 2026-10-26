import { ScriptSettings } from "../settings/script-settings";

/**
 * Class to dock a window.
 *
 * Handles docking the window to specified positions based on script settings.
 */
class WindowDock {
    /** The values this run was configured with. */
    private scriptSettings: ScriptSettings;

    /** The window being docked. */
    private windowNow: Window;

    /** Needed because the tiling slots act on the ACTIVE window. */
    private workspace: Workspace;

    /**
     * @param scriptSettings - The settings for the script.
     * @param windowNow - The current window object.
     * @param workspace - The workspace object.
     */
    constructor(
        scriptSettings: ScriptSettings,
        windowNow: Window,
        workspace: Workspace
    ) {
        this.scriptSettings = scriptSettings;
        this.windowNow = windowNow;
        this.workspace = workspace;
    }

    /**
     * Configure the window docking position based on script settings.
     *
     * Adjusts the window's position by docking it to the specified screen edge or
     * corner.
     */
    public configureWindowDock(): void {
        // Ensure that the active window is the window we are configuring.
        this.workspace.activeWindow = this.windowNow;

        switch (this.scriptSettings.windowPosition) {
            case "db":
                // Docking Bottom
                this.workspace.slotWindowQuickTileBottom();
                break;
            case "dbl":
                // Docking Bottom Left
                this.workspace.slotWindowQuickTileBottomLeft();
                break;
            case "dbr":
                // Docking Bottom Right
                this.workspace.slotWindowQuickTileBottomRight();
                break;
            case "dl":
                // Docking Left
                this.workspace.slotWindowQuickTileLeft();
                break;
            case "dr":
                // Docking Right
                this.workspace.slotWindowQuickTileRight();
                break;
            case "dt":
                // Docking Top
                this.workspace.slotWindowQuickTileTop();
                break;
            case "dtl":
                // Docking Top Left
                this.workspace.slotWindowQuickTileTopLeft();
                break;
            case "dtr":
                // Docking Top Right
                this.workspace.slotWindowQuickTileTopRight();
                break;
            default:
                // Handle default or invalid cases if necessary
                break;
        }
    }
}

export { WindowDock };

