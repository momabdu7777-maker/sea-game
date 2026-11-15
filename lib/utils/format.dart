/// تنسيق الوزن: كسور للأسماك الصغيرة، وفواصل آلاف للعملاقة (قرش الحوت 1,250 كغ).
String formatKg(double w) {
  if (w < 1) return w.toStringAsFixed(2);
  if (w < 100) return w.toStringAsFixed(1);
  final n = w.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < n.length; i++) {
    if (i > 0 && (n.length - i) % 3 == 0) b.write(',');
    b.write(n[i]);
  }
  return b.toString();
}
