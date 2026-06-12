import 'package:flutter/material.dart';
import 'package:sistem_pos/features/home/models/product_model.dart';
import 'package:sistem_pos/core/models/discount_model.dart';
import 'package:sistem_pos/features/home/services/product_api_service.dart';
import 'package:sistem_pos/core/network/master_api_service.dart';

class ProductProvider extends ChangeNotifier {
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  List<dynamic> _categories = [];
  Set<int> _bestsellerProductIds = {};

  bool _isLoading = true;
  String _selectedCategory = "All Menu";
  String _searchQuery = "";

  List<Product> get products => _filteredProducts;
  List<dynamic> get categories => _categories;
  Set<int> get bestsellerProductIds => _bestsellerProductIds;
  bool get isLoading => _isLoading;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;

  Future<void> fetchData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        ProductApiService.getCategories().catchError((e) => []),
        ProductApiService.getProducts().catchError((e) => <Product>[]),
        MasterApiService.getDiscounts().catchError((e) => <Discount>[]),
        ProductApiService.getTopProducts().catchError((e) => <String>[]),
        ProductApiService.getStations().catchError((e) => <dynamic>[]),
      ]);

      _categories = results[0];
      final List<Product> productsData = results[1] as List<Product>;
      final List<Discount> discountsData = results[2] as List<Discount>;
      final List<String> topProductNames = results[3] as List<String>;
      final List<dynamic> stationsData = results[4];

      final Map<String, String> stationMap = {};
      for (var s in stationsData) {
        if (s is Map) {
          final id = s['id']?.toString();
          final name = s['name']?.toString();
          if (id != null && name != null) {
            stationMap[id] = name;
          }
        }
      }

      for (var product in productsData) {
        product.stationName = stationMap[product.stationId] ?? '';
      }

      // Terapkan diskon ke produk
      for (var product in productsData) {
        final productDiscount = discountsData
            .where((d) => d.scope == 'products' && d.productIds.contains(product.id))
            .toList();

        final categoryDiscount = discountsData
            .where((d) => d.scope == 'categories' && product.categoryId != null && d.categoryIds.contains(product.categoryId))
            .toList();

        product.discount = productDiscount.isNotEmpty
            ? productDiscount.first
            : (categoryDiscount.isNotEmpty ? categoryDiscount.first : null);
      }

      // Bestseller
      final Set<int> bestsellerIds = {};
      for (var product in productsData) {
        if (topProductNames.contains(product.name.toLowerCase().trim())) {
          bestsellerIds.add(product.id);
        }
      }

      _allProducts = productsData;
      _bestsellerProductIds = bestsellerIds;
      _isLoading = false;
      
      _applyFilters();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setCategory(String category) {
    _selectedCategory = category;
    _applyFilters();
  }

  void setSearchQuery(String query) {
    _searchQuery = query.toLowerCase();
    _applyFilters();
  }

  void _applyFilters() {
    _filteredProducts = _allProducts.where((p) {
      bool matchCategory = _selectedCategory == "All Menu" ||
          p.category.toLowerCase().contains(_selectedCategory.toLowerCase());
      bool matchQuery = _searchQuery.isEmpty || p.name.toLowerCase().contains(_searchQuery);
      return matchCategory && matchQuery;
    }).toList();

    _filteredProducts.sort((a, b) => (a.stock <= 0 && b.stock > 0)
        ? 1
        : (a.stock > 0 && b.stock <= 0)
            ? -1
            : 0);

    notifyListeners();
  }
}
