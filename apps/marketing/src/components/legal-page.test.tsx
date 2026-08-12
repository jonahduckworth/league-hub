import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { LegalPage } from "./legal-page";

describe("LegalPage", () => {
  it("renders the branded legal header and navigation", () => {
    const { container } = render(
      <LegalPage
        eyebrow="Privacy"
        title="Privacy matters"
        intro="A clear explanation."
        updated="August 11, 2026"
      >
        <section><h2>Details</h2></section>
      </LegalPage>,
    );

    expect(container.querySelector("header.legal-header")).toBeTruthy();
    expect(screen.getByRole("link", { name: "League Hub home" })).toHaveAttribute(
      "href",
      "/",
    );
    expect(screen.getByRole("link", { name: /back to league hub/i })).toHaveAttribute(
      "href",
      "/",
    );
  });
});
