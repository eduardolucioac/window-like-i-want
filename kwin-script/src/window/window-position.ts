import { windowValidRegularPositions } from "../constant/constant";
import { ScriptSettings } from "../settings/script-settings";

/** A window size, in pixels. */
interface WindowDimensions {
  windowWidth: number;
  windowHeight: number;
}

/**
 * Where to place a window: which screen, which position code, and whether to
 * leave the coordinates it already has alone.
 */
interface ScreenIndexAndPosition {
  windowPosition: string;
  screenIndex: number;
  useXYPreviousValues: boolean;
}

/** A window position, in pixels. */
interface WindowPositionXY {
  windowXPosition: number;
  windowYPosition: number;
}

/**
 * Class to configure window's position and size configurations.
 *
 * Handles the window to the specified positions based on script settings.
 */
class WindowPosition {
  /** The values this run was configured with. */
  private scriptSettings: ScriptSettings;

  /** The window being placed. */
  private windowNow: Window;

  /** Cached by "getLastScreenIndex", which is called more than once. */
  private lastScreenIndex?: number;

  /** Cached by "defineWindowWidthNHeight", which is called more than once. */
  private windowWidthNHeight?: WindowDimensions;

  /**
   * @param scriptSettings - The settings for the script.
   * @param windowNow - The current window object.
   */
  constructor(scriptSettings: ScriptSettings, windowNow: Window) {
    this.scriptSettings = scriptSettings;
    this.windowNow = windowNow;
    this.lastScreenIndex = undefined;
    this.windowWidthNHeight = undefined;
  }

  /**
   * Get the last screen index that contained the given window position.
   *
   * @param windowXPosition - The X position of the window.
   * @param windowYPosition - The Y position of the window.
   * @returns The screen index.
   */
  public getLastScreenIndex(
    windowXPosition: number,
    windowYPosition: number
  ): number {
    if (this.lastScreenIndex !== undefined) {
      return this.lastScreenIndex;
    }

    this.lastScreenIndex = 0;
    let screenGeometry: Geometry;
    let screenWidthBegin: number;
    let screenHeightBegin: number;
    let screenWidth: number;
    let screenHeight: number;

    for (let i = 0; i < workspace.screens.length; i++) {
      screenGeometry = workspace.screens[i].geometry;
      screenWidthBegin = screenGeometry.x;
      screenHeightBegin = screenGeometry.y;
      screenWidth = screenGeometry.width;
      screenHeight = screenGeometry.height;

      if (
        windowXPosition >= screenWidthBegin &&
        windowXPosition < screenWidthBegin + screenWidth &&
        windowYPosition >= screenHeightBegin &&
        windowYPosition < screenHeightBegin + screenHeight
      ) {
        this.lastScreenIndex = i;
        break;
      }
    }

    return this.lastScreenIndex;
  }

  /**
   * Calculate a width and height for the window based on the width and height
   * of the selected screen index. The returned value will be 70% of the respective
   * width and height of the selected screen index.
   *
   * @param screenIndex - The index of the screen.
   * @returns An object containing the window width and height.
   */
  private calculateWindowWidthNHeight(screenIndex: number): WindowDimensions {
    const screenGeometry = workspace.screens[screenIndex].geometry;
    const screenWidth = screenGeometry.width;
    const screenHeight = screenGeometry.height;

    return {
      windowWidth: Math.floor(screenWidth * 0.7),
      windowHeight: Math.floor(screenHeight * 0.7),
    };
  }

  /**
   * Define the window's width and height based on script settings or current window
   * dimensions.
   *
   * @returns An object containing the window width and height.
   */
  private defineWindowWidthNHeight(): WindowDimensions {
    if (this.windowWidthNHeight !== undefined) {
      return this.windowWidthNHeight;
    }

    let windowWidth: number;
    let windowHeight: number;

    if (
      this.scriptSettings.windowWidth !== -1 ||
      this.scriptSettings.windowHeight !== -1
    ) {
      windowWidth = this.scriptSettings.windowWidth;
      windowHeight = this.scriptSettings.windowHeight;
    } else if (this.scriptSettings.screenIndex !== -1) {
      if (
        this.scriptSettings.screenIndex !==
        this.getLastScreenIndex(this.windowNow.x, this.windowNow.y)
      ) {
        const calculatedDimensions = this.calculateWindowWidthNHeight(
          this.scriptSettings.screenIndex
        );
        windowWidth = calculatedDimensions.windowWidth;
        windowHeight = calculatedDimensions.windowHeight;
      } else {
        windowWidth = this.windowNow.width;
        windowHeight = this.windowNow.height;
      }
    } else {
      windowWidth = this.windowNow.width;
      windowHeight = this.windowNow.height;
    }

    this.windowWidthNHeight = {
      windowWidth: windowWidth,
      windowHeight: windowHeight,
    };

    return this.windowWidthNHeight;
  }

