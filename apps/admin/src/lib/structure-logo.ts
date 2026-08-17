export const maxStructureLogoBytes = 10 * 1024 * 1024;

const supportedStructureLogoTypes = new Set([
  "image/jpeg",
  "image/png",
  "image/webp"
]);

export function validateStructureLogoFile(
  file: Pick<File, "name" | "size" | "type">
): string | null {
  if (!supportedStructureLogoTypes.has(file.type)) {
    return "Choose a PNG, JPG, or WebP image.";
  }
  if (file.size <= 0) return "The selected logo file is empty.";
  if (file.size > maxStructureLogoBytes) {
    return "Logo files must be 10 MB or smaller.";
  }
  return null;
}

export function structureLogoStoragePath({
  orgId,
  entityType,
  entityId,
  userId,
  fileName,
  timestamp = Date.now()
}: {
  orgId: string;
  entityType: "league" | "hub" | "team";
  entityId: string;
  userId: string;
  fileName: string;
  timestamp?: number;
}): string {
  const safeName = fileName.replace(/[^a-zA-Z0-9._-]/g, "_");
  return `orgs/${orgId}/logos/${entityType}/${entityId}/${userId}/${timestamp}_${safeName}`;
}
