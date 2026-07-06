import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./src/app/**/*.{ts,tsx}",
    "./src/components/**/*.{ts,tsx}",
    "./src/lib/**/*.{ts,tsx}"
  ],
  theme: {
    extend: {
      colors: {
        ink: "#17202A",
        muted: "#657082",
        shell: "#F6F7F4",
        panel: "#FFFFFF",
        line: "#DDE3DD",
        teal: "#087E8B",
        mint: "#35A67B",
        amber: "#C58220",
        coral: "#D75A4A",
        grape: "#6E5BA8"
      },
      boxShadow: {
        soft: "0 10px 30px rgba(23, 32, 42, 0.08)"
      }
    }
  },
  plugins: []
};

export default config;
