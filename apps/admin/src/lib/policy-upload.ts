export const POLICY_FILE_MAX_BYTES = 50 * 1024 * 1024;
export const POLICY_CATEGORIES = ["Policy", "Protocol", "Code of Conduct", "Other"] as const;

export function isPolicyFileAllowed(file: Pick<File, "size">): boolean {
  return file.size <= POLICY_FILE_MAX_BYTES;
}

export function policyStoragePath(orgId: string, policyId: string, fileName: string, timestamp = Date.now()): string {
  return `organizations/${orgId}/policies/${policyId}/${timestamp}-${sanitizeStorageFileName(fileName)}`;
}

export async function runReservedPolicyUpload({
  reserve,
  upload,
  finalize,
  cleanupFile,
  cleanupPolicy
}: {
  reserve: () => Promise<void>;
  upload: () => Promise<string>;
  finalize: (fileUrl: string) => Promise<void>;
  cleanupFile: () => Promise<void>;
  cleanupPolicy: () => Promise<void>;
}): Promise<string> {
  await reserve();
  try {
    const fileUrl = await upload();
    await finalize(fileUrl);
    return fileUrl;
  } catch (error) {
    await cleanupFile().catch(() => undefined);
    await cleanupPolicy().catch(() => undefined);
    throw error;
  }
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
