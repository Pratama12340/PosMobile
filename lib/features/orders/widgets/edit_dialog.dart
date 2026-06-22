import 'package:sistem_pos/core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sistem_pos/core/constants/style.dart';
import 'package:sistem_pos/features/orders/models/order_model.dart';
import 'package:sistem_pos/core/services/storage_service.dart';
import 'package:sistem_pos/features/orders/services/order_api_service.dart';
import 'package:sistem_pos/core/network/master_api_service.dart';
import 'package:sistem_pos/features/auth/services/auth_api_service.dart';
import 'package:sistem_pos/core/utils/app_keys.dart';
import 'package:sistem_pos/features/printer/utils/print_helper.dart';
import 'package:sistem_pos/core/utils/tax_calculator.dart' as tax_calc;
import 'package:sistem_pos/core/utils/string_utils.dart';
import 'package:sistem_pos/core/utils/snackbar_helper.dart';
class ReceiptDialog extends StatefulWidget {
  final int orderId;
  const ReceiptDialog({super.key, required this.orderId});

  @override
  State<ReceiptDialog> createState() => _ReceiptDialogState();
}

class _ReceiptDialogState extends State<ReceiptDialog> {
  late Future<Order?> _detailFuture;
  Order? localOrder;
  bool isEditMode = false;
  final TextEditingController _noteController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _currentUserName = "";
  List<dynamic> _masterTaxes = [];
  bool _isPrinting = false;
  bool _isSaving = false;

  double _totalBeforeEdit = 0;
  // Snapshot activeQty tiap item saat masuk mode edit, untuk di-rollback bila
  // user menekan "Batal" (qty dimutasi langsung di localOrder.items).
  List<int>? _qtyBeforeEdit;
  SharedPreferences? _prefs;
  bool _prefsReady = false;

