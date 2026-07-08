export const POLICY_FILE_MAX_BYTES = 50 * 1024 * 1024;

export function isPolicyFileAllowed(file: Pick<File, "size">): boolean {
  return file.size <= POLICY_FILE_MAX_BYTES;
}

export function policyStoragePath(orgId: string, policyId: string, fileName: string, timestamp = Date.now()): string {
  return `organizations/${orgId}/policies/${policyId}/${timestamp}-${sanitizeStorageFileName(fileName)}`;
}

export function sanitizeStorageFileName(fileName: string): string {
  const sanitized = fileName
    .trim()
    .replace(/\s+/g, "-")
    .replace(/[^a-zA-Z0-9._-]/g, "")
    .replace(/^[.-]+/, "")
    .slice(0, 120);

  return sanitized || "policy-file";
}
