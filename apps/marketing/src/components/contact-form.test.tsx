import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { ContactForm } from "./contact-form";

afterEach(() => vi.restoreAllMocks());

describe("ContactForm", () => {
  it("submits pricing inquiries and shows success", async () => {
    const fetchMock = vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(JSON.stringify({ ok: true }), { status: 200 }),
    );
    render(<ContactForm />);

    fireEvent.change(screen.getByLabelText("Your name"), { target: { value: "Jordan Davis" } });
    fireEvent.change(screen.getByLabelText("Work email"), { target: { value: "jordan@example.com" } });
    fireEvent.change(screen.getByLabelText("League or organization"), { target: { value: "Premier League" } });
    fireEvent.change(screen.getByLabelText("What would make League Hub valuable for you?"), {
      target: { value: "A single place for our league information." },
    });
    fireEvent.click(screen.getByRole("button", { name: "Send inquiry" }));

    await waitFor(() => expect(fetchMock).toHaveBeenCalledOnce());
    expect(await screen.findByText("Thanks — we'll be in touch.")).toBeInTheDocument();
  });

  it("provides a direct email fallback when delivery fails", async () => {
    vi.spyOn(globalThis, "fetch").mockRejectedValue(new Error("offline"));
    render(<ContactForm />);

    fireEvent.change(screen.getByLabelText("Your name"), { target: { value: "Jordan Davis" } });
    fireEvent.change(screen.getByLabelText("Work email"), { target: { value: "jordan@example.com" } });
    fireEvent.change(screen.getByLabelText("League or organization"), { target: { value: "Premier League" } });
    fireEvent.change(screen.getByLabelText("What would make League Hub valuable for you?"), {
      target: { value: "A single place for our league information." },
    });
    fireEvent.click(screen.getByRole("button", { name: "Send inquiry" }));

    expect(await screen.findByRole("alert")).toHaveTextContent("jonah@jdbuilds.ca");
  });
});
