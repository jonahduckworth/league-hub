# League Hub Admin

Next.js admin dashboard for active `platformOwner` and `superAdmin` users.

## Commands

```bash
npm install
npm run dev
npm run verify
```

## Firebase

The app is a static Next.js export served by Firebase Hosting:

```bash
npm run build
firebase deploy --only hosting:admin
```

The `admin` hosting target is mapped to the existing `jdb-league-hub` Hosting site.
The Firebase web app is `League Hub Admin` with app id `1:757767295888:web:c9cc6d379088109b101915`.

Use `NEXT_PUBLIC_ADMIN_DEMO_MODE=true` only for local UI QA.
