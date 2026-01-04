
import 'dart:convert';

import '../nasaimage.dart';

Future<NasaImage> parseNasaData(String jsonString) async {
  final data = jsonDecode(jsonString) as Map<String, dynamic>;
  return NasaImage(   date: data['date'] as String? ?? '',
    explanation: data['explanation'] as String? ?? 'Нет описания',
    mediaType: data['mediaType'] as String? ?? 'unknown',
    title: data['title'] as String? ?? 'Без названия',
    url: data['url'] as String? ?? '',
  );
}