import 'package:flutter/material.dart';
import 'package:sistem_pos/features/orders/models/order_model.dart';
import 'package:sistem_pos/core/constants/style.dart';
import 'package:sistem_pos/core/utils/currency_formatter.dart';

class PendingOrderPanel extends StatelessWidget {
  final List<Order> pendingOrders;
  final List<Order> paidOrders;
  final bool isLoadingPendingOrders;
  final VoidCallback onClose;
  final Function(Order) onAcceptOrder;
  final Function(Order) onLoadOrderToCart;

  const PendingOrderPanel({
    super.key,
    required this.pendingOrders,
    required this.paidOrders,
    required this.isLoadingPendingOrders,
    required this.onClose,
    required this.onAcceptOrder,
    required this.onLoadOrderToCart,
  });

  @override
  Widget build(BuildContext context) {
    final Set<int> seenIds = {};
    final List<Map<String, dynamic>> allItems = [
      ...pendingOrders.map((o) => {'order': o, 'type': 'pending'}),
    ].where((item) {
      final Order o = item['order'] as Order;
      return seenIds.add(o.id);
    }).toList();

    return Container(
      width: 340,
      margin: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Pesanan",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (pendingOrders.isNotEmpty)
                              _buildStatusBadge(
                                '${pendingOrders.length} Tertunda',
                                Colors.orange,
                              ),
                            if (pendingOrders.isNotEmpty && paidOrders.isNotEmpty)
                              const SizedBox(width: 6),
                          ],
                        ),
                      ],
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
              child: isLoadingPendingOrders
                  ? const Center(
                      child: CircularProgressIndicator(color: AppStyle.primaryBlue),
                    )
                  : allItems.isEmpty
                  ? const Center(
                      child: Text(
                        "Tidak ada pesanan.",
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      itemCount: allItems.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: Color(0xFFF5F5F5)),
                      itemBuilder: (context, index) {
                        final item = allItems[index];
                        final Order order = item['order'] as Order;
                        final bool isPaid = item['type'] == 'paid';
                        return _buildOrderTile(order, isPaid);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }

  Widget _buildOrderTile(Order order, bool isPaid) {
    final String tableNo = order.tableId?.toString() ?? '-';
    final bool isCash = order.isCashOrder;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: isCash
            ? Colors.orange.withValues(alpha: 0.1)
            : Colors.green.withValues(alpha: 0.1),
        child: Text(
          tableNo,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isCash ? Colors.orange : Colors.green,
            fontSize: 14,
          ),
        ),
      ),
      title: Text(
        order.customerName,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Total: ${CurrencyFormatter.format(order.totalPrice)}",
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
            Text(
              order.paymentMethodDisplay,
              style: TextStyle(
                fontSize: 11,
                color: isCash ? Colors.orange : Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      trailing: isCash
          ? InkWell(
              onTap: () => onLoadOrderToCart(order),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: Colors.orange,
                ),
              ),
            )
          : InkWell(
              onTap: () => onAcceptOrder(order),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline, size: 14, color: Colors.green),
                    SizedBox(width: 4),
                    Text(
                      "Terima",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
            ),
      onTap: isCash ? () => onLoadOrderToCart(order) : null,
    );
  }
}
