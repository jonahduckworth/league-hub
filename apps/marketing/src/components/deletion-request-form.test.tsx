import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { DeletionRequestForm } from "./deletion-request-form";

afterEach(() => vi.restoreAllMocks());

describe("DeletionRequestForm", () => {
  it("submits an account deletion request and explains verification", async () => {
    const fetchMock = vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(JSON.stringify({ ok: true }), { status: 200 }),
    );
    render(<DeletionRequestForm />);

    fireEvent.change(screen.getByLabelText("League Hub account email"), {
      target: { value: "reviewer@example.com" },
    });
    fireEvent.change(screen.getByLabelText("Organization or league"), {
      target: { value: "Demo Hockey League" },
    });
    fireEvent.click(screen.getByRole("button", { name: "Request deletion" }));

    await waitFor(() => expect(fetchMock).toHaveBeenCalledOnce());
    const body = JSON.parse(String(fetchMock.mock.calls[0][1]?.body));
    expect(body.inquiryType).toBe("account_deletion");
    expect(body.startedAt).toBeGreaterThan(0);
    expect(await screen.findByText("Request received")).toBeInTheDocument();
  });
});
