'use strict';

class PlannerV2Error extends Error {
  /**
   * @param {string} code
   * @param {string} message
   * @param {{ httpStatus?: number, details?: object, retryable?: boolean }} [options]
   */
  constructor(code, message, options = {}) {
    super(message);
    this.name = 'PlannerV2Error';
    this.code = code;
    this.httpStatus = options.httpStatus || 400;
    this.details = options.details || {};
    this.retryable = options.retryable === true;
  }

  toSafeResponse() {
    return {
      status: 'error',
      error: {
        code: this.code,
        message: this.message,
        retryable: this.retryable,
        details: this.details,
      },
    };
  }
}

module.exports = {
  PlannerV2Error,
};
