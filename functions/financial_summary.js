function roundMoney(value) {
  const number = Number(value);
  if (!Number.isFinite(number)) return 0;
  return Math.round((number + Number.EPSILON) * 100) / 100;
}

function sumMoney(values) {
  return roundMoney(values.reduce((total, value) => total + Number(value || 0), 0));
}

function summarizeFinancialActivity({
  onlineTransactions = [],
  completedCashAmounts = [],
  scheduledCashAmounts = [],
} = {}) {
  const paidOnline = onlineTransactions.filter((item) => item.status === 'paid');
  const pendingOnline = onlineTransactions.filter((item) => item.status === 'pending');
  const onlineGross = sumMoney(paidOnline.map((item) => item.amount));
  const marketplaceFees = sumMoney(paidOnline.map((item) => item.marketplaceFee));
  const mercadoPagoFees = sumMoney(paidOnline.map((item) => item.mercadoPagoFee));
  const onlineNet = sumMoney(paidOnline.map((item) => item.netAmount));
  const cashReceived = sumMoney(completedCashAmounts);
  const cashScheduled = sumMoney(scheduledCashAmounts);

  return {
    grossRevenue: sumMoney([onlineGross, cashReceived]),
    netRevenue: sumMoney([onlineNet, cashReceived]),
    onlineGross,
    onlineNet,
    marketplaceFees,
    mercadoPagoFees,
    cashReceived,
    cashScheduled,
    pendingOnline: sumMoney(pendingOnline.map((item) => item.amount)),
    paidOnlineCount: paidOnline.length,
    pendingOnlineCount: pendingOnline.length,
    completedCashCount: completedCashAmounts.length,
    scheduledCashCount: scheduledCashAmounts.length,
    hasEstimatedOnlineValues: paidOnline.some((item) => item.isNetEstimated === true),
  };
}

module.exports = { roundMoney, summarizeFinancialActivity };
