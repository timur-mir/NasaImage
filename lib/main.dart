import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:website1/models/nasaimage.dart';
import 'package:flutter/cupertino.dart';
import 'package:website1/utils/cacheservice.dart';

import 'models/network/parser.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Одностраничный сайт',
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final scrollKey = GlobalKey(); 
  void toast() {
    Fluttertoast.showToast(
      msg: "Идёт обновление",
      toastLength: Toast.LENGTH_LONG,
         gravity: ToastGravity.CENTER,
           timeInSecForIosWeb: 1,
           backgroundColor: Colors.deepPurple,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  NasaImage? content3;
  bool isLoading = false; 
  String? errorMessage; 
  final String apiKey = '******';

  final cacheService = CacheService();
  NasaImage? cachedData;

  Future<void> fetchNasaImage() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });


    try {
          cachedData = await cacheService.getCachedNasaData();
      if (cachedData != null) {
        setState(() {
          content3 = cachedData;
          errorMessage = 'Данные из кэша (обновлено: ${cachedData?.date})';
        });
      }

     
      final uri = Uri.parse(
        'https://api.nasa.gov/planetary/apod?api_key=$apiKey',
      );

        final response = await http
          .get(uri)
          .timeout(
        Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Превышено время ожидания'),
      );
  
      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          throw Exception('Пустой ответ от сервера');
        }

          final newContent = await compute(parseNasaData, response.body);

          await cacheService.saveNasaData(newContent);

        if (mounted) {
          setState(() {
            content3 = newContent;
            isLoading = false;
            errorMessage = null;
          });
        }
      } else if (response.statusCode == 504) {
          if (cachedData != null) {
          setState(() {
            isLoading = false;
            errorMessage = 'Сервер NASA перегружен. Показаны данные из кэша.';
          });
        } else {
          throw Exception('Сервер NASA перегружен. Попробуйте позже.');
        }
      } else {
        throw Exception(
          'HTTP ${response.statusCode}: ${response.reasonPhrase ?? 'Неизвестная ошибка'}',
        );
      }
    } on TimeoutException catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = cachedData != null
              ? 'Таймаут. Показаны данные из кэша.'
              : e.toString();
        });
        Fluttertoast.showToast(msg: 'Таймаут запроса');
      }
    } on SocketException catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = cachedData != null
              ? 'Нет интернета. Показаны данные из кэша.'
              : 'Нет подключения к интернету';
        });
        Fluttertoast.showToast(msg: 'Нет интернета');
      }
    } catch (e, stack) {
      if (mounted) {
        print('Ошибка загрузки: $e\n$stack');
        setState(() {
          isLoading = false;
          errorMessage = e.toString();
        });
        Fluttertoast.showToast(msg: e.toString());
      }
    }
  }
  final testImage = NasaImage(
    date: '2024-01-01',
    explanation: 'Это тестовое изображение для проверки кэша.',
    mediaType: 'image',
    title: 'Тестовая картинка',
    url: 'https://api.nasa.gov/assets/img/general/apod.jpg',
  );
  Future<void> _testFullCacheFlow() async {
    final cacheService = CacheService();
    await cacheService.saveNasaData(testImage);
    print('✅ Тестовые данные сохранены');

    final cachedData = await cacheService.getCachedNasaData();
    if (cachedData == null) {
      print('❌ Кэш не найден!');
      return;
    }

    print('✅ Кэш успешно прочитан:');
    print('- Дата: ${cachedData.date}');
    print('- Заголовок: ${cachedData.title}');

    setState(() {
      content3 = cachedData;
      isLoading = false;
      errorMessage = 'Данные загружены из теста кэша';
    });
  }

  @override
  void initState() {
    super.initState();
   fetchNasaImage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Фото дня NASA'),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.home),
            onPressed: () {
              Scrollable.ensureVisible(
                scrollKey.currentContext!,
                duration: Duration(milliseconds: 500),
                curve: Curves.easeInOut,
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : content3 == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Не удалось загрузить данные'),
                  Text(
                    errorMessage ?? 'Проверьте интернет или попробуйте позже',
                    style: TextStyle(color: Colors.white),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: fetchNasaImage,
                    child: Text('Повторить'),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  Text(
                    key: scrollKey, 
                    content3!.title,
                    style: TextStyle(fontSize: 28, color: Colors.cyanAccent),
                  ),
                  Container(
                    padding: EdgeInsets.all(16),
                    color: Colors.white12,
                    child: Center(
                      child: SelectableText(
                        content3!.explanation,
                        style: TextStyle(fontSize: 18, color: Colors.white),
                        contextMenuBuilder: (context, editableTextState) {
                          return AdaptiveTextSelectionToolbar.buttonItems(
                            anchors: editableTextState.contextMenuAnchors,
                            buttonItems:
                                editableTextState.contextMenuButtonItems,
                          );
                        },
                      ),
                    ),
                  ),
                  content3!.url.isNotEmpty
                      ? Image.network(content3!.url)
                      : Text('Изображение не доступно'),
                  SizedBox(height: 12),
                  Text(
                    content3!.date,
                    style: TextStyle(fontSize: 14, color: Colors.white),
                  ),

                  ElevatedButton(
                    onPressed: () async {
                      await cacheService.clearCache();
                      setState(() {
                        content3 = null;
                        errorMessage = 'Кэш очищен';
                      });
                    },
                    child: Text('Очистить кэш'),
                  ),
                  SizedBox(height: 240),
                ],
              ),
            ),

      backgroundColor: Colors.teal,
    );
  }
}








