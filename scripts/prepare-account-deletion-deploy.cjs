// Build a focused deployment artifact without requiring the not-yet-configured
// Apple/Razorpay server secrets. The authoritative source remains functions/.
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const target = path.join(root, '.firebase/account-deletion-deploy');
fs.mkdirSync(path.join(target, 'functions'), { recursive: true });
for (const name of ['index.js', 'account-deletion.js', 'account-deletion-core.js', 'account-lifecycle.js', 'package.json', 'package-lock.json']) {
  let source = fs.readFileSync(path.join(root, 'functions', name));
  if (name === 'index.js') {
    source = source.toString()
      .replace("Object.assign(exports, require('./apple-subscriptions'));", '')
      .replace("Object.assign(exports, require('./razorpay-subscriptions'));", '')
      .replace("Object.assign(exports, require('./case-payments'));", '');
  }
  fs.writeFileSync(path.join(target, 'functions', name), source);
}
let rules = fs.readFileSync(path.join(root, 'firestore.rules'), 'utf8');
const start = rules.indexOf('    match /subscriptions/{userId} {');
const end = rules.indexOf('    match /appleSubscriptions/', start);
if (start < 0 || end < 0) throw new Error('Subscription rule block not found');
// Preserve the installed app's direct Razorpay activation until the IAP/backend
// migration is configured and the replacement Android build is enforced.
rules = rules.slice(0, start) + `    match /subscriptions/{userId} {
      allow read: if signedIn() && request.auth.uid == userId;
      allow create, update: if signedIn()
        && request.auth.uid == userId
        && request.resource.data.userId == userId
        && request.resource.data.userType in ['lawyer', 'client']
        && request.resource.data.status == 'active'
        && request.resource.data.planId is number
        && request.resource.data.duration is string
        && request.resource.data.price is number
        && request.resource.data.price > 0
        && request.resource.data.features is list
        && request.resource.data.paymentId is string
        && request.resource.data.paymentId.size() > 0
        && request.resource.data.subscriptionDate is timestamp
        && request.resource.data.endDate is timestamp
        && request.resource.data.endDate > request.resource.data.subscriptionDate;
      allow delete: if false;
    }

` + rules.slice(end);
fs.writeFileSync(path.join(target, 'firestore.rules'), rules);
fs.copyFileSync(path.join(root, 'storage.rules'), path.join(target, 'storage.rules'));
// Optional live inventory from `firebase firestore:indexes --json` prevents
// removing indexes which were added outside this repository.
const indexes = JSON.parse(fs.readFileSync(path.join(root, 'firestore.indexes.json')));
if (process.argv[2]) {
  let live = JSON.parse(fs.readFileSync(process.argv[2]));
  live = live.result || live;
  if (typeof live === 'string') live = JSON.parse(live);
  for (const group of ['indexes', 'fieldOverrides']) {
    const key = value => group === 'indexes'
      ? `${value.collectionGroup}:${value.queryScope}:${JSON.stringify(value.fields)}`
      : `${value.collectionGroup}:${value.fieldPath}`;
    const combined = new Map((live[group] || []).map(v => [key(v), v]));
    for (const entry of indexes[group] || []) combined.set(key(entry), entry);
    indexes[group] = [...combined.values()];
  }
}
fs.writeFileSync(path.join(target, 'firestore.indexes.json'), JSON.stringify(indexes, null, 2) + '\n');
console.log('Prepared .firebase/account-deletion-deploy from current source.');