  @override
  void initState() {
    super.initState();
    _detailFuture = OrderApiService.fetchHistoryDetail(widget.orderId);
    _loadCurrentUserData();
    _loadTaxSettings();
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _prefsReady = true);
  }

  String _sanitizeKey(String raw) {
    return raw
        .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .toLowerCase();
  }

  String _buildRefundKey(OrderLog log) {
    final raw = 'refund_${widget.orderId}_${log.title}_${log.reason}';
    return _sanitizeKey(raw);
  }

  Future<void> _loadCurrentUserData() async {
    String name = await StorageService.getCashierName();
    setState(() => _currentUserName = name);
  }

  void _loadTaxSettings() async {
    final taxes = await MasterApiService.getTaxes();
    if (mounted) setState(() => _masterTaxes = taxes);
  }

  // ← TAMBAH FUNGSI INI
  Future<void> _executePrint() async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);

    try {
      final outletInfo = await AuthApiService.fetchOutletInfoLive();

      final itemsForPrinting = PrintHelper.orderItemsToCartItems(
        localOrder!.items,
        filterVoided: false,
      );

      final List<Map<String, dynamic>> taxDetails = calculatedTaxBreakdown
          .map((tax) => {
                'name': tax['name'],
                'calculated_amount': tax['calculated_amount'],
              })
          .toList();

      final transaction = PrintHelper.buildTransaction(
        orderId: localOrder!.invoiceNo,
        outletName: outletInfo['name'] ?? "Outlet",
        outletAddress: outletInfo['address_outlet'] ?? "-",
        cashierName: _currentUserName,
        customerName: localOrder!.customerName,
        tableNumber: localOrder!.tableNo,
        items: itemsForPrinting,
        taxBreakdown: taxDetails,
        discountAmount: localOrder!.discountAmount,
        totalPrice: isEditMode ? currentTotalPrice : localOrder!.totalPrice,
      );

      await PrintHelper.printToAllPrinters(
        transaction: transaction,
        onSuccess: (name) {
          snackbarKey.currentState?.showSnackBar(
            SnackBar(
              content: Text("✓ $name berhasil mencetak."),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        onError: (name, e) {
          snackbarKey.currentState?.showSnackBar(
            SnackBar(
              content: Text("Gagal cetak ke $name: $e"),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        onNoPrinter: () {
          snackbarKey.currentState?.showSnackBar(
            const SnackBar(
              content: Text("Tidak ada printer aktif."),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      );
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  double get currentSubtotalPrice {
    if (localOrder == null) return 0;
    double total = 0;
    for (var item in localOrder!.items) {
      total += item.activeQty * item.unitPrice;
    }
    return total;
  }

  double get baseAmount {
    if (localOrder == null) return 0;
    return currentSubtotalPrice - localOrder!.discountAmount;
  }

  List<Map<String, dynamic>> get calculatedTaxBreakdown {
    if (localOrder == null || _masterTaxes.isEmpty) return [];
    return tax_calc.calculateTaxBreakdown(baseAmount, _masterTaxes);
  }

  double get currentTaxAmount => calculatedTaxBreakdown.fold(
      0.0, (sum, t) => sum + (t['calculated_amount'] as double));

  double get currentTotalPrice {
    if (localOrder == null) return 0;
    final total = baseAmount + currentTaxAmount;
    return total < 0 ? 0 : total;
  }

  @override
  Widget build(BuildContext context) {
    final style = AppStyle();

    return FutureBuilder<Order?>(
      future: _detailFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            localOrder == null) {
          return const Dialog(
            child: SizedBox(
                height: 300,
                child: Center(child: CircularProgressIndicator())),
          );
        }

        if (snapshot.hasData && localOrder == null) {
          localOrder = snapshot.data;

          if (_prefs != null && localOrder != null && localOrder!.logs.isNotEmpty) {
            final oldRefund = _prefs!.getDouble('refund_${widget.orderId}');
            if (oldRefund != null && oldRefund > 0) {
              final firstLog = localOrder!.logs.first;
              final logKey = _buildRefundKey(firstLog);
              _prefs!.setDouble(logKey, oldRefund);
              _prefs!.remove('refund_${widget.orderId}');
            }
          }
        }

        if (localOrder == null) {
          return const Dialog(
              child: Center(child: Text("Data tidak ditemukan")));
        }

        bool showRightSide = localOrder!.logs.isNotEmpty || isEditMode;

        double displaySubtotal =
            isEditMode ? currentSubtotalPrice : localOrder!.subtotalPrice;
        double displayBase = displaySubtotal - localOrder!.discountAmount;
        double displayTotal =
            isEditMode ? currentTotalPrice : localOrder!.totalPrice;

        return Dialog(
          backgroundColor: const Color(0xFFF8FAFC),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width *
                  (showRightSide ? 0.85 : 0.5),
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            child: Form(
              key: _formKey,
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: showRightSide
                            ? const BorderRadius.horizontal(
                                left: Radius.circular(24))
                            : BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeaderCustom(),
                          const SizedBox(height: 24),
                          _buildCashierInfoBox(),
                          const SizedBox(height: 32),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Rincian Pesanan",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 22)),
                              _buildEditToggleButton(),
                            ],
                          ),
                          const Divider(height: 32, thickness: 1),
                          Expanded(
                            child: ListView(
                              children: localOrder!.items
                                  .map((item) =>
                                      _buildItemRowCustom(item, style))
                                  .toList(),
                            ),
                          ),
                          const Divider(height: 24, thickness: 1),

                          _buildSummaryRow(
                              "Subtotal", CurrencyFormatter.format(displaySubtotal)),

                          if (localOrder!.discountAmount > 0)
                            _buildSummaryRow(
                              "Diskon",
                              "-${CurrencyFormatter.format(localOrder!.discountAmount)}",
                              color: Colors.red,
                            ),

                          if (_masterTaxes.isNotEmpty)
                            ...() {
                              if (isEditMode) {
                                return calculatedTaxBreakdown.map((tax) {
                                  double amt =
                                      tax['calculated_amount'] as double;
                                  double rate = double.tryParse(
                                          tax['rate']?.toString() ?? '0') ??
                                      0;
                                  String label = tax['name'] ?? "Pajak";
                                  if (tax['type'] == 'percentage') {
                                    label += " (${rate.toStringAsFixed(0)}%)";
                                  }
                                  return _buildSummaryRow(
                                      label, CurrencyFormatter.format(amt));
                                }).toList();
                              }

                              double serviceTotal = 0;
                              final List<Widget> rows = [];

                              for (var tax in _masterTaxes) {
                                final name = (tax['name'] ?? '')
                                    .toString()
                                    .toLowerCase();
                                final isPpn = name.contains('ppn') ||
                                    name.contains('vat') ||
                                    name.contains('tax');
                                if (isPpn) continue;

                                double rate = double.tryParse(
                                        tax['rate']?.toString() ?? '0') ??
                                    0;
                                double amt = (tax['type'] == 'percentage')
                                    ? (displayBase * (rate / 100))
                                    : rate;
                                serviceTotal += amt;

                                String label = tax['name'] ?? "Pajak";
                                if (tax['type'] == 'percentage') {
                                  label += " (${rate.toStringAsFixed(0)}%)";
                                }
                                rows.add(_buildSummaryRow(
                                    label, CurrencyFormatter.format(amt)));
                              }

                              final afterService = displayBase + serviceTotal;
                              for (var tax in _masterTaxes) {
                                final name = (tax['name'] ?? '')
                                    .toString()
                                    .toLowerCase();
                                final isPpn = name.contains('ppn') ||
                                    name.contains('vat') ||
                                    name.contains('tax');
                                if (!isPpn) continue;

                                double rate = double.tryParse(
                                        tax['rate']?.toString() ?? '0') ??
                                    0;
                                double amt = (tax['type'] == 'percentage')
                                    ? (afterService * (rate / 100))
                                    : rate;

                                String label = tax['name'] ?? "Pajak";
                                if (tax['type'] == 'percentage') {
                                  label += " (${rate.toStringAsFixed(0)}%)";
                                }
                                rows.add(_buildSummaryRow(
                                    label, CurrencyFormatter.format(amt)));
                              }

                              return rows;
                            }()
                          else if (localOrder!.taxAmount > 0)
                            _buildSummaryRow(
                                "Pajak",
                                CurrencyFormatter.format(localOrder!.taxAmount)),

                          const Divider(height: 32, thickness: 1),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Total Tagihan",
                                  style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold)),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    CurrencyFormatter.format(displayTotal),
                                    style: const TextStyle(
                                        fontSize: 32,
                                        color: AppStyle.successGreen,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    "Metode: ${localOrder!.paymentMethod}",
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (showRightSide)
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isEditMode) ...[
                              const Text("Input Perubahan",
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 16),
                              _buildNoteInput(),
                              const SizedBox(height: 12),
                              _buildSaveButton(),
                              const Divider(height: 40),
                            ],
                            const Row(
                              children: [
                                Icon(Icons.history_rounded,
                                    color: Colors.blueGrey),
                                SizedBox(width: 8),
                                Text("Log Perubahan",
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blueGrey)),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Expanded(
                              child: localOrder!.logs.isEmpty
                                  ? const Center(
                                      child: Text(
                                          "Riwayat akan muncul di sini",
                                          style:
                                              TextStyle(color: Colors.grey)))
                                  : _buildTimelineLogs(style),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimelineLogs(AppStyle style) {
    return ListView.builder(
      itemCount: localOrder!.logs.length,
      itemBuilder: (context, index) {
        final log = localOrder!.logs[index];

        if (!_prefsReady) return const SizedBox.shrink();
        final logKey = _buildRefundKey(log);
        final double logRefundAmount = _prefs!.getDouble(logKey) ?? 0.0;
        final bool showRefundHere = logRefundAmount > 0;

        final bool isLatest = index == 0;
        final bool isLast = index == localOrder!.logs.length - 1;

        String formattedTitle = log.title.replaceAllMapped(
          RegExp(r'Void (\d+)x'),
          (match) => '- ${match.group(1)}',
        );

        final parsedDate = _parseLogDate(log.date);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                const SizedBox(height: 3),
                Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: isLatest
                        ? const Color(0xFF4285F4)
                        : Colors.blueGrey.shade200,
                    shape: BoxShape.circle,
                    boxShadow: isLatest
                        ? [
                            BoxShadow(
                              color: const Color(0xFF4285F4).withValues(alpha: 0.35),
                              blurRadius: 6,
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: _estimateLineHeight(showRefundHere),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF4285F4).withValues(alpha: 0.3),
                          Colors.blue.withValues(alpha: 0.05),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 13,
                            backgroundColor:
                                const Color(0xFF4285F4).withValues(alpha: 0.12),
                            child: Text(
                              _getInitial(log.actor == "Staff"
                                  ? _currentUserName
                                  : log.actor),
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF4285F4),
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            log.actor == "Staff"
                                ? _currentUserName
                                : log.actor,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                      if (isLatest)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4285F4).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            "Terbaru",
                            style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF4285F4),
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 11, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        parsedDate['date'] ?? '-',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey),
                      ),
                      if (parsedDate['time'] != null && parsedDate['time']!.isNotEmpty) ...[
                        Container(
                          margin:
                              const EdgeInsets.symmetric(horizontal: 8),
                          width: 3,
                          height: 3,
                          decoration: const BoxDecoration(
                            color: Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const Icon(Icons.access_time_rounded,
                            size: 11, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          parsedDate['time']!,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 10),

                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isLatest
                            ? const Color(0xFF4285F4).withValues(alpha: 0.22)
                            : Colors.grey.withValues(alpha: 0.1),
                        width: isLatest ? 1.5 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4285F4).withValues(alpha: 0.07),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(14)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.edit_note_rounded,
                                  size: 15, color: Color(0xFF4285F4)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  formattedTitle,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Color(0xFF4285F4)),
                                ),
                              ),
                            ],
                          ),
                        ),

                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 13,
                                  color: Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  log.reason,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black87,
                                      fontStyle: FontStyle.italic,
                                      height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (showRefundHere) ...[
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 13),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF1FBF4),
                              borderRadius: BorderRadius.vertical(
                                  bottom: Radius.circular(14)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF4CAF50),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.keyboard_return_rounded,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Kembalikan ke Customer • ${parsedDate['time'] ?? 'Sukses'}",
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.black45,
                                            fontWeight: FontWeight.w500),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        CurrencyFormatter.format(logRefundAmount),
                                        style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF2E7D32)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else
                          const SizedBox(height: 4),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  double _estimateLineHeight(bool withRefund) => withRefund ? 215 : 160;

  String _getInitial(String name) => StringUtils.getInitials(name);

  Map<String, String?> _parseLogDate(String rawDate) {
    if (rawDate.trim().isEmpty || rawDate == '-' || rawDate == 'null') {
      return {'date': '-', 'time': null};
    }

    try {
      DateTime? dt = DateTime.tryParse(rawDate);

      dt ??= DateTime.tryParse(rawDate.replaceFirst(' ', 'T'));

      if (dt != null) {
        dt = dt.toLocal();
        final day = dt.day.toString().padLeft(2, '0');
        final month = _monthName(dt.month);
        final year = dt.year;
        final hour = dt.hour.toString().padLeft(2, '0');
        final minute = dt.minute.toString().padLeft(2, '0');
        return {
          'date': '$day $month $year',
          'time': '$hour:$minute WIB',
        };
      }
    } catch (_) {}

    final timeRegex = RegExp(r'\b\d{1,2}:\d{2}(?::\d{2})?\b');
    final match = timeRegex.firstMatch(rawDate);
    if (match != null) {
      final time = match.group(0)!;
      final date = rawDate.replaceAll(time, '').trim();
      return {
        'date': date.isNotEmpty ? date : rawDate,
        'time': '$time WIB'
      };
    }

    return {'date': rawDate, 'time': null};
  }

  String _monthName(int month) {
    const months = [
      '',
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return months[month];
  }

  Widget _buildHeaderCustom() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                localOrder!.invoiceNo,
                style: const TextStyle(
                    fontSize: 26,
                    color: Color(0xFF4285F4),
                    fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text("${_parseLogDate(localOrder!.date)['date']} • Outlet 1",
                  style: const TextStyle(color: Colors.grey, fontSize: 14)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: _isPrinting ? null : _executePrint, // ← UBAH INI
          icon: _isPrinting // ← UBAH INI
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.print, size: 20, color: Colors.white),
          label: Text( // ← UBAH INI
            _isPrinting ? "Mencetak..." : "Cetak",
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4285F4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildCashierInfoBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildInfoColumn("CUSTOMER", localOrder!.customerName),
          _buildInfoColumn("TABLE", localOrder!.tableNo, isRight: true),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value, {bool isRight = false}) {
    return Column(
      crossAxisAlignment:
          isRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF4285F4),
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildItemRowCustom(OrderItem item, AppStyle style) {
    final bool isZero = item.activeQty == 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: isZero ? Colors.red : Colors.black87,
                    decoration: isZero
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    decorationColor: isZero ? Colors.red : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "${item.activeQty} x ${CurrencyFormatter.format(item.unitPrice)}",
                  style: TextStyle(
                    fontSize: 13,
                    color: isZero
                        ? Colors.red.withValues(alpha: 0.6)
                        : Colors.grey,
                    decoration: isZero
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
                if (item.notes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      "Notes: ${item.notes}",
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
            ),
          ),
          if (isEditMode) _buildQtyController(item),
          const SizedBox(width: 20),
          Text(
            CurrencyFormatter.format(item.activeQty * item.unitPrice),
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isZero ? Colors.red : Colors.black87,
                decoration: isZero
                    ? TextDecoration.lineThrough
                    : TextDecoration.none),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value,
      {Color color = Colors.black87}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.grey, 
                  fontSize: 14, 
                  fontWeight: FontWeight.w500)),
          Text(value,
              style: TextStyle(
                  fontSize: 16, 
                  fontWeight: FontWeight.w700, 
                  color: color)),
        ],
      ),
    );
  }

  Widget _buildEditToggleButton() {
    return OutlinedButton.icon(
      onPressed: () => setState(() {
        if (!isEditMode) {
          // Masuk mode edit: simpan total & snapshot qty untuk rollback.
          _totalBeforeEdit = localOrder!.totalPrice;
          _qtyBeforeEdit =
              localOrder!.items.map((it) => it.activeQty).toList();
        } else {
          // Tekan "Batal": kembalikan qty ke nilai sebelum edit.
          final snapshot = _qtyBeforeEdit;
          if (snapshot != null) {
            for (int i = 0;
                i < localOrder!.items.length && i < snapshot.length;
                i++) {
              localOrder!.items[i].activeQty = snapshot[i];
            }
          }
          _qtyBeforeEdit = null;
        }
        isEditMode = !isEditMode;
      }),
      icon: Icon(isEditMode ? Icons.close : Icons.edit_note,
          color: Colors.redAccent, size: 18),
      label: Text(isEditMode ? "Batal" : "Edit Item",
          style: const TextStyle(color: Colors.redAccent)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.redAccent),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildQtyController(OrderItem item) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline,
              color: Colors.redAccent),
          onPressed: () =>
              setState(() => item.activeQty > 0 ? item.activeQty-- : null),
        ),
        Text("${item.activeQty}",
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _buildNoteInput() {
    return TextFormField(
      controller: _noteController,
      maxLines: 2,
      decoration: InputDecoration(
        hintText: "Tulis alasan perubahan...",
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
      ),
      validator: (value) =>
          (value == null || value.isEmpty) ? "Wajib isi alasan" : null,
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 45,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.redAccent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: _isSaving ? null : _handleSaveButton,
        child: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text("Simpan Perubahan",
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _handleSaveButton() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      try {
        final totalBefore = _totalBeforeEdit;
        final totalAfter = currentTotalPrice;

        final success = await OrderApiService.updateOrder(
          orderId: localOrder!.orderId,
          items: localOrder!.items,
          reason: _noteController.text,
          taxAmount: currentTaxAmount,
          totalPrice: totalAfter,
        );

        if (!mounted) return;
        setState(() => _isSaving = false);

        if (success) {
          final diff = totalBefore - totalAfter;
          final newOrder =
              await OrderApiService.fetchHistoryDetail(widget.orderId);

          if (diff > 0 && newOrder != null && newOrder.logs.isNotEmpty) {
            final newLog = newOrder.logs.first;
            final logKey = _buildRefundKey(newLog);
            if (_prefs != null) {
              await _prefs!.setDouble(logKey, diff);
            }
          }

          if (!mounted) return;
          setState(() {
            localOrder = newOrder;
            _detailFuture = Future.value(newOrder);
            isEditMode = false;
            _qtyBeforeEdit = null; // snapshot lama tidak relevan utk order baru
            _noteController.clear();
          });
          SnackbarHelper.showSuccess(context, "Pesanan berhasil diperbarui");
        } else {
          SnackbarHelper.showError(context, "Gagal memperbarui pesanan");
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _isSaving = false);
        SnackbarHelper.showError(context, e);
      }
    }
  }
}

