import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sistem_pos/core/constants/style.dart';
import 'package:sistem_pos/features/orders/models/order_model.dart';
import 'package:sistem_pos/features/cart_checkout/widgets/cart_panel.dart';
import 'package:sistem_pos/features/cart_checkout/widgets/draft_panel.dart';
import 'package:sistem_pos/core/utils/currency_formatter.dart';
import 'package:sistem_pos/features/home/providers/product_provider.dart';
import 'package:sistem_pos/features/cart_checkout/providers/cart_provider.dart';
import 'package:sistem_pos/features/orders/providers/order_provider.dart';
import 'package:sistem_pos/features/home/widgets/category_filter.dart';
import 'package:sistem_pos/features/orders/widgets/pending_order_panel.dart';
import 'package:sistem_pos/features/home/widgets/product_grid.dart';
import 'package:sistem_pos/features/home/providers/home_controller.dart';
import 'package:sistem_pos/features/printer/utils/print_helper.dart';
import 'package:sistem_pos/core/services/storage_service.dart';

class HomeScreen extends StatefulWidget {
  final TextEditingController searchController;
  final Function(bool)? onCartToggled;

  const HomeScreen({
    super.key,
    required this.searchController,
    this.onCartToggled,
  });

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_onSearchChanged);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().fetchData();
      context.read<OrderProvider>().fetchPendingOrders();
      context.read<OrderProvider>().fetchPaidOrders();
    });
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_onSearchChanged);
    super.dispose();
  }

  void _onSearchChanged() {
    context.read<ProductProvider>().setSearchQuery(widget.searchController.text);
  }

  Future<void> _acceptOrder(Order order) async {
    final orderProvider = context.read<OrderProvider>();
    final success = await orderProvider.acceptOrder(order.id);
    
    if (success) {
      if (!mounted) return;
      _printAcceptedOrder(order);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Text('Order berhasil di-accept!'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Gagal accept order.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _printAcceptedOrder(Order order) async {
    try {
      final outletName = await StorageService.getOutletName();
      final cashierName = await StorageService.getCashierName();

      final allProducts = context.read<ProductProvider>().products;

      final itemsForPrinting = PrintHelper.orderItemsToCartItems(
        order.items,
        filterVoided: false,
        allProducts: allProducts,
      );

      final transaction = PrintHelper.buildTransaction(
        orderId: order.invoiceNo,
        outletName: outletName,
        outletAddress: "-",
        cashierName: cashierName,
        customerName: order.customerName,
        tableNumber: order.tableNumber?.toString(),
        items: itemsForPrinting,
        taxBreakdown: List<Map<String, dynamic>>.from(order.taxBreakdown ?? []),
        discountAmount: order.discountAmount,
        totalPrice: order.totalPrice,
      );

      await PrintHelper.printToAllPrinters(
        transaction: transaction,
        skipCashier: true, // Jangan print struk kasir untuk pesanan QRIS POS QR
        onSuccess: (name) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("✓ $name berhasil mencetak struk."),
              backgroundColor: Colors.green,
            ),
          );
        },
        onError: (name, e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Gagal cetak ke $name: $e"),
              backgroundColor: Colors.red,
            ),
          );
        },
      );
    } catch (e) {
      debugPrint("Error printing accepted order: $e");
    }
  }

  Widget _buildDraftButton() {
    final draftsCount = context.watch<CartProvider>().drafts.length;
    final homeCtrl = context.read<HomeController>();
    return Badge(
      label: Text(
        '$draftsCount',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: Colors.redAccent,
      child: InkWell(
        onTap: () => homeCtrl.toggleDraftPanel(),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.shopping_cart_outlined,
            color: AppStyle.primaryBlue,
            size: 26,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final productProvider = context.watch<ProductProvider>();
    final cartProvider = context.watch<CartProvider>();
    final orderProvider = context.watch<OrderProvider>();
    final homeCtrl = context.watch<HomeController>();

    final int totalOrderBadge = orderProvider.pendingOrders.length;

    return MediaQuery(
      data: mediaQuery.copyWith(viewInsets: EdgeInsets.zero),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: AppStyle.bgLightBlue,
        body: productProvider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        homeCtrl.hideAllPanels();
                      },
                      behavior: HitTestBehavior.translucent,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: CategoryFilter(
                                    categories: productProvider.categories,
                                    selectedCategory: productProvider.selectedCategory,
                                    onCategorySelected: (val) {
                                      productProvider.setCategory(val);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 15),
                                if (cartProvider.drafts.isNotEmpty && !homeCtrl.isDraftPanelVisible)
                                  _buildDraftButton(),
                                if (totalOrderBadge > 0 &&
                                    !homeCtrl.isPendingPanelVisible &&
                                    !cartProvider.isPendingOrderLoaded) ...[
                                  const SizedBox(width: 15),
                                  Badge(
                                    label: Text(
                                      '$totalOrderBadge',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    backgroundColor: Colors.redAccent,
                                    child: InkWell(
                                      onTap: () => homeCtrl.togglePendingPanel(),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        width: 45,
                                        height: 45,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.05),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.receipt_long,
                                          color: Colors.orange,
                                          size: 26,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 15),
                            const Expanded(
                              child: ProductGrid(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // PANEL KANAN
                  if (homeCtrl.isPendingPanelVisible)
                    PendingOrderPanel(
                      pendingOrders: orderProvider.pendingOrders,
                      paidOrders: orderProvider.paidOrders,
                      isLoadingPendingOrders: orderProvider.isLoadingPendingOrders,
                      onClose: () => homeCtrl.togglePendingPanel(),
                      onAcceptOrder: _acceptOrder,
                      onLoadOrderToCart: (order) {
                        cartProvider.loadPendingOrderToCart(order, productProvider.products);
                        homeCtrl.hideAllPanels();
                        widget.onCartToggled?.call(true);
                      },
                    )
                  else if (homeCtrl.isDraftPanelVisible)
                    DraftPanel(
                      drafts: cartProvider.drafts,
                      onClose: () => homeCtrl.toggleDraftPanel(),
                      onRestore: (index) {
                        final draft = cartProvider.drafts[index];
                        cartProvider.loadFromDraft(draft);
                        homeCtrl.hideAllPanels();
                        widget.onCartToggled?.call(true);
                      },
                      onDelete: (index) {
                        cartProvider.removeDraft(index);
                      },
                    )
                  else
                    CartPanel(
                      cart: cartProvider.cart,
                      hasDiscountedItem: cartProvider.hasDiscountedItem,
                      originalTotalAmount: cartProvider.originalTotalAmount,
                      formatCurrency: CurrencyFormatter.format, 
                      initialCustomerName: cartProvider.currentCustomerName,
                      initialTableNumber: cartProvider.currentTableNumber,
                      initialTableId: cartProvider.currentTableId,
                      isPendingMode: cartProvider.isPendingOrderLoaded,
                      pendingOrderId: cartProvider.currentPendingOrderId,
                      pendingDiscountId: cartProvider.currentPendingDiscountId,
                      onIncrease: (id) => cartProvider.increaseQty(id),
                      onDecrease: (id) {
                        cartProvider.decreaseQty(id);
                        if (cartProvider.cart.isEmpty) widget.onCartToggled?.call(false);
                      },
                      onDelete: (id) {
                        cartProvider.removeProduct(id);
                        if (cartProvider.cart.isEmpty) widget.onCartToggled?.call(false);
                      },
                      onCheckoutSuccess: (res) {
                        cartProvider.clearCart();
                        orderProvider.fetchPendingOrders();
                        widget.onCartToggled?.call(false);
                      },
                      onSaveDraft: (name, table, id) {
                        cartProvider.saveToDraft(name, table, id);
                        widget.onCartToggled?.call(false);
                      },
                      onCancelPendingMode: () {
                        cartProvider.clearCart();
                        widget.onCartToggled?.call(false);
                      },
                    )
                ],
              ),
      ),
    );
  }
}
