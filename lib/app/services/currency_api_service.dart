import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:test_app/app/models/cached_rate.dart';

class CurrencyAPIService {
  static const String _apiKey = String.fromEnvironment('EXCHANGE_API_KEY');
  static const String _cachedRateBoxName = 'cached_rates';
  static const String _cacheKey = 'latest_rates'; 

  Future<CachedRate?> _getRateData() async {
    final cacheBox = Hive.box<CachedRate>(_cachedRateBoxName);
    final cachedData = cacheBox.get(_cacheKey);

    if (cachedData != null) {
      final difference = DateTime.now().difference(cachedData.lastFetched);
      if (difference.inHours < 24) { 
        return cachedData;
      }
    }

    if (_apiKey.isEmpty) return null;
    
    final url = Uri.parse('https://v6.exchangerate-api.com/v6/$_apiKey/latest/USD');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == 'success') {
          final rates = Map<String, double>.from(data['conversion_rates'].map((k, v) => MapEntry(k, v.toDouble())));
          final newCacheData = CachedRate(
            baseCode: data['base_code'],
            conversionRates: rates,
            lastFetched: DateTime.now(),
          );
          await cacheBox.put(_cacheKey, newCacheData); 
          return newCacheData;
        }
      }
    } catch (e) {
      print("Currency API Error: $e");
    }
    return cachedData;
  }

  Future<double?> getExchangeRate(String from, String to) async {
    final rateData = await _getRateData();
    if (rateData == null) return null; 
    final rates = rateData.conversionRates;
    if (!rates.containsKey(from) || !rates.containsKey(to)) {
      return null;
    }
    final rateFromBase = rates[from]!;
    final rateToBase = rates[to]!;
    return rateToBase / rateFromBase;
  }
}