# Setting up admin access

This turns your product catalog into a real database with login-protected
editing: you (and anyone you invite) can manage products through a new
`/admin.html` page, while regular site visitors can only view — never edit —
anything.

It uses **Supabase** (a free hosting service for a database + login system).
You'll need to do a few steps in their dashboard yourself — there's no way
around creating the account, since only you can do that — but everything
else (the database structure, the admin page, the security rules) is
already written for you.

Total time: about 15 minutes.

---

## 1. Create your Supabase project

1. Go to [supabase.com](https://supabase.com) and sign up (free tier is
   plenty for a small shop).
2. Click **New project**. Pick any name and a database password (save that
   password somewhere — you likely won't need it again, but keep it safe).
3. Wait about a minute for the project to finish setting up.

## 2. Run the database setup script

1. In your new project, open **SQL Editor** (left sidebar) → **New query**.
2. Open `schema.sql` (included alongside this file), copy the *entire*
   contents, and paste it into the query editor.
3. Near the very bottom of the file, find this line:
   ```sql
   values ('YOUR-EMAIL@example.com', true)
   ```
   Replace `YOUR-EMAIL@example.com` with the email you'll log into the admin
   panel with.
4. Click **Run**. This creates the products table (pre-filled with your
   current 13 products), the admin allowlist, and the security rules that
   keep editing locked down.

## 3. Create your login

1. In Supabase, go to **Authentication → Users → Add user → Create new
   user**.
2. Enter the *same email* you used in step 2, and set a password.
3. Leave "Auto Confirm User" checked (so you don't need to click an email
   confirmation link).

You're now both a registered user *and* on the admin allowlist — the two
things needed to get into `/admin.html`.

## 4. Connect index.html and admin.html to your project

1. In Supabase, go to **Project Settings → API**.
2. Copy the **Project URL** and the **anon public** key (not the
   `service_role` one — that one should never go in client-side code).
3. Open `index.html`, find this near the top of the first `<script>` block:
   ```js
   const SUPABASE_URL = 'YOUR_SUPABASE_PROJECT_URL';
   const SUPABASE_ANON_KEY = 'YOUR_SUPABASE_ANON_KEY';
   ```
   Paste your actual values in place of both placeholders.
4. Open `admin.html`, find the same two lines near the bottom (inside the
   `<script>` tag), and paste the same two values there too.

## 5. Deploy and test

1. Upload/deploy `index.html`, `admin.html`, and `ADMIN_SETUP.md` (this file
   is just documentation — safe to skip deploying it) as you normally would.
2. Visit `yoursite.com/admin.html`, sign in with the email/password from
   step 3, and you should see your 13 products listed, ready to edit.
3. Visit your normal homepage and confirm products still show up there too
   — they're now being pulled live from the database instead of being
   hardcoded.

---

## Giving someone else admin access

1. **Create their login**: Supabase → Authentication → Users → Add user,
   with their email and a temporary password (tell them to change it, or
   use "Send invite" if you'd rather Supabase email them a signup link —
   see Supabase's docs for exact wording, this changes occasionally).
2. **Add them to the allowlist**: sign into `/admin.html` yourself, go to
   the **Admin access** tab (only visible to you, the owner), and add their
   email there.

They can now sign in and edit products — but only you (the owner) can add
or remove other admins. Regular admins can manage products but can't grant
anyone else access.

## Removing someone's access

Go to `/admin.html` → **Admin access** tab → **Remove** next to their name.
This stops them from editing products immediately. If you also want to stop
them from being able to log in at all, delete their user in Supabase →
Authentication → Users.

## A note on security

The `anon` key you pasted into `index.html` and `admin.html` is *meant* to
be public — it's visible to anyone who views your page source, same as any
client-side API key. It only grants what `schema.sql` explicitly allows:
anyone can *read* products, but only emails in the `admins` table can
write. That check happens on Supabase's servers (via "Row Level Security"),
not in the browser, so it can't be bypassed by editing the page's code.

Never paste your `service_role` key anywhere in `index.html` or
`admin.html` — that key bypasses all these protections.
