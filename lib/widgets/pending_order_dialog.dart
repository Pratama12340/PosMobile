import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../constants/style.dart';

class PendingOrderPanel extends StatelessWidget {
  final List<Order> pendingOrders;
  final bool isLoading;
  final String Function(double) formatHarga;
  final Function(Order) onOrderSelected;
  final VoidCallback onClose;

  const PendingOrderPanel({
    super.key,
    required this.pendingOrders,
    required this.isLoading,
    required this.formatHarga,
    required this.onOrderSelected,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(-5, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppStyle.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.receipt_long,
                    color: AppStyle.primaryBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "Pesanan Tertunda",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ),
                InkWell(
                  onTap: onClose,
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(
                      Icons.close_rounded,
                      color: Colors.black54,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF5F5F5)),

          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppStyle.primaryBlue,
                    ),
                  )
                : pendingOrders.isEmpty
                ? const Center(
                    child: Text(
                      "Tidak ada pesanan tertunda.",
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    itemCount: pendingOrders.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, color: Color(0xFFF5F5F5)),
                    itemBuilder: (context, index) {
                      final order = pendingOrders[index];

                      String custName = order.customerName;
                      String tableNo = order.tableId?.toString() ?? '-';
                      double total = (order.totalPrice).toDouble();

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFF8FAFC),
                          child: Text(
                            tableNo,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppStyle.primaryBlue,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        title: Text(
                          custName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            "Total: ${formatHarga(total)}",
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppStyle.primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios,
                            size: 12,
                            color: AppStyle.primaryBlue,
                          ),
                        ),
                        onTap: () {
                          onOrderSelected(order);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