  /**
   * Configure the window's position and size.
   *
   * Sets the frameGeometry of the windowNow object.
   */
  public configureWindowXYWidthNHeight(): void {
    let windowXPosition: number;
    let windowYPosition: number;
    const windowDimensions = this.defineWindowWidthNHeight();

    if (
      this.scriptSettings.windowXPosition !== -1 ||
      this.scriptSettings.windowYPosition !== -1
    ) {
      windowXPosition = this.scriptSettings.windowXPosition;
      windowYPosition = this.scriptSettings.windowYPosition;
    } else {
      const screenIndexNPosition = this.defineScreenIndexNPosition();
      if (screenIndexNPosition.useXYPreviousValues) {
        windowXPosition = this.windowNow.x;
        windowYPosition = this.windowNow.y;
      } else {
        const windowXYPosition = this.calculateWindowXYPosition(
          windowDimensions.windowWidth,
          windowDimensions.windowHeight,
          screenIndexNPosition.screenIndex,
          screenIndexNPosition.windowPosition
        );
        windowXPosition = windowXYPosition.windowXPosition;
        windowYPosition = windowXYPosition.windowYPosition;
      }
    }

    this.windowNow.frameGeometry = {
      x: windowXPosition,
      y: windowYPosition,
      width: windowDimensions.windowWidth,
      height: windowDimensions.windowHeight,
    };
  }

  /**
   * Define the screen index and window position.
   *
   * @returns An object containing the window position,
   * screen index, and whether to use previous XY values.
   */
  private defineScreenIndexNPosition(): ScreenIndexAndPosition {
    let windowPosition = this.scriptSettings.windowPosition;
    let screenIndex: number;
    const lastScreenIndex = this.getLastScreenIndex(
      this.windowNow.x,
      this.windowNow.y
    );
    let useXYPreviousValues = false;

    if (this.scriptSettings.screenIndex !== -1) {
      screenIndex = this.scriptSettings.screenIndex;
      if (
        !windowValidRegularPositions.includes(
          this.scriptSettings.windowPosition
        )
      ) {
        if (this.scriptSettings.screenIndex !== lastScreenIndex) {
          windowPosition = "c";
        } else {
          useXYPreviousValues = true;
        }
      }
    } else if (lastScreenIndex > workspace.screens.length - 1) {
      screenIndex = 0;
      if (
        !windowValidRegularPositions.includes(
          this.scriptSettings.windowPosition
        )
      ) {
        windowPosition = "c";
      }
    } else {
      screenIndex = lastScreenIndex;
      if (
        !windowValidRegularPositions.includes(
          this.scriptSettings.windowPosition
        )
      ) {
        useXYPreviousValues = true;
      }
    }

    return {
      windowPosition: windowPosition,
      screenIndex: screenIndex,
      useXYPreviousValues: useXYPreviousValues,
    };
  }

  /**
   * Calculate the window's X and Y position based on its size, screen index, and
   * desired position.
   *
   * @param windowWidth - The width of the window.
   * @param windowHeight - The height of the window.
   * @param screenIndex - The index of the screen.
   * @param windowPosition - The desired window position (e.g., "tld",
   * "tc", "trd").
   * @returns An object containing the window's X and Y position.
   */
  private calculateWindowXYPosition(
    windowWidth: number,
    windowHeight: number,
    screenIndex: number,
    windowPosition: string
  ): WindowPositionXY {
    const screenGeometry = workspace.screens[screenIndex].geometry;
    const screenWidthBegin = screenGeometry.x;
    const screenHeightBegin = screenGeometry.y;
    const screenWidth = screenGeometry.width;
    const screenHeight = screenGeometry.height;

    let windowXPosition = 0;
    let windowYPosition = 0;

    switch (windowPosition) {
      case "tld":
        windowXPosition = screenWidthBegin;
        windowYPosition = screenHeightBegin;
        break;
      case "tc":
        windowXPosition =
          screenWidthBegin + Math.floor((screenWidth - windowWidth) / 2);
        windowYPosition = screenHeightBegin;
        break;
      case "trd":
        windowXPosition = screenWidthBegin + (screenWidth - windowWidth);
        windowYPosition = screenHeightBegin;
        break;
      case "cl":
        windowXPosition = screenWidthBegin;
        windowYPosition =
          screenHeightBegin + Math.floor((screenHeight - windowHeight) / 2);
        break;
      case "c":
        windowXPosition =
          screenWidthBegin + Math.floor((screenWidth - windowWidth) / 2);
        windowYPosition =
          screenHeightBegin + Math.floor((screenHeight - windowHeight) / 2);
        break;
      case "cr":
        windowXPosition = screenWidthBegin + (screenWidth - windowWidth);
        windowYPosition =
          screenHeightBegin + Math.floor((screenHeight - windowHeight) / 2);
        break;
      case "bld":
        windowXPosition = screenWidthBegin;
        windowYPosition = screenHeightBegin + (screenHeight - windowHeight);
        break;
      case "bc":
        windowXPosition =
          screenWidthBegin + Math.floor((screenWidth - windowWidth) / 2);
        windowYPosition = screenHeightBegin + (screenHeight - windowHeight);
        break;
      case "brd":
        windowXPosition = screenWidthBegin + (screenWidth - windowWidth);
        windowYPosition = screenHeightBegin + (screenHeight - windowHeight);
        break;
    }

    return {
      windowXPosition: windowXPosition < 0 ? 0 : windowXPosition,
      windowYPosition: windowYPosition < 0 ? 0 : windowYPosition,
    };
  }
}

export { WindowPosition };

