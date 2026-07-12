/// Menentukan apakah sebuah pajak tergolong PPN/VAT (dihitung DI ATAS service
/// charge), bukan biaya layanan / service charge.
///
/// Prioritas penentuan:
/// 1. Penanda eksplisit dari backend (`is_ppn` / `is_vat` / `category`).
/// 2. Fallback ke nama: mengandung "ppn" atau "vat", atau mengandung "tax"
///    SELAMA bukan biaya layanan (service / charge / layanan).
///
/// Catatan: pencocokan kata "tax" sengaja dikecualikan untuk nama yang juga
/// mengandung "service"/"charge"/"layanan" agar "Service Tax" tidak salah
/// dianggap PPN.
bool isPpnTax(dynamic tax) {
  // 1. Penanda eksplisit dari backend (paling andal)
  final flag = tax['is_ppn'] ?? tax['is_vat'];
  if (flag is bool) return flag;
  if (flag != null) {
    final s = flag.toString().toLowerCase();
    if (s == '1' || s == 'true') return true;
    if (s == '0' || s == 'false') return false;
  }
  final category =
      (tax['category'] ?? tax['tax_category'] ?? '').toString().toLowerCase();
  if (category.contains('ppn') || category.contains('vat')) return true;
  if (category.contains('service') || category.contains('layanan')) return false;

  // 2. Fallback ke nama
  final name = (tax['name'] ?? '').toString().toLowerCase();
  if (name.contains('ppn') || name.contains('vat')) return true;
  final isServiceCharge = name.contains('service') ||
      name.contains('charge') ||
      name.contains('layanan');
  return name.contains('tax') && !isServiceCharge;
}

/// Kalkulasi pajak bertingkat untuk checkout dan edit dialog.
///
/// Urutan kalkulasi:
/// 1. Hitung semua pajak non-PPN (Service Charge, dll) berdasarkan [baseAmount]
/// 2. Hitung PPN berdasarkan [baseAmount] + total service charge
///
/// Return: Map berisi 'tax_amount', 'tax_breakdown', dan 'grand_total'.
Map<String, dynamic> calculateTaxesAndGrandTotal(
  double baseAmount,
  List<dynamic> availableTaxes,
) {
  double serviceAmount = 0;

  // Langkah 1: Hitung service charge terlebih dahulu
  for (var tax in availableTaxes) {
    if (isPpnTax(tax)) continue; // PPN dihitung setelah service charge

    final double rate =
        double.tryParse(tax['rate']?.toString() ?? '0') ?? 0;
    final double amt = (tax['type'] == 'percentage')
        ? (baseAmount * (rate / 100))
        : rate;

    serviceAmount += amt;
  }

  // Langkah 2: Hitung semua pajak (termasuk PPN berdasarkan base + service)
  double totalTaxAmount = 0;
  final List<Map<String, dynamic>> taxBreakdown = [];
  final double afterService = baseAmount + serviceAmount;

  for (var tax in availableTaxes) {
    final double rate =
        double.tryParse(tax['rate']?.toString() ?? '0') ?? 0;
    final bool isPpn = isPpnTax(tax);

    double amt;
    if (isPpn) {
      // PPN dihitung dari base + service charge
      amt = (tax['type'] == 'percentage')
          ? (afterService * (rate / 100))
          : rate;
    } else {
      // Service charge dihitung dari base saja
      amt = (tax['type'] == 'percentage')
          ? (baseAmount * (rate / 100))
          : rate;
    }

    amt = amt.roundToDouble();
    totalTaxAmount += amt;

    final Map<String, dynamic> taxData = Map<String, dynamic>.from(tax);
    taxData['calculated_amount'] = amt;
    taxBreakdown.add(taxData);
  }

  // Urutkan agar pajak non-PPN (Service) muncul lebih dulu di atas PPN
  taxBreakdown.sort((a, b) {
    final bool isPpnA = isPpnTax(a);
    final bool isPpnB = isPpnTax(b);

    if (isPpnA && !isPpnB) return 1;
    if (!isPpnA && isPpnB) return -1;
    return 0;
  });

  return {
    'tax_amount': totalTaxAmount,
    'tax_breakdown': taxBreakdown,
    'grand_total': (baseAmount + totalTaxAmount).floorToDouble(),
  };
}

/// Versi sederhana yang hanya mengembalikan tax breakdown tanpa grand total.
/// Dipakai di edit_dialog.dart untuk menampilkan rincian pajak.
List<Map<String, dynamic>> calculateTaxBreakdown(
  double baseAmount,
  List<dynamic> masterTaxes,
) {
  final result = calculateTaxesAndGrandTotal(baseAmount, masterTaxes);
  return result['tax_breakdown'] as List<Map<String, dynamic>>;
}

/// Menghitung total pajak dari tax breakdown.
double calculateTotalTax(List<Map<String, dynamic>> taxBreakdown) {
  return taxBreakdown.fold(
    0.0,
    (sum, t) => sum + ((t['calculated_amount'] as double?) ?? 0.0),
  );
}
