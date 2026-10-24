# Apple subscriptions: setup and release

Implementation targets the existing Flutter app `com.aapkelawyer.app` and Firebase
project `lawyer-417809`, with Functions in `asia-south1`.
Firebase Core 4.12.1 and Cloud Functions 6.3.5 are pinned together to avoid a
Swift conformance conflict with the existing Storage/App Check plugins. Apple products and API
credentials have not been created yet. No production deployment has been made.

## 1. Complete the account setup

- Resolve Apple's organization-account requirement with Apple Developer Support.
- In App Store Connect > Business, accept the Paid Apps Agreement and complete
  banking and tax setup. Confirm the agreement is active.
- In the existing app, copy its numeric Apple ID from App Information. This is
  different from the bundle ID and Firebase App ID.
- Confirm Firebase is on Blaze and the deploying account can deploy Functions,
  access Secret Manager, and update Firestore rules.

## 2. Create auto-renewable subscriptions

In App Store Connect, open this app > Monetization > Subscriptions.

Create one subscription group for mutually exclusive NyaySaarthi access plans.
Create products matching the plans you actually sell. Example identifiers only:

| Example product ID | Billing period |
| --- | --- |
| `com.aapkelawyer.app.nyaysaarthi.monthly` | 1 month |
| `com.aapkelawyer.app.nyaysaarthi.quarterly` | 3 months |
| `com.aapkelawyer.app.nyaysaarthi.yearly` | 1 year |

Use only the products that match your actual plans. Configure pricing, storefront
availability, subscription name, localization, description, review screenshot, and
review notes. Keep Family Sharing disabled: this implementation binds a purchase
to one Aapke Lawyer account. Start without introductory offers; the existing app
trial is separate from an Apple introductory offer.

For each matching Firestore `plans/{documentId}`, add an `appleProductId` string
with the exact product ID. Retain existing fields (`duration`, `months`, `price`,
`features`, `active`, etc.) for Android. Match the advertised benefits to the Apple
product. iOS shows Apple's localized price and billing period, never the Razorpay
price or discount. Missing/unavailable Apple products cannot be purchased on iOS.
Keep old product mappings even after making a plan inactive, so existing Apple
subscribers can continue to be verified.

Apple billing starts at purchase confirmation; it does not wait until the end of
an app-granted trial or append months to an existing Razorpay subscription. The
iOS purchase path blocks a second purchase while existing paid access is active.
Existing Razorpay access remains valid until its recorded expiry. Existing Apple
subscribers use Manage Subscription for changes within the Apple group.

## 3. Create the server API credentials

In App Store Connect > Users and Access > Integrations > In-App Purchase, generate
an In-App Purchase API key. Download the `.p8` file securely and record its Key ID
and Issuer ID. The private key must never be included in Flutter, Firestore, source
control, or chat.

Copy `functions/.env.example` to `functions/.env.lawyer-417809` and replace all
three identifier placeholders. Store the private key with:

```sh
firebase functions:secrets:set APPLE_IAP_PRIVATE_KEY --data-file /secure/path/AuthKey_KEYID.p8 --project lawyer-417809
```

Android subscription activation now verifies captured payments on the backend.
Set `RAZORPAY_KEY_ID` and `RAZORPAY_KEY_SECRET` using interactive Secret Manager
commands (do not put secret values on the command line):

```sh
firebase functions:secrets:set RAZORPAY_KEY_ID --project lawyer-417809
firebase functions:secrets:set RAZORPAY_KEY_SECRET --project lawyer-417809
```

The Key ID must match the account used by the existing `usefulkey` checkout
configuration. Razorpay auto-capture must be enabled; authorized but uncaptured
payments do not activate subscriptions.

## 4. Verify locally and deploy in stages

```sh
flutter pub get
flutter analyze
flutter test
cd functions
npm ci
npm test
cd ..
flutter build ios --simulator --debug
```

Deploy only the new functions first, leaving existing functions intact:

```sh
firebase deploy --project lawyer-417809 --only functions:prepareApplePurchase,functions:verifyApplePurchase,functions:refreshAppleSubscription,functions:appleSubscriptionNotifications,functions:verifyRazorpaySubscription
```

Use the deployed `appleSubscriptionNotifications` HTTPS URL for BOTH Production
and Sandbox App Store Server Notifications URLs in App Store Connect. Select
Version 2. Request an Apple test notification and confirm a successful response.
The endpoint is public for Apple to reach, but accepts only Apple-signed payloads.

