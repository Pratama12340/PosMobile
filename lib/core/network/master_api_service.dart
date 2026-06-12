import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:sistem_pos/core/models/discount_model.dart';
import 'package:sistem_pos/core/network/api_client.dart';

class MasterApiService {
  static Future<List<Discount>> getDiscounts() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiClient.baseUrl}/discounts'),
        headers: await ApiClient.getHeaders(),
      );
      if (response.statusCode == 200) {
        final dynamic res = jsonDecode(response.body);
        List<dynamic> data = [];
        if (res is List) {
          data = res;
        } else if (res is Map) {
          if (res['data'] is List) {
            data = res['data'];
          } else if (res['data'] is Map && res['data']['data'] is List) {
            data = res['data']['data'];
          } else if (res['discounts'] is List) {
            data = res['discounts'];
          }
        }
        return data.map((json) => Discount.fromJson(json)).toList();
      }
    } catch (e) {
// debugPrint("💥 [API ERROR] getDiscounts: $e");
    }
    return [];
  }

  static Future<List<dynamic>> getTaxes() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiClient.baseUrl}/taxes'),
        headers: await ApiClient.getHeaders(),
      );
      if (response.statusCode == 200) {
        final dynamic result = jsonDecode(response.body);
        if (result is List) return result;
        if (result is Map) {
          if (result['data'] is List) return result['data'];
          if (result['data'] != null && result['data']['data'] is List) {
            return result['data']['data'];
          }
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<dynamic>> getReports() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiClient.baseUrl}/reports'),
        headers: await ApiClient.getHeaders(),
      );
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['data'] is List ? result['data'] : result['data']['data'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<dynamic>> getTables() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiClient.baseUrl}/tables'),
        headers: await ApiClient.getHeaders(),
      );
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['data'] is List ? result['data'] : result['data']['data'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
