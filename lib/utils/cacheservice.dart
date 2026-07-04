
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/nasaimage.dart';

class CacheService {
  static const String _cacheKey = 'nasa_apod_cache';

  Future<void> saveNasaData(NasaImage data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(data.toJson()));
  }

  Future<NasaImage?> getCachedNasaData() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_cacheKey);
    if (jsonString == null) return null;

    final Map<String, dynamic> json = jsonDecode(jsonString);
    return NasaImage.fromJson(json);
  }

  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
  }
}
