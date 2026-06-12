import 'package:flutter/material.dart';
import 'package:sistem_pos/features/orders/models/order_model.dart';
import 'package:sistem_pos/core/constants/style.dart';
import 'package:sistem_pos/features/printer/utils/print_helper.dart';

class SuccessPaymentPage extends StatefulWidget {
  final String orderId;
  final String outletName;
  final String outletAddress;
  final String paymentMethod;
  final double grandTotal;
  final List<dynamic> taxBreakdown;
  final double discountAmount;
  final double amountPaid;
  final double change;
  final Map<int, OrderItem> cart;
  final String tableNumber;
  final String customerName;
  final String cashierName;
  final String Function(double) formatCurrency;

  const SuccessPaymentPage({
    super.key,
    required this.orderId,
    required this.outletName,
    required this.outletAddress,
    required this.paymentMethod,
    required this.grandTotal,
    required this.discountAmount,
    required this.taxBreakdown,
    required this.amountPaid,
    required this.change,
    required this.cart,
    required this.tableNumber,
    required this.customerName,
    required this.cashierName,
    required this.formatCurrency,
  });

  @override
  State<SuccessPaymentPage> createState() => _SuccessPaymentPageState();
}

class _SuccessPaymentPageState extends State<SuccessPaymentPage> {
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    // Auto-print struk begitu halaman terbuka
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _executePrint();
    });
  }

  // Fungsi cetak yang dipakai auto-print & tombol manual
  Future<void> _executePrint() async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);

    try {
      final itemsForPrinting = PrintHelper.orderItemsToCartItems(
        widget.cart.values.toList(),
        filterVoided: false,
      );

      final transaction = PrintHelper.buildTransaction(
        orderId: widget.orderId,
        outletName: widget.outletName,
        outletAddress: widget.outletAddress,
        cashierName: widget.cashierName,
        customerName: widget.customerName,
        tableNumber: widget.tableNumber,
        items: itemsForPrinting,
        taxBreakdown: List<Map<String, dynamic>>.from(widget.taxBreakdown),
        discountAmount: widget.discountAmount,
        totalPrice: widget.grandTotal,
      );

      await PrintHelper.printToAllPrinters(
        transaction: transaction,
        onSuccess: (name) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("✓ $name berhasil mencetak struk."),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        onError: (name, e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Gagal cetak ke $name: $e"),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        onNoPrinter: () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Tidak ada printer aktif. Struk tidak dicetak."),
                backgroundColor: Colors.orange,
              ),
            );
          }
        },
      );
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F9),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            margin: const EdgeInsets.all(40.0),
            padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF4CAF50),
                  size: 120,
                ),
                const SizedBox(height: 24),
                const Text(
                  "Pembayaran Berhasil!",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.orderId,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontFamily: 'Poppins',
                  ),
                ),
                if (widget.customerName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    "Customer: ${widget.customerName}",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppStyle.primaryBlue,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
                const SizedBox(height: 40),

                if (widget.paymentMethod.toLowerCase() == 'cash' ||
                    widget.paymentMethod == 'Tunai')
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFF),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE8F0FE)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "Uang Kembalian",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 18,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.formatCurrency(widget.change),
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF4CAF50),
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    children: [
                      const Text(
                        "Total Pembayaran",
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                      Text(
                        widget.formatCurrency(widget.grandTotal),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4285F4),
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 60),

                Row(
                  children: [
                    Expanded(
                      child: _buildActionBtn(
                        context,
                        "Transaksi Baru",
                        const Color(0xFF4CAF50),
                        Icons.add_shopping_cart_rounded,
                        true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildActionBtn(
                        context,
                        _isPrinting ? "Mencetak..." : "Cetak Struk",
                        const Color(0xFF4285F4),
                        Icons.print_rounded,
                        false,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionBtn(
    BuildContext context,
    String label,
    Color color,
    IconData icon,
    bool isBack,
  ) {
    return SizedBox(
      height: 65,
      child: ElevatedButton.icon(
        onPressed: _isPrinting && !isBack
            ? null // disable tombol cetak saat sedang mencetak
            : isBack
                ? () => Navigator.of(context).popUntil((route) => route.isFirst)
                : () => _executePrint(), // cetak ulang manual
        icon: _isPrinting && !isBack
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Icon(icon, size: 22),
        label: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            fontFamily: 'Poppins',
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}