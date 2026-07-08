/** @type {import('next').NextConfig} */
const nextConfig = {
  output: "export",
  trailingSlash: true,
  typescript: {
    tsconfigPath: "./tsconfig.json"
  }
};

export default nextConfig;
