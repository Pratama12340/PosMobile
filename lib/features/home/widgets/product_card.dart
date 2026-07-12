import 'package:flutter/material.dart';
import 'package:sistem_pos/features/home/models/product_model.dart';
import 'package:sistem_pos/core/constants/style.dart';
import 'package:sistem_pos/core/utils/currency_formatter.dart';
import 'package:sistem_pos/core/utils/string_utils.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final Set<int> bestsellerProductIds;
  final VoidCallback onAdd;

  const ProductCard({
    super.key,
    required this.product,
    required this.bestsellerProductIds,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    bool isOutOfStock = product.stock <= 0;
    bool isBestseller = bestsellerProductIds.contains(product.id) || product.isBestseller == true;
    bool isDiskon = product.discount != null && product.price >= product.discount!.minPurchase;

    double priceAfterDiscount = product.discountedPrice;

    String imageUrl = product.image.trim();
    if (imageUrl.isNotEmpty && !imageUrl.startsWith('http')) {
      // imageUrl = "http://103.197.190.23:9010/storage/${imageUrl.startsWith('/') ? imageUrl.substring(1) : imageUrl}";
      imageUrl = "https://api.etres.my.id/storage/${imageUrl.startsWith('/') ? imageUrl.substring(1) : imageUrl}";
    }

    Widget imagePlaceholder = Container(
      color: const Color(0xFFB0B0B0),
      alignment: Alignment.center,
      child: Text(
        StringUtils.getInitials(product.name),
        style: const TextStyle(
          fontSize: 100,
          fontWeight: FontWeight.bold,
          color: Color(0xFF9E9E9E),
        ),
      ),
    );

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: isOutOfStock ? null : onAdd,
        borderRadius: BorderRadius.circular(20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned.fill(
                child: imageUrl.isEmpty
                    ? imagePlaceholder
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => imagePlaceholder,
                      ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.8),
                      ],
                      stops: const [0.4, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isBestseller)
                      Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFFD32F2F),
                          borderRadius: BorderRadius.only(
                            bottomRight: Radius.circular(15),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: const Text(
                          "BESTSELLER",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    if (isBestseller && isDiskon) const SizedBox(height: 2),
                    if (isDiskon)
                      Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFF24707A),
                          borderRadius: BorderRadius.only(
                            bottomRight: Radius.circular(15),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: const Text(
                          "DISKON",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOutOfStock ? Colors.red : AppStyle.primaryBlue,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(15),
                    ),
                  ),
                  child: Text(
                    isOutOfStock ? "HABIS" : "STOK: ${product.stock}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 15,
                left: 15,
                right: 15,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            product.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (isDiskon) ...[
                            Text(
                              CurrencyFormatter.format(product.price.toDouble()),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: Colors.redAccent,
                                decorationThickness: 2.0,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              CurrencyFormatter.format(priceAfterDiscount),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ] else
                            Text(
                              CurrencyFormatter.format(product.price.toDouble()),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add,
                        color: isOutOfStock ? Colors.grey : AppStyle.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
