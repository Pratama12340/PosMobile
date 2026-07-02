import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sistem_pos/core/constants/style.dart';

class PaymentSelector extends StatelessWidget {
  final bool isUpdatingOrder;
  final String paymentMethod;
  final TextEditingController manualTenderController;
  final bool isLoading;
  final bool isLoadingPayment;
  final bool isKeyboardOpen;
  final String? errorMessage;
  final bool isExactChange;
  final double? selectedQuickAmount;
  final double grandTotal;
  final int tagihanInt;
  final int uangMasukInt;
  final int change;
  final String? qrUrl;
  final String? redirectUrl;
  final WebViewController? webViewController;
  final String Function(double) formatCurrency;
  
  final Function(String) onPaymentMethodChanged;
  final Function(String) onManualAmountChanged;
  final Function(double, bool) onQuickAmountSelected;
  final Future<void> Function(String) onProcessPayment;

  const PaymentSelector({
    super.key,
    required this.isUpdatingOrder,
    required this.paymentMethod,
    required this.manualTenderController,
    required this.isLoading,
    required this.isLoadingPayment,
    this.isKeyboardOpen = false,
    this.errorMessage,
    required this.isExactChange,
    this.selectedQuickAmount,
    required this.grandTotal,
    required this.tagihanInt,
    required this.uangMasukInt,
    required this.change,
    this.qrUrl,
    this.redirectUrl,
    this.webViewController,
    required this.formatCurrency,
    required this.onPaymentMethodChanged,
    required this.onManualAmountChanged,
    required this.onQuickAmountSelected,
    required this.onProcessPayment,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: paymentMethod == 'Cash' ? MainAxisAlignment.spaceBetween : MainAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        isUpdatingOrder ? "Bayar Pesanan (Update)" : "Payment Method",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          _payBtn('Cash', Icons.payments_outlined),
                          const SizedBox(width: 15),
                          _payBtn('Card', Icons.credit_card_outlined),
                          const SizedBox(width: 15),
                          _payBtn('Qris', Icons.qr_code_scanner),
                        ],
                      ),
                      if (paymentMethod != 'Cash') ...[
                        const SizedBox(height: 30),
                        _buildCashlessView(),
                      ] else ...[
                        const SizedBox(height: 30),
                      ],
                    ],
                  ),
                  if (paymentMethod == 'Cash')
                    TextField(
                      controller: manualTenderController,
                      textAlign: TextAlign.left,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        CurrencyInputFormatter(),
                      ],
                      style: AppStyle.numPadText.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppStyle.primaryBlue,
                      ),
                      decoration: InputDecoration(
                        prefixText: "Rp ",
                        prefixStyle: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppStyle.primaryBlue,
                        ),
                        hintText: "Isi Uang Manual",
                        hintStyle: const TextStyle(
                          fontSize: 18,
                          color: Colors.black38,
                          fontWeight: FontWeight.normal,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: const BorderSide(color: AppStyle.primaryBlue, width: 2),
                        ),
                      ),
                      onChanged: onManualAmountChanged,
                    ),
                  if (paymentMethod == 'Cash' && !isKeyboardOpen)
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 2.2,
                      children: [
                        _quickBtn(grandTotal, label: "Bayar Pas", isExact: true),
                        ...[
                          20000.0,
                          50000.0,
                          100000.0,
                          150000.0,
                          200000.0,
                        ].map((v) => _quickBtn(v)),
                      ],
                    ),
                  if (paymentMethod == 'Cash')
                    Opacity(
                      opacity: change >= 0 ? 1.0 : 0.0,
                      child: _buildChangeDisplay(change < 0 ? 0 : change.toDouble()),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _payBtn(String l, IconData i, {bool isEnabled = true}) {
    bool s = paymentMethod == l;
    return Expanded(
      child: GestureDetector(
        onTap: (isEnabled && !isLoading)
            ? () async {
                onPaymentMethodChanged(l);
                if (l != 'Cash') {
                  await onProcessPayment(l);
                }
              }
            : null,
        child: Opacity(
          opacity: isEnabled ? 1.0 : 0.4,
          child: Container(
            height: 85,
            decoration: BoxDecoration(
              color: s ? AppStyle.primaryBlue : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: s ? AppStyle.primaryBlue : const Color(0xFFEEEEEE),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading && s)
                  const SizedBox(
                    height: 28,
                    width: 28,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                else
                  Icon(
                    i,
                    color: s ? Colors.white : AppStyle.textMain,
                    size: 28,
                  ),
                const SizedBox(height: 8),
                Text(
                  l,
                  style: TextStyle(
                    color: s ? Colors.white : AppStyle.textMain,
                    fontWeight: s ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _quickBtn(double v, {String? label, bool isExact = false}) {
    bool isSelected = selectedQuickAmount == v &&
        (label == null || isExactChange == isExact);

    if (label == "Bayar Pas") {
      isSelected = isExactChange;
    }

    return GestureDetector(
      onTap: () => onQuickAmountSelected(v, isExact),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppStyle.primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppStyle.primaryBlue : const Color(0xFFEEEEEE),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppStyle.primaryBlue.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Text(
          label ?? formatCurrency(v),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppStyle.textMain,
          ),
        ),
      ),
    );
  }

  Widget _buildChangeDisplay(double c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.green.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Kembalian",
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            Text(
              formatCurrency(c),
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w900,
                fontSize: 24,
              ),
            ),
          ],
        ),
      );

  Widget _buildCashlessView() {
    if (errorMessage != null) {
      return SizedBox(
        height: 360,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (isLoadingPayment) {
      return const SizedBox(
        height: 360,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppStyle.primaryBlue),
            SizedBox(height: 16),
            Text(
              "Memuat halaman pembayaran...",
              style: TextStyle(color: Colors.black45, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (paymentMethod == 'Qris') {
      if (qrUrl == null && redirectUrl == null) {
        return const SizedBox(
          height: 360,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppStyle.primaryBlue),
              SizedBox(height: 16),
              Text(
                "Memuat QR Code...",
                style: TextStyle(color: Colors.black45, fontSize: 13),
              ),
            ],
          ),
        );
      }

      bool isHttpImage = qrUrl != null && qrUrl!.startsWith('http');
      String? qrData = isHttpImage ? null : (qrUrl ?? redirectUrl);

      return Container(
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: isHttpImage
                  ? Image.network(
                      qrUrl!,
                      width: 280,
                      height: 280,
                      fit: BoxFit.contain,
                      errorBuilder: (ctx, err, stack) => const SizedBox(
                        width: 280,
                        height: 280,
                        child: Center(child: Text("Gagal memuat QR Code")),
                      ),
                    )
                  : (qrData != null && qrData.isNotEmpty
                      ? QrImageView(
                          data: qrData,
                          version: QrVersions.auto,
                          size: 280.0,
                          backgroundColor: Colors.white,
                        )
                      : const SizedBox(
                          width: 280,
                          height: 280,
                          child: Center(child: Text("Data QR tidak tersedia")),
                        )),
            ),
            const SizedBox(height: 16),
            const Text(
              "Silakan scan QR Code di atas\nuntuk menyelesaikan pembayaran.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ),
      );
    }

    if (paymentMethod == 'Card') {
      if (webViewController != null) {
        return Container(
          height: 360,
          margin: const EdgeInsets.only(top: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: AppStyle.primaryBlue.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: WebViewWidget(controller: webViewController!),
        );
      }

      return SizedBox(
        height: 360,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading) ...[
              const CircularProgressIndicator(color: AppStyle.primaryBlue),
              const SizedBox(height: 10),
              const Text("Memproses...", style: TextStyle(color: Colors.black45, fontSize: 12)),
            ],
          ],
        ),
      );
    }

    return const SizedBox(height: 360);
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue o, TextEditingValue n) {
    if (n.text.isEmpty) return n.copyWith(text: '');

    // Temukan jumlah digit sebelum kursor
    int selectionIndex = n.selection.baseOffset;
    if (selectionIndex < 0) {
      selectionIndex = n.text.length;
    }
    String substringToCursor = n.text.substring(0, selectionIndex);
    int digitsBeforeCursor = substringToCursor.replaceAll('.', '').length;

    // Bersihkan teks dan format kembali
    String cleanText = n.text.replaceAll('.', '');
    if (cleanText.isEmpty) return n.copyWith(text: '');

    String formattedText = NumberFormat.decimalPattern('id').format(double.parse(cleanText));

    // Hitung posisi kursor yang baru
    int newCursorOffset = formattedText.length; // Default ke akhir string
    int digitCount = 0;
    for (int i = 0; i < formattedText.length; i++) {
      if (digitCount == digitsBeforeCursor) {
        newCursorOffset = i;
        break;
      }
      if (formattedText[i] != '.') {
        digitCount++;
      }
    }

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: newCursorOffset),
    );
  }
}
