import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sistem_pos/features/home/providers/product_provider.dart';
import 'package:sistem_pos/features/cart_checkout/providers/cart_provider.dart';
import 'package:sistem_pos/features/auth/providers/auth_provider.dart';
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

    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: itemWidth / itemHeight,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      ),
              itemCount: productProvider.products.length,
              itemBuilder: (context, index) {
                final p = productProvider.products[index];
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
