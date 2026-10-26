// Declare global CLASSES provided by KWin's scripting environment

/**
 * Qt's single shot / repeating timer, as exposed to KWin scripts.
 *
 * The only scheduling primitive available here: there is no setTimeout.
 */
declare class QTimer {
    constructor();
    timeout: {
        connect(callback: () => void): void;
    };
    start(msec: number): void;
    stop(): void;
}

// Declare global VARIABLES provided by KWin's scripting environment

declare function print(message: string): void;

declare const workspace: Workspace;

/** The KWin workspace: the screens, the windows, and the actions on them. */
interface Workspace {
    windowAdded: {
        connect(callback: (window: Window) => void): void;
    };
    screens: Screen[];
    activeWindow: Window;
    slotWindowQuickTileBottom(): void;
    slotWindowQuickTileBottomLeft(): void;
    slotWindowQuickTileBottomRight(): void;
    slotWindowQuickTileLeft(): void;
    slotWindowQuickTileRight(): void;
    slotWindowQuickTileTop(): void;
    slotWindowQuickTileTopLeft(): void;
    slotWindowQuickTileTopRight(): void;
}

/** One output. */
interface Screen {
    geometry: Geometry;
}

/**
 * A rectangle, in KWin's LOGICAL pixels.
 *
 * NOTE: Not necessarily whole numbers. On a fractionally scaled output a
 * width of 823 comes back as 823.3333333333335.
 */
interface Geometry {
    x: number;
    y: number;
    width: number;
    height: number;
}

/**
 * One window.
 *
 * NOTE: Assigning to "frameGeometry" is ASYNCHRONOUS. Reading it back on the
 * next line still returns the old rectangle; the new one appears a few tens of
 * milliseconds later.
 */
interface Window {
    pid: number;
    opacity: number;
    minimized: boolean;
    fullScreen: boolean;
    keepAbove: boolean;
    x: number;
    y: number;
    width: number;
    height: number;
    frameGeometry: Geometry;
    setMaximize(horizontal: boolean, vertical: boolean): void;
}
