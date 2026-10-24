// Pure policy shared by purchase verification, notifications, and tests.
function entitlementFor(transaction, renewal, status, now = Date.now()) {
  if (transaction.type !== 'Auto-Renewable Subscription' ||
      transaction.inAppOwnershipType !== 'PURCHASED' ||
      transaction.revocationDate || transaction.isUpgraded) {
    return { active: false, endMillis: 0 };
  }
  const endMillis = status === 4
    ? Number(renewal?.gracePeriodExpiresDate || 0)
    : Number(transaction.expiresDate || 0);
  return {
    active: [1, 4].includes(status) && endMillis > now,
    endMillis: Number.isFinite(endMillis) ? endMillis : 0,
  };
}

function summarize(chains, now = Date.now()) {
  const active = Object.values(chains).filter((chain) =>
    chain.active && chain.endMillis > now);
  active.sort((a, b) => b.endMillis - a.endMillis);
  return active[0] || null;
}

module.exports = { entitlementFor, summarize };
