import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sistem_pos/features/home/providers/product_provider.dart';
import 'package:sistem_pos/features/cart_checkout/providers/cart_provider.dart';
import 'package:sistem_pos/features/home/widgets/product_card.dart';
import 'package:sistem_pos/features/home/providers/home_controller.dart';

class ProductGrid extends StatelessWidget {
  const ProductGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer3<ProductProvider, CartProvider, HomeController>(
      builder: (context, productProvider, cartProvider, homeController, child) {
        if (productProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (productProvider.products.isEmpty) {
          return const Center(child: Text('Tidak ada produk ditemukan'));
        }

        return LayoutBuilder(
  builder: (context, constraints) {
    double spacing = 18.0;
    double itemHeight = (constraints.maxHeight - (spacing * 2)) / 3;
    double itemWidth = (constraints.maxWidth - (spacing * 3)) / 4;

    final sortedProducts = List.of(productProvider.products);
    sortedProducts.sort((a, b) {
      final aIsBest = productProvider.bestsellerProductIds.contains(a.id);
      final bIsBest = productProvider.bestsellerProductIds.contains(b.id);
      if (aIsBest && !bIsBest) return -1;
      if (!aIsBest && bIsBest) return 1;
      return 0;
    });

    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: itemWidth / itemHeight,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      ),
              itemCount: sortedProducts.length,
              itemBuilder: (context, index) {
                final p = sortedProducts[index];
                return ProductCard(
                  product: p,
                  bestsellerProductIds: productProvider.bestsellerProductIds,
                  onAdd: () {
                    homeController.hideAllPanels();
                    cartProvider.addToCart(p);
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
