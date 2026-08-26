const DEFAULT_MARKETPLACE_FEE_PERCENT = 3;
const DEFAULT_FEE_TRIAL_DAYS = 30;
const DAY_IN_MILLISECONDS = 24 * 60 * 60 * 1000;

function timestampToMillis(value) {
  if (value && typeof value.toMillis === 'function') return value.toMillis();
  if (value instanceof Date) return value.getTime();
  if (Number.isFinite(value)) return Number(value);
  return null;
}

function resolvePaymentFeePolicy({
  accountData = {},
  configuredPercent = DEFAULT_MARKETPLACE_FEE_PERCENT,
  trialDays = DEFAULT_FEE_TRIAL_DAYS,
  nowMillis = Date.now(),
} = {}) {
  const parsedPercent = Number(configuredPercent);
  if (!Number.isFinite(parsedPercent) || parsedPercent < 0 || parsedPercent > 100) {
    throw new RangeError('A comissao do marketplace deve estar entre 0 e 100.');
  }
  if (!Number.isInteger(trialDays) || trialDays < 0) {
    throw new RangeError('O periodo promocional deve ser um numero inteiro de dias.');
  }

  const trialStartedAtMillis = timestampToMillis(
    accountData.feeTrialStartedAt || accountData.connectedAt
  );
  const trialEndsAtMillis =
    trialStartedAtMillis === null
      ? null
      : trialStartedAtMillis + trialDays * DAY_IN_MILLISECONDS;
  const isTrialActive =
    trialEndsAtMillis !== null && nowMillis < trialEndsAtMillis;

  return {
    configuredPercent: parsedPercent,
    appliedPercent: isTrialActive ? 0 : parsedPercent,
    isTrialActive,
    trialStartedAtMillis,
    trialEndsAtMillis,
  };
}

module.exports = {
  DEFAULT_MARKETPLACE_FEE_PERCENT,
  DEFAULT_FEE_TRIAL_DAYS,
  resolvePaymentFeePolicy,
};
