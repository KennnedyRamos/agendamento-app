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

function buildFinancialBreakdowns(transactions = []) {
  const paidTransactions = transactions.filter((item) => item.status === 'paid');
  const daily = new Map();
  const services = new Map();

  for (const transaction of paidTransactions) {
    const dateKey = String(transaction.dateKey || '');
    if (/^\d{4}-\d{2}-\d{2}$/.test(dateKey)) {
      const currentDay = daily.get(dateKey) || {
        date: dateKey,
        day: Number(dateKey.slice(-2)),
        appointmentCount: 0,
        grossAmount: 0,
        netAmount: 0,
      };
      currentDay.appointmentCount += 1;
      currentDay.grossAmount = sumMoney([
        currentDay.grossAmount,
        transaction.amount,
      ]);
      currentDay.netAmount = sumMoney([
        currentDay.netAmount,
        transaction.netAmount,
      ]);
      daily.set(dateKey, currentDay);
    }

    const serviceName = String(transaction.serviceName || 'Servico').trim();
    const serviceKey = serviceName.toLocaleLowerCase('pt-BR');
    const currentService = services.get(serviceKey) || {
      serviceName: serviceName || 'Servico',
      appointmentCount: 0,
      grossAmount: 0,
      netAmount: 0,
    };
    currentService.appointmentCount += 1;
    currentService.grossAmount = sumMoney([
      currentService.grossAmount,
      transaction.amount,
    ]);
    currentService.netAmount = sumMoney([
      currentService.netAmount,
      transaction.netAmount,
    ]);
    services.set(serviceKey, currentService);
  }

  return {
    dailyRevenue: [...daily.values()].sort((first, second) =>
      first.date.localeCompare(second.date)
    ),
    serviceBreakdown: [...services.values()].sort(
      (first, second) =>
        second.appointmentCount - first.appointmentCount ||
        second.grossAmount - first.grossAmount
    ),
  };
}

module.exports = {
  buildFinancialBreakdowns,
  roundMoney,
  summarizeFinancialActivity,
};
