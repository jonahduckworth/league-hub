# League Hub store release assets

`assets/brand/league-hub-master.png` is the approved source artwork. Run
`node store_assets/render-assets.js` after changing it to regenerate every
native icon, launch image, website icon, social image, and Google Play graphic.

`node store_assets/render-screenshots.js` turns the isolated reviewer fixture's
real 1320 × 2868 simulator captures into polished 1242 × 2688 listing images.
The final files in `screenshots/app-store-iphone-6.5/` satisfy both Apple and
Google Play phone screenshot requirements; raw captures and duplicate Play
exports stay local and are not committed.

This folder contains non-secret listing copy, compliance drafts, final icons, and approved screenshot exports. Reviewer passwords and Android signing credentials are stored in macOS Keychain and never committed.

Final screenshots are produced from the isolated production review organization on a 6.9-inch iPhone simulator. The app is intentionally iPhone-only for the first App Store release until a dedicated iPad experience is ready.
