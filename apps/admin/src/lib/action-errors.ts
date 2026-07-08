type ErrorLike = {
  code?: unknown;
  message?: unknown;
};

export function formatAdminActionError(error: unknown): string {
  const code = errorCode(error);
  const message = errorMessage(error);

  if (code.includes("permission-denied")) {
    return "You do not have permission to complete that admin action.";
  }

  if (code.includes("unauthenticated")) {
    return "Your admin session expired. Sign in again and retry the action.";
  }

  if (code.includes("not-found")) {
    return "The requested admin record could not be found. Refresh the dashboard and try again.";
  }

  if (code.includes("internal") || message.toLowerCase() === "internal") {
    return "Admin action failed because the backend function returned an internal error. Confirm the League Hub admin Cloud Functions are deployed for jdb-league-hub and try again.";
  }

  return message || "Admin action failed. Try again.";
}

function errorCode(error: unknown): string {
  if (!isErrorLike(error) || typeof error.code !== "string") {
    return "";
  }
  return error.code.toLowerCase();
}

function errorMessage(error: unknown): string {
  if (error instanceof Error && error.message) {
    return error.message;
  }
  if (isErrorLike(error) && typeof error.message === "string") {
    return error.message;
  }
  return "";
}

function isErrorLike(error: unknown): error is ErrorLike {
  return error != null && typeof error === "object";
}
