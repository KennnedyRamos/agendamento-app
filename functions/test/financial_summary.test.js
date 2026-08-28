const test = require('node:test');
const assert = require('node:assert/strict');

const { summarizeFinancialActivity } = require('../financial_summary');

test('resume pagamentos online e dinheiro sem misturar valores pendentes', () => {
  const summary = summarizeFinancialActivity({
    onlineTransactions: [
      {
        status: 'paid',
        amount: 50,
        marketplaceFee: 1.5,
        mercadoPagoFee: 0.5,
        netAmount: 48,
      },
      { status: 'pending', amount: 80 },
      { status: 'failed', amount: 100 },
    ],
    completedCashAmounts: [40],
    scheduledCashAmounts: [30, 35],
  });

  assert.deepEqual(summary, {
    grossRevenue: 90,
    netRevenue: 88,
    onlineGross: 50,
    onlineNet: 48,
    marketplaceFees: 1.5,
    mercadoPagoFees: 0.5,
    cashReceived: 40,
    cashScheduled: 65,
    pendingOnline: 80,
    paidOnlineCount: 1,
    pendingOnlineCount: 1,
    completedCashCount: 1,
    scheduledCashCount: 2,
    hasEstimatedOnlineValues: false,
  });
});

test('informa quando o liquido online ainda e estimado', () => {
  const summary = summarizeFinancialActivity({
    onlineTransactions: [
      {
        status: 'paid',
        amount: 50,
        marketplaceFee: 0,
        mercadoPagoFee: 0,
        netAmount: 50,
        isNetEstimated: true,
      },
    ],
  });

  assert.equal(summary.hasEstimatedOnlineValues, true);
});
