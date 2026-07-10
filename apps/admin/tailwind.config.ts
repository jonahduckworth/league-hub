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
        ink: "#101828",
        muted: "#667085",
        shell: "#F3F6FA",
        panel: "#FFFFFF",
        line: "#D8E0EA",
        teal: "#0F766E",
        mint: "#15803D",
        amber: "#A16207",
        coral: "#C2413A",
        grape: "#6941C6",
        navy: "#0B1220",
        "navy-soft": "#172033",
        sky: "#2563EB"
      },
      boxShadow: {
        soft: "0 18px 48px -28px rgba(16, 24, 40, 0.32)",
        card: "0 1px 2px rgba(16, 24, 40, 0.04), 0 12px 32px -20px rgba(16, 24, 40, 0.24)",
        lift: "0 24px 64px -28px rgba(11, 18, 32, 0.38)"
      },
      backgroundImage: {
        "hero-glow": "radial-gradient(circle at top right, rgba(45, 212, 191, 0.2), transparent 38%), linear-gradient(135deg, #0B1220 0%, #172033 72%, #123B3A 100%)"
      }
    }
  },
  plugins: []
};

export default config;
