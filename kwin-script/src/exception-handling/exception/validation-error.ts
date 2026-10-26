/**
 * Represents a validation error.
 *
 * This error is thrown when validation of input fails.
 * @extends Error
 */
class ValidationError extends Error {
    /**
     * Create a ValidationError instance.
     *
     * @param message - The error message describing the validation failure.
     */
    constructor(message: string) {
        super(message);
        this.name = "ValidationError";

        // When extending built-in classes like Error in TypeScript, especially when
        // targeting ES5, there can be issues with the prototype chain. To ensure
        // that the instanceof checks work correctly, it's recommended to set the
        // prototype explicitly using Object.setPrototypeOf(this, ValidationError.prototype);.
        // This line ensures that ValidationError instances are correctly recognized
        // as instances of ValidationError.
        Object.setPrototypeOf(this, ValidationError.prototype);
    }
}

export { ValidationError };

