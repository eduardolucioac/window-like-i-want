import {
    windowValidRegularPositions,
    windowValidDockPositions,
    windowValidModes,
} from "../constant/constant";
import { ValidationError } from "../exception-handling/exception/validation-error";

/**
 * The raw settings, exactly as BASH substituted them into this script.
 *
 * Every field is a STRING, including the numbers: they arrive as text and are
 * parsed and validated by the constructor of "ScriptSettings". An empty string
 * means "not set".
 */
interface ScriptSettingsOptions {
    keepAbove?: string;
    konsolePid?: string;
    hideShowWindowTransformationsLatency?: string;
    screenIndex?: string;
    windowHeight?: string;
    windowWidth?: string;
    windowPosition?: string;
    windowMode?: string;
    windowXPosition?: string;
    windowYPosition?: string;
}

/**
 * Class representing the script settings.
 * Validates and stores configuration options.
 */
class ScriptSettings {
    keepAbove: boolean;
    konsolePid: number;
    hideShowWindowTransformationsLatency: number;
    windowHeight: number;
    windowWidth: number;
    screenIndex: number;
    windowPosition: string;
    windowMode: string;
    windowXPosition: number;
    windowYPosition: number;

    /**
     * Create a ScriptSettings instance.
     *
     * @param options - Configuration options.
     * @throws ValidationError Throws if any of the options are invalid.
     */
    constructor(options: ScriptSettingsOptions = {}) {
        const {
            keepAbove = "",
            konsolePid = "",
            hideShowWindowTransformationsLatency = "",
            screenIndex = "",
            windowHeight = "",
            windowPosition = "",
            windowMode = "",
            windowWidth = "",
            windowXPosition = "",
            windowYPosition = "",
        } = options;

        this.keepAbove = keepAbove === "1";

        this.konsolePid = this.parseInteger(konsolePid, "KONSOLE_PID");

        this.hideShowWindowTransformationsLatency = this.parseInteger(
            hideShowWindowTransformationsLatency,
            "hide_show_window_transformations_latency"
        );

        this.windowHeight =
            windowHeight !== ""
                ? this.validatePositiveInteger(windowHeight, "WINDOW_HEIGHT")
                : -1;

        this.windowWidth =
            windowWidth !== ""
                ? this.validatePositiveInteger(windowWidth, "WINDOW_WIDTH")
                : -1;

        this.screenIndex =
            screenIndex !== ""
                ? this.validateScreenIndex(
                      this.validatePositiveInteger(screenIndex, "SCREEN_INDEX"),
                      workspace.screens.length
                  )
                : -1;

        this.windowPosition =
            windowPosition !== ""
                ? this.validateAgainstAList(
                      windowPosition,
                      "WINDOW_POSITION",
                      windowValidRegularPositions.concat(
                          windowValidDockPositions
                      )
                  )
                : "";

        this.windowMode =
            windowMode !== ""
                ? this.validateAgainstAList(
                      windowMode,
                      "WINDOW_MODE",
                      windowValidModes
                  )
                : "";

        this.windowXPosition =
            windowXPosition !== ""
                ? this.validatePositiveInteger(
                      windowXPosition,
                      "WINDOW_X_POSITION"
                  )
                : -1;

        this.windowYPosition =
            windowYPosition !== ""
                ? this.validatePositiveInteger(
                      windowYPosition,
                      "WINDOW_Y_POSITION"
                  )
                : -1;
    }

    /**
     * Parse a string value to an integer.
     *
     * @param value - The value to parse.
     * @param itemName - The name of the item being parsed.
     * @returns The parsed integer.
     * @throws ValidationError Throws if the value is not a valid integer.
     */
    private parseInteger(value: string, itemName: string): number {
        const parsedValue = parseInt(value, 10);
        if (isNaN(parsedValue)) {
            throw new ValidationError(
                'The "' + itemName + '" must be a valid integer.'
            );
        }
        return parsedValue;
    }

    /**
     * Validate that a value is a positive integer.
     *
     * @param value - The value to validate.
     * @param itemName - The name of the item being validated.
     * @returns The validated positive integer.
     * @throws ValidationError Throws if the value is not a positive integer.
     */
    private validatePositiveInteger(value: string, itemName: string): number {
        const parsedValue = this.parseInteger(value, itemName);
        if (parsedValue < 0) {
            throw new ValidationError(
                'The "' + itemName + '" must be a positive integer value.'
            );
        }
        return parsedValue;
    }

    /**
     * Validate that a value is one of the valid values.
     *
     * @param value - The value to validate.
     * @param itemName - The name of the item being validated.
     * @param validValues - The list of valid values.
     * @returns The validated value.
     * @throws ValidationError Throws if the value is not in the list of valid values.
     */
    private validateAgainstAList(
        value: string,
        itemName: string,
        validValues: string[]
    ): string {
        if (!validValues.includes(value)) {
            throw new ValidationError(
                'The "' + itemName + '" must be one of the following values: ' + validValues.join(
                    ", "
                ) + '.'
            );
        }
        return value;
    }

    /**
     * Validate that a screen index is within the valid range.
     *
     * @param value - The screen index to validate.
     * @param screensLength - The number of available screens.
     * @returns The validated screen index.
     * @throws ValidationError Throws if the screen index is invalid.
     */
    private validateScreenIndex(value: number, screensLength: number): number {
        if (value >= screensLength) {
            throw new ValidationError(
                'Invalid "SCREEN_INDEX". Must be less than or equal to ' +
                    (screensLength - 1)
                + '.'
            );
        }
        return value;
    }
}

export { ScriptSettings, ScriptSettingsOptions };

