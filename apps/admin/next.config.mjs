/** @type {import('next').NextConfig} */
const nextConfig = {
  allowedDevOrigins: ["127.0.0.1"],
  output: "export",
  trailingSlash: true,
  images: {
    unoptimized: true
  },
  typescript: {
    tsconfigPath: "./tsconfig.json"
  }
};

export default nextConfig;
