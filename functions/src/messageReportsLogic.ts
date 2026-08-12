export function messageReportIdempotencyKey(
  orgId: string,
  reportId: string,
): string {
  return `league-hub-report-${orgId}-${reportId}`;
}

export function requireSuccessfulMessageReportDelivery(
  status: number,
  responseBody: string,
): void {
  if (status >= 200 && status < 300) return;
  throw new Error(
    `Safety report delivery failed (${status}): ${responseBody.slice(0, 500)}`,
  );
}
