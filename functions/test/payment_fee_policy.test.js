const test = require('node:test');
const assert = require('node:assert/strict');

const {
  DEFAULT_MARKETPLACE_FEE_PERCENT,
  resolvePaymentFeePolicy,
} = require('../payment_fee_policy');

const DAY = 24 * 60 * 60 * 1000;
const TRIAL_START = Date.UTC(2026, 0, 1);

test('aplica 0% durante os primeiros 30 dias', () => {
  const policy = resolvePaymentFeePolicy({
    accountData: { feeTrialStartedAt: TRIAL_START },
    nowMillis: TRIAL_START + 29 * DAY,
  });

  assert.equal(policy.appliedPercent, 0);
  assert.equal(policy.isTrialActive, true);
});

test('aplica 3% a partir do fim do periodo promocional', () => {
  const policy = resolvePaymentFeePolicy({
    accountData: { feeTrialStartedAt: TRIAL_START },
    nowMillis: TRIAL_START + 30 * DAY,
  });

  assert.equal(policy.appliedPercent, DEFAULT_MARKETPLACE_FEE_PERCENT);
  assert.equal(policy.isTrialActive, false);
});

test('preserva compatibilidade com contas que possuem apenas connectedAt', () => {
  const policy = resolvePaymentFeePolicy({
    accountData: { connectedAt: new Date(TRIAL_START) },
    configuredPercent: 4,
    nowMillis: TRIAL_START + 31 * DAY,
  });

  assert.equal(policy.appliedPercent, 4);
  assert.equal(policy.trialStartedAtMillis, TRIAL_START);
});

test('nao concede periodo gratuito sem uma data de inicio registrada', () => {
  const policy = resolvePaymentFeePolicy({ accountData: {} });

  assert.equal(policy.appliedPercent, DEFAULT_MARKETPLACE_FEE_PERCENT);
  assert.equal(policy.isTrialActive, false);
});

test('rejeita percentual de comissao invalido', () => {
  assert.throws(
    () => resolvePaymentFeePolicy({ configuredPercent: 101 }),
    RangeError
  );
});
