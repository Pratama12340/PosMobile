import 'package:flutter/material.dart';

class CheckoutDialog extends StatefulWidget {
  final Map<String, Map<String, dynamic>> cart;
  final int totalAmount;
  final String orderId;
  final String tableNumber;
  final String Function(int) formatCurrency;

  const CheckoutDialog({
    super.key,
    required this.cart,
    required this.totalAmount,
    required this.orderId,
    required this.tableNumber,
    required this.formatCurrency,
  });

  @override
  State<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<CheckoutDialog> {
  String _paymentMethod = 'Cash'; 
  int _amountTendered = 0;
  final TextEditingController _manualTenderController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _amountTendered = widget.totalAmount;
    _manualTenderController.text = widget.totalAmount.toString();
  }

  @override
  Widget build(BuildContext context) {
    int tax = (widget.totalAmount * 0.1).toInt();
    int subTotal = widget.totalAmount - tax;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 1000, height: 650,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            // SISI KIRI (PAYMENT)
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    const Text("Amount Tendered", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 25),
                      decoration: BoxDecoration(color: const Color(0xFFF1F2F6), borderRadius: BorderRadius.circular(15)),
                      child: Center(child: Text(widget.formatCurrency(_amountTendered), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, fontFamily: 'JetBrains'))),
                    ),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _payBtn('Card', Icons.credit_card),
                        const SizedBox(width: 15),
                        _payBtn('Cash', Icons.wallet),
                        const SizedBox(width: 15),
                        _payBtn('Qris', Icons.qr_code),
                      ],
                    ),
                    if (_paymentMethod == 'Cash') ...[
                      const SizedBox(height: 30),
                      Wrap(
                        spacing: 10, runSpacing: 10, alignment: WrapAlignment.center,
                        children: [50000, 100000, 150000, 200000].map((v) => _quickBtn(v)).toList(),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _manualTenderController, textAlign: TextAlign.center,
                        decoration: InputDecoration(hintText: "Input Manual", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                        onChanged: (v) => setState(() => _amountTendered = int.tryParse(v) ?? 0),
                      ),
                    ]
                  ],
                ),
              ),
            ),
            // SISI KANAN (SUMMARY)
            Expanded(
              flex: 4,
              child: Container(
                padding: const EdgeInsets.all(35), color: const Color(0xFFFAFAFA),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(widget.orderId, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, fontFamily: 'Poppins')),
                        GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text("Cashier : Siti Fatimah", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'Poppins')),
                    Text("No. Table : ${widget.tableNumber.isEmpty ? '...' : widget.tableNumber}", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'Poppins')),
                    const Divider(height: 30),
                    Expanded(
                      child: ListView.builder(
                        itemCount: widget.cart.length,
                        itemBuilder: (context, index) {
                          var entry = widget.cart.entries.elementAt(index);
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Poppins')),
                              Text(widget.formatCurrency(entry.value['qty'] * entry.value['price']), style: const TextStyle(fontFamily: 'JetBrains', fontWeight: FontWeight.bold)),
                            ],
                          );
                        },
                      ),
                    ),
                    const Divider(),
                    _rowInf("Sub Total", subTotal),
                    _rowInf("Tax (10%)", tax),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Total", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, fontFamily: 'Poppins')),
                        Text(widget.formatCurrency(widget.totalAmount), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.blue, fontFamily: 'JetBrains')),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, minimumSize: const Size(double.infinity, 55)),
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Pay Bills", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowInf(String l, int v) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Poppins')), Text(widget.formatCurrency(v), style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'JetBrains'))]));
  
  Widget _payBtn(String l, IconData i) {
    bool s = _paymentMethod == l;
    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = l),
      child: Container(
        width: 80, height: 80,
        decoration: BoxDecoration(color: s ? Colors.blue : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: s ? Colors.blue : Colors.grey.shade300)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(i, color: s ? Colors.white : Colors.black), Text(l, style: TextStyle(color: s ? Colors.white : Colors.black, fontSize: 10, fontFamily: 'Poppins'))]),
      ),
    );
  }

  Widget _quickBtn(int v) => GestureDetector(onTap: () { setState(() { _amountTendered = v; _manualTenderController.text = v.toString(); }); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(20)), child: Text(widget.formatCurrency(v), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'JetBrains'))));
}