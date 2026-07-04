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

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'explanation': explanation,
      'mediaType': mediaType,
      'title': title,
      'url': url,
    };
  }


  factory NasaImage.fromJson(Map<String, dynamic> json) {

    return NasaImage(
      date: json['date']?.toString() ?? 'Unknown date',
      explanation: json['explanation']?.toString() ?? 'No explanation available',
      mediaType: json['mediaType']?.toString() ?? 'unknown',
      title: json['title']?.toString() ?? 'Untitled',
      url: json['url']?.toString() ?? '',
    );
  }

 
  @override
  String toString() {
    return 'NasaImage(date: $date, title: $title, url: $url)';
  }
}
