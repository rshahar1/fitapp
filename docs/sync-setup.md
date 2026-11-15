# Cloud backup setup

Cloud backup is optional. Without the keys below the app works fully offline. These steps are for the owner
who runs the Supabase project.

## 1. Supabase project

1. Create a project at [supabase.com](https://supabase.com).
2. Copy the project URL and the anon (publishable) key from Settings > API into `env/dev.json`
   (git-ignored): `SUPABASE_URL` and `SUPABASE_ANON_KEY`. Never put the service-role key in the app or in git.
3. Install the [Supabase CLI](https://supabase.com/docs/guides/cli), then from the repo root:

```sh
supabase login
supabase link --project-ref <ref>
supabase db push                          # applies supabase/migrations
supabase functions deploy delete-account
```

## 2. Google Cloud

1. In Google Cloud Console > APIs & Services, configure the OAuth consent screen.
2. Create an OAuth client of type **Web application**. Its client ID is `GOOGLE_WEB_CLIENT_ID` (in
   `env/dev.json`) and also the Supabase Google provider client ID. Its secret goes only into the Supabase
   dashboard.
3. Create **Android** OAuth clients for package `com.fitapp.app`, one per signing key:
   - Debug SHA-1: `keytool -list -v -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android`
   - Release SHA-1: from your release keystore (`keytool -list -v -keystore <path> -alias <alias>`).

## 3. Supabase dashboard: Google provider

Auth > Providers > Google:

- Enable the provider.
- Client ID: the web client ID; under authorized client IDs add the Android client IDs too (comma-separated).
- Client secret: the web client secret.
- If Android sign-in fails with a nonce error, enable **Skip nonce check**.

## 4. Run the app

```sh
flutter run --dart-define-from-file=env/dev.json
```

`GOOGLE_WEB_CLIENT_ID`, `SUPABASE_URL` and `SUPABASE_ANON_KEY` must all be set, otherwise backup stays disabled.

## 5. Backend tests

```sh
npm ci && node tool/db_test.mjs
```