Before releasing the new app, deploy a staging rules revision that adds the new
owner-only `appleSubscriptions` read permission and denies client access to the
three new server-only collections, while retaining the old `subscriptions`
write permissions temporarily. This permits sandbox testing and the Android
update rollout without breaking installed clients. Do not publish the new app
before those Apple read permissions exist: its access check reads that document.

After testing and coordinating a mandatory-update policy for older Android
clients, deploy the final checked-in rules, which remove all client subscription
writes:

```sh
firebase deploy --project lawyer-417809 --only firestore:rules
```

**Compatibility:** old app versions activate Razorpay plans by writing Firestore
directly. The new rules intentionally reject those writes. Deploying these rules
while old clients can still buy subscriptions would cause their activation to
fail after payment. The new Android version must be rolled out/enforced first,
or a separately designed migration/reconciliation flow must be provided. Existing
subscription documents remain readable and are not deleted or changed by setup.

Do not deploy the rules alone before the new backend functions are available.
No API credentials or product mappings means a deployment is not launch-ready.

## 5. Sandbox and TestFlight acceptance checks

Use a Sandbox Apple Account on a physical device with a development-signed build,
or TestFlight's sandbox environment. No real charges are made in sandbox. Xcode's
local StoreKit simulator transactions are not accepted by the live verification
backend: use real Apple sandbox products for the end-to-end test.

Check all of these before release:

- Correct localized price, billing period, benefits, renewal disclosure, terms,
  and privacy policy appear before purchase.
- Purchase activates access only after Firebase verifies the transaction.
- Canceling checkout does not grant access; pending approval does not grant access.
- Relaunch/sign-in recovers unfinished purchases; Restore Purchases works after a
  reinstall and on a second device signed into the same app account.
- A purchase bound to another app account cannot be claimed by the current account.
- Renewal updates the exact Apple expiry without appending extra months.
- Canceling auto-renew preserves access through the paid period; expiry locks
  access; refunds/revocations remove access. Billing grace is honored only when
  Apple returns a valid grace-period expiry.
- Replaying a transaction or duplicate/out-of-order notification never extends
  access or undoes a newer revocation.
- An existing Razorpay subscriber sees existing access and cannot accidentally
  buy an Apple subscription while that access is active.
- Android verifies a captured Razorpay payment, binds it to the buyer and plan,
  and rejects reuse of a payment ID. Existing trial stacking remains on Android.

Backend tests mock external Apple/Firestore I/O and also use Apple's real verifier
to reject unsigned payloads. They do not replace testing with a real Apple sandbox
purchase, deployed Functions, and deployed Firestore rules.

## 6. App Review submission

Submit the first subscriptions with the new app version. Include demo credentials,
purchase/restore navigation steps, and explain that iOS digital subscriptions now
use Apple IAP. Add public privacy-policy and terms URLs to App Store metadata. If
using Apple's standard EULA, include its link in the app description:
https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

The screenshot, account deletion, and organization-account issues from the prior
rejection still need resolution separately. This payment change does not resolve
them automatically.

## Backend data and behavior

- `applePurchaseAccounts/{uid}` and `applePurchaseTokens/{uuid}`: server-only mapping
  between Firebase identity and Apple's appAccountToken.
- `appleSubscriptions/{uid}`: server-only writes, owner-only reads; stores each
  subscription chain, verified status, renewal flag, environment, and expiry.
- `subscriptions/{uid}`: legacy/Razorpay access; writes now come only from the
  verified callable. Existing records continue to grant access until expiry.
- `verifiedSubscriptionPayments/{paymentId}`: server-only Razorpay replay guard.

Purchase verification calls Apple's transaction and subscription-status APIs,
checks signed data against Apple's bundled G3 root certificate, verifies app
identity and appAccountToken, and restricts products to server-configured plans.
Production is tried first; only transaction-not-found permits sandbox fallback.
Notifications fetch current status rather than trusting event delivery order.
The client refreshes status on sign-in/resume and explicit restoration; the gate
listens for verified Apple entitlement changes and schedules expiry checks.

Reference documentation:
- https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/overview-for-configuring-in-app-purchases/
- https://developer.apple.com/help/app-store-connect/manage-subscriptions/offer-auto-renewable-subscriptions/
- https://github.com/apple/app-store-server-library-node
- https://pub.dev/packages/in_app_purchase
