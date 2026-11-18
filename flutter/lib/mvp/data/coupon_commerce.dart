// A escala é idêntica para reais e percentuais (centavos ou pontos-base).
int? couponHundredths(String input) {
  final value = input.trim();
  if (!RegExp(r'^\d{1,8}([,.]\d{1,2})?$').hasMatch(value)) return null;
  final parts = value.replaceAll(',', '.').split('.');
  return int.parse(parts[0]) * 100 +
      (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0')));
}

const couponStates = {
  'issued': 'Emitido',
  'payment_reported': 'Pagamento informado pelo turista',
  'converted': 'Convertido',
  'interested': 'Interessado',
  'utilized': 'Utilizado',
  'completed': 'Concluído',
  'declined': 'Recusado',
  'disputed': 'Em análise de divergência',
  'cancelled': 'Cancelado',
  'expired': 'Vencido',
  'partial_refund': 'Estornado parcialmente',
  'refunded': 'Estornado integralmente',
};

String? commercialCouponCode(String input) {
  final text = input.trim().toUpperCase();
  final code = text.startsWith('MARAPASS:CUPOM:')
      ? text.substring('MARAPASS:CUPOM:'.length)
      : text;
  return RegExp(r'^MP-[A-F0-9]{32}$').hasMatch(code) ? code : null;
}

const couponFeeStates = {
  'pending': 'Pendente',
  'invoiced': 'Faturada',
  'paid': 'Paga',
  'disputed': 'Contestada',
};
