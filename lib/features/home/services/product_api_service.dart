import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sistem_pos/features/home/models/product_model.dart';
import 'package:sistem_pos/core/services/storage_service.dart';
import 'package:sistem_pos/core/network/api_client.dart';

class ProductApiService {
  static Future<List<Product>> getProducts() async {
    try {
      final int outletId = await StorageService.getOutletId() ?? 1;

      final response = await ApiClient.get(
        Uri.parse('${ApiClient.baseUrl}/products?outlet_id=$outletId&per_page=100'),
      );
      final result = jsonDecode(response.body);
      if (result['data'] != null) {
        List<dynamic> productList = (result['data'] is List)
            ? result['data']
            : result['data']['data'] ?? [];
        return productList.map((json) => Product.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) print("💥 [API ERROR] getProducts: $e");
      return [];
    }
  }

  static Future<List<dynamic>> getCategories() async {
    try {
      final int outletId = await StorageService.getOutletId() ?? 1;

      final response = await ApiClient.get(
        Uri.parse('${ApiClient.baseUrl}/categories?outlet_id=$outletId&per_page=100'),
      );
      final result = jsonDecode(response.body);
      if (result['data'] != null) {
        if (result['data'] is List) return result['data'];
        if (result['data']['data'] is List) return result['data']['data'];
      }
      return [];
    } catch (e) {
      if (kDebugMode) print("💥 [API ERROR] getCategories: $e");
      return [];
    }
  }

  static Future<List<String>> getTopProducts() async {
    try {
      final int outletId = await StorageService.getOutletId() ?? 1;

      final response = await ApiClient.get(
        Uri.parse('${ApiClient.baseUrl}/public/top-products?outlet_id=$outletId'),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        List<dynamic> rawData = [];
        if (result['top_products'] != null) {
          rawData = result['top_products'];
        } else if (result['data'] != null) {
          rawData = result['data'] is List ? result['data'] : (result['data']['data'] ?? []);
        } else if (result is List) {
          rawData = result;
        }

        return rawData
            .map((item) => item['name']?.toString().toLowerCase().trim() ?? '')
            .where((name) => name.isNotEmpty)
            .toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) print("💥 [API ERROR] getTopProducts: $e");
      return [];
    }
  }

  static Future<List<dynamic>> getStations() async {
    try {
      final response = await ApiClient.get(
        Uri.parse('${ApiClient.baseUrl}/stations'),
      );
      final result = jsonDecode(response.body);
      return response.statusCode == 200
          ? (result['data'] is List ? result['data'] : result['data']['data'] ?? [])
          : [];
    } catch (e) {
      if (kDebugMode) print("💥 [API ERROR] getStations: $e");
      return [];
    }
  }
}
