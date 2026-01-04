import 'dart:core';

class NasaImage {
  final String date;
  final String explanation;
  final String mediaType;
  final String title;
  final String url;

  NasaImage({
    required this.date,
    required this.explanation,
    required this.mediaType,
    required this.title,
    required this.url,
  });

  /// Преобразует объект в JSON‑карту (для сохранения в кэш)
  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'explanation': explanation,
      'mediaType': mediaType,
      'title': title,
      'url': url,
    };
  }

  /// Создаёт объект из JSON‑карты (для восстановления из кэша)
  factory NasaImage.fromJson(Map<String, dynamic> json) {
    // Валидация и обработка возможных null
    return NasaImage(
      date: json['date']?.toString() ?? 'Unknown date',
      explanation: json['explanation']?.toString() ?? 'No explanation available',
      mediaType: json['mediaType']?.toString() ?? 'unknown',
      title: json['title']?.toString() ?? 'Untitled',
      url: json['url']?.toString() ?? '',
    );
  }

  /// Опционально: метод для отладки (вывод в консоль)
  @override
  String toString() {
    return 'NasaImage(date: $date, title: $title, url: $url)';
  }
}