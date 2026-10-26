import { ValidationError } from "./exception/validation-error";

/**
 * Handles exceptions thrown by the provided function.
 *
 * If a ValidationError is caught, it prints a formatted error message.
 * Otherwise, it prints the error message and stack trace.
 *
 * @param functionToHandler - The function to execute and handle exceptions for.
 */
function exceptionHandler(functionToHandler: () => void): void {
  try {
    functionToHandler();
  } catch (e: unknown) {
    if (e instanceof ValidationError) {
      print(
        "[WINDOW_LIKE_I_WANT $config_to_use $execution_uuid] ERROR: " +
          e.message
      );
    } else if (e instanceof Error) {
      print(
        "[WINDOW_LIKE_I_WANT $config_to_use $execution_uuid]\nERROR: " +
          e.message +
          "\nSTACK TRACE: " +
          e.stack
      );
    } else {
      print(
        "[WINDOW_LIKE_I_WANT $config_to_use $execution_uuid]\nUNKNOWN ERROR!"
      );
    }
  }
}

export { exceptionHandler };

