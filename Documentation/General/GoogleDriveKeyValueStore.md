# Google Drive key-value store

`GSGoogleDriveUbiquitousKeyValueStore` stores a dictionary as one XML
property-list file in the signed-in user's hidden Google Drive `appDataFolder`.
It uses the same Foundation value types as the AWS backend: strings, numbers,
dates, data, arrays and string-keyed dictionaries. The serialized file is
limited to 1 MiB; nesting is limited to 128 levels. It requires Base built
with GnuTLS and does not require a Google SDK.

The file is private to the OAuth application and the user. It is not displayed
among the user's normal Drive files, and cannot be shared with other users.
Devices using the same OAuth application, user account and store name can
find the same settings. Users can remove application data through their Google
account; the backend will report a disappeared store rather than silently
recreating a previously known file.

## Application setup

1. Enable the Google Drive API in a Google Cloud project and configure an
   OAuth consent screen and an OAuth client appropriate for the application.
2. Have the user authorize the `https://www.googleapis.com/auth/drive.appdata`
   scope. A Google/Gmail account alone is not authorization for the application.
3. Obtain an access token, or obtain a refresh token with offline access.
   The application owns the interactive authorization flow (including PKCE
   for a desktop app) and secure, persistent token storage. This Foundation
   backend does not open a browser or implement a sign-in UI.
4. Supply the credentials through `NSProcessInfo`'s environment and select the
   backend before the first call to `defaultStore`.

Access-token mode uses `GOOGLE_DRIVE_ACCESS_TOKEN`. When that token expires,
synchronization fails with HTTP 401 until the application supplies a new token.

For automatic refresh, supply:

- `GOOGLE_DRIVE_CLIENT_ID`
- `GOOGLE_DRIVE_REFRESH_TOKEN`
- `GOOGLE_DRIVE_CLIENT_SECRET` if required by the registered client

`GOOGLE_DRIVE_ACCESS_TOKEN` can also supply the initial token. Refreshed access
tokens are cached in memory until shortly before expiry. A 401 causes at most
one refresh and retry per request. The refresh request goes to
`https://oauth2.googleapis.com/token`. Tokens are never put in URL query
strings, user defaults or error messages. DPoP-bound credentials are not
supported. Revoked/expired refresh tokens require renewed user authorization.

An application can update credentials for the same account with
`-[NSProcessInfo setValue:inEnvironment:]`; a credential change invalidates the
cached access token. Do not switch users on an existing store: it retains
cached values and pending edits for its original account. This implementation
has no automatic account-switch detection; manage account-specific store
instances and finish or discard pending changes before switching accounts.

```objc
// The application has already obtained credentials through OAuth.
[[NSProcessInfo processInfo] setValue: accessToken
                       inEnvironment: @"GOOGLE_DRIVE_ACCESS_TOKEN"];

NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
[defaults setObject: @"GSGoogleDriveUbiquitousKeyValueStore"
            forKey: @"GSUbiquitousKeyValueStoreClass"];
[defaults setObject: @"org.example.MyApp.settings.plist"
            forKey: @"GSGoogleDriveKeyValueStoreName"];

NSUbiquitousKeyValueStore *store = [NSUbiquitousKeyValueStore defaultStore];
[store synchronize];
[store setString: @"dark" forKey: @"appearance"];
[store synchronize];
```

Choose a stable, application-specific name and use it on all devices. The
backend discovers matching files in `appDataFolder`, following pagination.
On the first write it creates a file with metadata and property-list content
in one multipart request. It pre-generates the file ID and retains it across
failed requests so retries can check whether creation already succeeded.

Drive permits duplicate names: simultaneous first writes on different devices
can create different files. The backend detects duplicate names during
subsequent discovery and fails instead of choosing one and losing changes.
Initialize the store on one device before using it on others. An application
can resolve duplicate data and configure `GSGoogleDriveKeyValueStoreFileID`
on all devices to select a specific existing app-data file. An explicit ID
takes precedence over the name, bypasses discovery, and must already exist
inside `appDataFolder`; ordinary Drive files are rejected. Duplicate files
are not automatically merged or deleted.

## Synchronization and failure behavior

Setters and getters operate on a local in-memory cache. `synchronize` blocks
and performs network requests; there is no automatic polling or persistent
offline cache. Each request has a 30-second deadline. Pending edits are lost
if the process exits before they are successfully uploaded.

The backend uses Drive API v2, which exposes an explicit file `etag`. It reads
metadata, downloads the content with `alt=media`, and checks the metadata
again before using the downloaded snapshot. It merges pending local values
and deletions, then sends a conditional media `PUT` with `If-Match` set to
that ETag. Changes detected during download or HTTP 412 conflicts trigger a
new read and merge, up to three attempts. Local edits win for the same key;
unrelated remote keys survive. A clean store only reads remote state.

Conditional-update behavior is covered by offline protocol tests. It has not
been verified against a live Google Drive account; the backend relies on
Drive honoring `If-Match` for its v2 content-update endpoint. It does not claim
a multi-file transaction or atomic uniqueness by filename.

Transport, authorization, quota, malformed-data and duplicate-file failures
raise exceptions without clearing pending local edits. Missing credentials or
configuration raise `NSInvalidArgumentException`; service failures normally
raise `NSGenericException`. No GnuTLS support raises
`NSInternalInconsistencyException`. Credentials, request bodies and server
error bodies are not included in these exception messages. TLS verification
is mandatory and redirects are rejected rather than forwarding tokens.

Successful synchronization that changes the cache posts
`NSUbiquitousKeyValueStoreDidChangeExternallyNotification` on the calling
thread. `NSUbiquitousKeyValueStoreChangeReasonKey` is 1 for an initial load,
0 for later server changes. Unchanged state and failed synchronizations do not
post a notification. Edits from run-loop callbacks during an upload remain
pending for the next sync; recursive calls to `synchronize` are ignored.

## References

- [Google Drive application data](https://developers.google.com/workspace/drive/api/guides/appdata)
- [Drive v2 file metadata, including ETags](https://developers.google.com/workspace/drive/api/reference/rest/v2/files)
- [Drive v2 content downloads](https://developers.google.com/workspace/drive/api/reference/rest/v2/files/get)
- [Drive v2 content updates](https://developers.google.com/workspace/drive/api/reference/rest/v2/files/update)
- [Pre-generated file IDs](https://developers.google.com/workspace/drive/api/reference/rest/v2/files/generateIds)
- [Google OAuth for desktop apps and token refresh](https://developers.google.com/identity/protocols/oauth2/native-app)
