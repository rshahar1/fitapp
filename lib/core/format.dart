import 'package:intl/intl.dart';

/// "20", "22.5", "22.25" (no trailing zeros).
String formatWeight(double kg) {
  if (kg == kg.roundToDouble()) return kg.toInt().toString();
  var s = kg.toStringAsFixed(2);
  if (s.endsWith('0')) s = s.substring(0, s.length - 1);
  return s;
}

/// "22.5 kg".
String formatKg(double kg) => '${formatWeight(kg)} kg';

/// "1,070 kg" (thousands separator, max 1 decimal).
String formatVolume(double kg) => '${NumberFormat('#,##0.#').format(kg)} kg';

String _two(int n) => n.toString().padLeft(2, '0');

/// "0:42", "12:05", "1:02:05".
String formatClock(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  return h > 0 ? '$h:${_two(m)}:${_two(s)}' : '${d.inMinutes}:${_two(s)}';
}

/// "45m", "1h 5m", "<1m".
String formatShortDuration(Duration d) {
  if (d.inSeconds < 60) return '<1m';
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  return h > 0 ? '${h}h ${m}m' : '${m}m';
}

/// "1:00", "0:05"; overtime (negative) is "+0:12".
String formatRest(Duration remaining) {
  if (remaining.isNegative) return '+${formatClock(-remaining)}';
  return formatClock(remaining);
}

/// "+11.1%", "-5.6%", "0%", null gives an em dash.
String formatPercent(double? p) {
  if (p == null) return '—';
  if (p == 0) return '0%';
  final s = NumberFormat('0.#').format(p.abs());
  return '${p > 0 ? '+' : '-'}$s%';
}

/// "Thu, 12 Nov".
String formatDateShort(DateTime d) => DateFormat('EEE, d MMM').format(d);

/// "November 2026".
String formatMonth(DateTime d) => DateFormat('MMMM y').format(d);

/// Pace as "5:30" from seconds per km; an em dash when unknown or absurd.
String formatPaceSec(num? secPerKm) {
  if (secPerKm == null || !secPerKm.isFinite || secPerKm >= 3600) return '—';
  final total = secPerKm.round();
  return '${total ~/ 60}:${_two(total % 60)}';
}

/// "12.3" km/h from metres per second; an em dash when unknown.
String formatSpeedMps(double? mps) =>
    mps == null || !mps.isFinite ? '—' : (mps * 3.6).toStringAsFixed(1);

/// "4.20" km from metres (two decimals, stable while ticking up).
String formatLiveKm(num meters) => (meters / 1000).toStringAsFixed(2);

/// "45 min" / "1 h 30 min" / "2 h".
String formatActivityMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m min';
  if (m == 0) return '$h h';
  return '$h h $m min';
}
