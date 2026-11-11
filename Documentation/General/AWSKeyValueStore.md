# AWS S3 and Cloudflare R2 key-value store

GNUstep Base's `GSAWSUbiquitousKeyValueStore` backend stores a property-list
dictionary in one object in an existing S3 general-purpose bucket. It requires
Base built with GnuTLS. It does not use iCloud or require an AWS SDK.

Configure these user defaults before the first call to
`[NSUbiquitousKeyValueStore defaultStore]`:

```objc
NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
[defaults setObject: @"GSAWSUbiquitousKeyValueStore"
            forKey: @"GSUbiquitousKeyValueStoreClass"];
[defaults setObject: @"my-settings-bucket"
            forKey: @"GSAWSKeyValueStoreBucket"];
[defaults setObject: @"us-east-1" forKey: @"GSAWSKeyValueStoreRegion"];
[defaults setObject: @"users/user-id/application.plist"
            forKey: @"GSAWSKeyValueStoreKey"];

NSUbiquitousKeyValueStore *store = [NSUbiquitousKeyValueStore defaultStore];
[store synchronize];  // Fetch existing settings before reading them.
[store setString: @"dark" forKey: @"appearance"];
[store synchronize];  // Merge and upload local changes.
```

Supply `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` in the process
environment. For temporary credentials also supply `AWS_SESSION_TOKEN`.
Credentials are read from `NSProcessInfo` for each request, never from user
defaults. An application refreshing credentials can update them with
`-[NSProcessInfo setValue:inEnvironment:]` between synchronizations. There is
no automatic credential discovery or renewal through profiles, IAM roles,
container metadata, or instance metadata.

The credentials need `s3:GetObject` and `s3:PutObject` permissions for the
configured object. S3 may require `s3:ListBucket` permission to return 404 for
an object that does not yet exist; without it S3 can return 403, which this
backend treats as a failure. Bucket creation, IAM policy management, and user
identity mapping belong to the application/deployment. Choose an object key
and IAM permissions that isolate each user's data as appropriate.

Bucket names must use lowercase ASCII letters, digits, and hyphens, be
3–63 characters long, and not begin or end with a hyphen. Dotted bucket names
are unsupported because the backend uses virtual-hosted HTTPS endpoints.
Set the actual bucket region; redirects are rejected. Commercial, GovCloud,
and China regional endpoint suffixes are supported; directory buckets,
and access points are not supported. An optional HTTPS endpoint enables
path-style access to Cloudflare R2 and compatible services (see below). Object keys are UTF-8 percent-encoded, retaining slashes.
Requests use AWS Signature Version 4, including session tokens when present,
and require certificate and hostname verification.

## Synchronization and failures

Reads and writes operate on an in-memory cache. There is no automatic polling,
background upload, or persistent offline cache. Call `synchronize` explicitly;
it blocks the calling thread, with a 30-second deadline per request. Network
failures and invalid remote data raise `NSGenericException`. Invalid
configuration or local values raise `NSInvalidArgumentException`. Selecting
the backend without GnuTLS raises `NSInternalInconsistencyException`.
The GNUstep API declares `synchronize` as returning `void`.

Each synchronization downloads the current dictionary, merges pending local
changes and deletions, and uploads only if there are pending changes. Writes
use `If-Match` with the downloaded ETag, or `If-None-Match: *` for a missing
object. HTTP 409/412 conflicts cause a fresh download and merge, up to three
attempts. Local edits win for the same key; unrelated remote changes survive.
Other failures retain local edits for a later retry. Edits made by run-loop
callbacks during a transfer remain pending; recursive synchronization is
ignored. Pending edits are lost if the process exits before a successful sync.

Values must be property-list strings, data, numbers, dates, arrays, or
string-keyed dictionaries. Values are copied when set. Nesting is limited to
128 levels and the serialized store to 1 MiB. Removing a key updates the
stored dictionary rather than deleting the S3 object.

A successful synchronization that changes the local cache posts
`NSUbiquitousKeyValueStoreDidChangeExternallyNotification` on the calling
thread, after releasing the store lock. Its user info contains
`NSUbiquitousKeyValueStoreChangeReasonKey`: 1 for the first successful sync,
0 for later server changes. No notification is posted for a failed sync or
an upload that leaves the local cache unchanged.

Protocol references:
[AWS Signature Version 4](https://docs.aws.amazon.com/AmazonS3/latest/API/sig-v4-header-based-auth.html)
and [S3 PutObject](https://docs.aws.amazon.com/AmazonS3/latest/API/API_PutObject.html).

## Cloudflare R2

Use the same `GSAWSUbiquitousKeyValueStore` backend and bucket/key defaults.
Set the signing region to `auto` and supply the S3 API endpoint for your R2
account:

```objc
[defaults setObject: @"auto" forKey: @"GSAWSKeyValueStoreRegion"];
[defaults setObject: @"https://YOUR_ACCOUNT_ID.r2.cloudflarestorage.com"
            forKey: @"GSAWSKeyValueStoreEndpoint"];
[defaults setObject: @"my-settings-bucket"
            forKey: @"GSAWSKeyValueStoreBucket"];
```

Set `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` to the **R2 S3 access key
ID and secret access key**, not a Cloudflare management API token or AWS keys.
Clear `AWS_SESSION_TOKEN` unless using temporary S3 credentials that require
one. Create the bucket and an R2 token authorized to read and write its objects
before use. Use the account's actual S3 endpoint, including any jurisdiction
suffix supplied by Cloudflare.

`GSAWSKeyValueStoreEndpoint` must be an HTTPS origin with no credentials, port,
query, fragment, or path other than an optional trailing slash. Setting it
switches to path-style addressing (`https://host/bucket/object-key`). Omitting
it retains AWS's regional virtual-hosted addressing. The endpoint is fixed
when the store is initialized. TLS verification and redirect rejection remain
enabled. R2 uses the same conditional writes, property-list format, limits,
and explicit synchronization as AWS.

Other S3-compatible endpoints can be configured, but must support Signature
Version 4, GET/PUT, ETags and atomic `If-Match`/`If-None-Match` writes. Only the
AWS and R2 request formats currently have dedicated offline tests; connecting
to an arbitrary S3-compatible service is not a compatibility guarantee.

References: [R2 S3 API](https://developers.cloudflare.com/r2/api/s3/api/)
and [conditional operations](https://developers.cloudflare.com/r2/api/s3/conditional-operations/).
