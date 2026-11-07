# Account deletion implementation and rollout

## Current status

Implemented locally. The iOS simulator build succeeded. The existing Flutter
suite (17 tests) and backend suite (30 tests) passed. Proposed Firestore and
Storage rules passed Firebase's compilation API without issues.

**Not deployed:** automatic approval review rejected the production rules release
because live access is materially broader than the checked-in rules. Explicit
approval of that production impact is required before deploying rules/functions.
Do not publish the new app before the deletion functions and rules are deployed.

The live rules currently permit public reads and broadly authenticated writes to
Firestore, and public Storage access. These permissions cannot protect a deletion
job from being forged or rewritten by another client. The proposed release uses
the repository's authenticated/owner rules plus deletion barriers, rather than
leaving those job records writable. This changes access for websites or older
clients that depend on public reads or broad writes; review those clients first.

## In-app flow

Both client and advocate accounts have **Delete account** in the navigation drawer
and on **My profile**. The deletion screen:

1. Explains permanent removal, affected data, other clients' preserved cases, and
   the difference between account deletion and Apple subscription cancellation.
2. Requires the current password for this app's email/password accounts and a
   typed `DELETE` confirmation. Firebase reauthentication refreshes `auth_time`.
3. Calls `requestAccountDeletion` in `asia-south1`; UID always comes from Firebase
   Authentication, never from a client-supplied account identifier.
4. Watches an owner-only server job and distinguishes queued/processing/retrying
   from completed. Closing the app does not cancel processing.
5. Shows completion only after server cleanup, including Firebase Auth deletion.
   Clears the local session, saved role, image cache and notifications. Firestore
   persistence is purged before first use at the next app launch.

If progress is unavailable, the app does not claim deletion completed. A persisted
accepted request resumes on launch, or the user can sign out while cleanup runs.
Files exported/shared outside this app and payment-provider records remain outside
this deletion operation. This app does not currently use Sign in with Apple.

## Server behavior

- `requestAccountDeletion`: authenticated callable, explicit confirmation, recent
  sign-in (five minutes), one durable job per UID, duplicate requests are safe.
- `processAccountDeletion`: Firestore create trigger with retries and a ten-minute
  lease longer than its nine-minute execution timeout. Disables/revokes the account
  first, cleans data in pages, and removes Firebase Auth last.
- `cleanupDeletedAuthAccount`: single-account Firebase Auth deletions made through
  Admin SDK/console also enqueue cleanup. Existing completed jobs are not recreated.
  Firebase bulk `deleteUsers` does not emit individual Auth deletion events: admin
  bulk workflows must enqueue a job per UID explicitly.

The job erases known account-owned data in users/lawyers, cases, consultation
requests, nested case chats, documents/files, timelines, reviews, notifications,
saved advocates, support tickets/replies/files, bug reports, feedback, feature
requests/votes, subscription/payment records and Apple account mappings. Reviews
also update the affected remaining advocate's aggregate rating transactionally.

Other clients keep their case/documents and unrelated activity; consultations/chats
with the departing account and generated history naming that advocate are removed.
RTDB currently stores only shared court/master data, so these shared records are
not erased. Storage deletion uses known exact paths and slash-terminated prefixes,
not arbitrary URLs supplied by the user.

The minimal job record contains status, timestamps, a UID as its document key,
phase, attempts and an error code. Completion sets `expiresAt` for 30 days; the
provided Firestore TTL field override removes completed job records afterwards.
Failed jobs retain their status for retries and operational recovery. Monitor
retrying jobs: Firebase event retries have a finite retention window.

Rules prevent deleting accounts from continuing normal writes, block new
consultations/reviews/saves targeting a deleting advocate, and make job writes
server-only. Notification handlers and future payment verification transactions
check the same barrier so delayed events cannot recreate erased account data.

## Focused deployment

Apple payment credentials are not configured yet, so the normal Functions entry
point cannot be deployed wholesale. A reproducible artifact excludes payment
exports while retaining deletion and notification source:

```sh
node scripts/prepare-account-deletion-deploy.cjs
npm ci --prefix .firebase/account-deletion-deploy/functions
```

To preserve production indexes added outside this repository, first save
`firebase firestore:indexes --project lawyer-417809 --json` to a local file and
pass its path as the script's argument. The script merges the live inventory.

The isolated config is `firebase.account-deletion.json`. Its generated rules
preserve the installed Android app's legacy Razorpay subscription activation
writes. The canonical `firestore.rules` remains the stricter future IAP version;
**do not deploy the canonical rules alone before the payment migration**.

After explicit production approval, deploy rules/indexes before enabling the
worker so clients can never forge deletion jobs:

```sh
firebase deploy --project lawyer-417809 --config firebase.account-deletion.json --only firestore:rules,firestore:indexes,storage --non-interactive
firebase deploy --project lawyer-417809 --config firebase.account-deletion.json --only functions:requestAccountDeletion,functions:processAccountDeletion,functions:cleanupDeletedAuthAccount,functions:sendCaseNotification,functions:notifyOnChatMessage,functions:notifyLawyersOnCasePayment,functions:updateLawyerRating,functions:notifyOnSupportReply,functions:notifyOnTicketStatusChange --non-interactive
```

This deployment excludes the unconfigured payment functions and does not change
the existing announcement handler. Verify the collection-group lookup index on
`lawyers.lawyerId` is ready. Grant the default function service accounts the
necessary Firebase Auth, Firestore, Storage and Messaging access if deployment or
synthetic-account testing reports an IAM failure. Storage's Firestore-backed rules
also require the standard cross-service rule evaluation permission.

## Required live checks after deployment

Use dedicated synthetic accounts and their own fixtures, never real customer data:

- Delete a client with an owned case, file, support ticket and Apple-mapping fixture;
  verify Firebase Auth, Firestore and Storage removal, job completion and retries.
- Delete an advocate linked to a synthetic other client's case; verify that other
  client's case/documents remain and consultation/chat/personal references disappear.
- Repeat the same request; try wrong/stale credentials and a different UID; verify
  no extra cleanup or cross-account access occurs.
- Deny client writes to job records and unrelated personal data. Confirm ordinary
  app login, profile edits, uploads, support, case booking, chat and Razorpay still
  work with the production rules.
- Close/reopen during deletion; verify queued status resumes and no false completion
  is shown. Test offline/retry behavior and automatic Auth-console cleanup.

Tests use mocked Firebase I/O and are not a substitute for a deployed end-to-end
check. Record the complete flow on a **physical device** for App Review as requested
in the rejection: sign in, open Delete account, confirm, and show completion.

References:
- https://developer.apple.com/support/offering-account-deletion-in-your-app/
- https://firebase.google.com/docs/auth/admin/manage-users
- https://firebase.google.com/docs/firestore/manage-data/delete-data
