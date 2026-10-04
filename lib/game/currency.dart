/// Currency helpers.
///
/// Snowfall Odyssey uses "fans" (fun coins) as its in-game currency to make it
/// explicit that this is a free, entertainment-only slot demo and NOT a
/// real-money gambling product.
library;

const String kCurrencyName = 'FANS';
const String kCurrencyDisclaimer =
    'Not real money. For fun only.';
const String kCurrencyDisclaimerLong =
    'Snowfall Odyssey is a free-to-play social slot experience. '
    'FANS are virtual credits with no monetary value and cannot be '
    'exchanged for real money or prizes.';

/// Format an amount in the fun currency, e.g. `1,250 FANS`.
String formatFans(num v, {bool withUnit = true}) {
  final n = v.round();
  final s = _addThousandsSep(n.abs().toString());
  final signed = n < 0 ? '-$s' : s;
  return withUnit ? '$signed FANS' : signed;
}

String _addThousandsSep(String s) {
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}
