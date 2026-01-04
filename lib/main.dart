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
  final scrollKey = GlobalKey(); // Ключ для прокрутки к разделу
  void toast() {
    Fluttertoast.showToast(
      msg: "Идёт обновление",
      toastLength: Toast.LENGTH_LONG,
      // длительность: SHORT или LONG
      gravity: ToastGravity.CENTER,
      // позиция: TOP, CENTER, BOTTOM
      timeInSecForIosWeb: 1,
      // для iOS/Web
      backgroundColor: Colors.deepPurple,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  NasaImage? content3;
  bool isLoading = false; // Флаг загрузки
  String? errorMessage; // Новое поле
  final String apiKey = 'Pr54PgeBMvnTRXHELBigPUY95Af1eOlzHBmWyOQh';

  // Uri get uri =>
  //     Uri.parse('https://api.nasa.gov/planetary/apod?api_key=${apiKey}');
  final cacheService = CacheService();
  NasaImage? cachedData;

  Future<void> fetchNasaImage() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });


    try {
      // 1. Пытаемся получить данные из кэша
      cachedData = await cacheService.getCachedNasaData();
      if (cachedData != null) {
        setState(() {
          content3 = cachedData;
          errorMessage = 'Данные из кэша (обновлено: ${cachedData?.date})';
        });
      }

      // 2. Формируем URL
      final uri = Uri.parse(
        'https://api.nasa.gov/planetary/apod?api_key=$apiKey',
      );

      // 3. Делаем запрос с таймаутом
      final response = await http
          .get(uri)
          .timeout(
        Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Превышено время ожидания'),
      );
      // 4. Проверяем статус ответа
      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          throw Exception('Пустой ответ от сервера');
        }

        // 5. Обрабатываем JSON в изоляте
        final newContent = await compute(parseNasaData, response.body);

        // 6. Сохраняем в кэш
        await cacheService.saveNasaData(newContent);

        if (mounted) {
          setState(() {
            content3 = newContent;
            isLoading = false;
            errorMessage = null;
          });
        }
      } else if (response.statusCode == 504) {
        // Сервер перегружен, но у нас есть кэш
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
    // 1. Сохраняем тестовые данные
    final cacheService = CacheService();
    await cacheService.saveNasaData(testImage);
    print('✅ Тестовые данные сохранены');

    // 2. Читаем из кэша
    final cachedData = await cacheService.getCachedNasaData();
    if (cachedData == null) {
      print('❌ Кэш не найден!');
      return;
    }

    print('✅ Кэш успешно прочитан:');
    print('- Дата: ${cachedData.date}');
    print('- Заголовок: ${cachedData.title}');

    // 3. Отображаем в UI (если нужно)
    setState(() {
      content3 = cachedData;
      isLoading = false;
      errorMessage = 'Данные загружены из теста кэша';
    });
  }

  @override
  void initState() {
    super.initState();
 //_testFullCacheFlow();
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
                    key: scrollKey, // Ключ для прокрутки
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
// floatingActionButton:
      backgroundColor: Colors.teal,
    );
  }
}








// floatingActionButton: FloatingActionButton(
//   backgroundColor: Colors.deepOrangeAccent,
//   foregroundColor: Colors.white,
//   onPressed: () =>
//   {
//
//     // ScaffoldMessenger.of(
//     //   context,
//     // ).showSnackBar(SnackBar(content: Text('Обновление страницы'))),
//     // MotionToast.success(
//     //   title: Text("Готово"),
//     //   description: Text("Операция выполнена"),
//     //   width: 300,
//     //   height: 65,
//     //   toastDuration: Duration(seconds: 3),
//     // ).show(context),
//     Fluttertoast.showToast(msg: "Перезагрузка"),
//     fetchNasaImage(),
//     // setState(() {items = ['Яблоко', 'Банан', 'Вишня','Груша'];})
//   },
//   tooltip: 'Upload',
//   child: const Icon(Icons.refresh_rounded),
// ),




//class NasaService {
  // final String apiKey = 'lVDfZy3V5O8nXfLboGeUZApmTgbZkfunn0iPEYjS';
  //
  // Future<NasaImage> fetchNasaInfo() async {
  // // Проверка API-ключа
  // if (apiKey.isEmpty) {
  // throw Exception('API-ключ не указан');
  // }
  //
  // try {
  //   final Uri uri = Uri.parse('https://api.nasa.gov/planetary/apod?api_key=$apiKey');
  //   final response = await http.get(uri).timeout(Duration(seconds: 80));
  // // Проверка статуса
  // if (response.statusCode != 200) {
  //   if (response.statusCode == 504) {
  //     throw Exception('Сервер NASA перегружен. Попробуйте позже.');
  //   }
  // throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase ?? 'Unknown error'}');
  // }
  // // Проверка тела ответа
  // if (response.body.isEmpty) {
  // throw Exception('Пустой ответ от сервера');
  // }
  // final data = jsonDecode(response.body) as Map<String, dynamic>;
  //
  //
  // return NasaImage(
  // date: data['date'] as String? ?? '',
  // explanation: data['explanation'] as String? ?? 'Нет описания',
  // media_type: data['media_type'] as String? ?? 'unknown',
  // title: data['title'] as String? ?? 'Без названия',
  // url: data['url'] as String? ?? '',
  // );
  // } on TimeoutException {
  // throw Exception('Запрос превысил время ожидания (80 сек)');
  // } on SocketException {
  // throw Exception('Нет подключения к интернету');
  // } catch (e) {
  // throw Exception('Неизвестная ошибка: $e');
  // }
  // }
//}










// fetchNasaImage() async {
//   setState(() {
//     isLoading = true;
//     errorMessage = null;
//   });
//
//   try {
//     // 1. Формируем корректный URL
//     final uri = Uri.parse(
//         'https://api.nasa.gov/planetary/apod?api_key=$apiKey');
//
//     // 2. Делаем запрос с таймаутом (без лишних задержек!)
//     final response = await http.get(uri).timeout(Duration(seconds: 100));
//
//     // 3. Проверяем статус ДО обработки тела
//     if (response.statusCode != 200) {
//       if (response.statusCode == 504) {
//         throw Exception('Сервер NASA перегружен. Попробуйте позже.');
//       }
//       throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase ?? 'Unknown error'}');
//     }
//
//     // 4. Проверяем, что тело не пустое
//     if (response.body.isEmpty) {
//       throw Exception('Пустой ответ от сервера');
//     }
//
//     // 5. Обрабатываем JSON в изоляте
//     final newContent = await compute(parseNasaData, response.body);
//
//     if (mounted) {
//       setState(() {
//         content3 = newContent;
//         isLoading = false;
//       });
//     }
//   } on SocketException {
//     // Ошибка сети (нет интернета, DNS и т.п.)
//     if (mounted) {
//       setState(() {
//         isLoading = false;
//         errorMessage = 'Нет подключения к интернету';
//       });
//       Fluttertoast.showToast(msg: 'Нет интернета');
//     }
//   } on TimeoutException {
//     // Превышен таймаут запроса
//     if (mounted) {
//       setState(() {
//         isLoading = false;
//         errorMessage = 'Запрос превысил время ожидания (100 сек)';
//       });
//       Fluttertoast.showToast(msg: 'Таймаут');
//     }
//   } catch (e) {
//     // Все остальные ошибки
//     if (mounted) {
//       print('Ошибка загрузки: $e');
//       setState(() {
//         isLoading = false;
//         errorMessage = e.toString();
//       });
//       Fluttertoast.showToast(msg: e.toString());
//     }
//   }
// }

// fetchNasaImage() async {
//   setState(() => isLoading = true);
//
//   try {
//     final newContent = await nasaService.fetchNasaInfo();
//     if (mounted) {
//       setState(() {
//         content3 = newContent;
//         isLoading = false;
//         errorMessage = null; // Сбрасываем ошибку при новом запросе
//       });
//     }
//   } catch (e) {
//     if (mounted) {
//       print('Ошибка загрузки: $e'); // Важно: видим ошибку в консоли
//       setState(() {
//         isLoading = false; // Сбрасываем флаг
//         errorMessage = e.toString(); // Сохраняем сообщение об ошибке
//         // content3 остаётся null → сработает блок с ошибкой в UI
//       });
//       Fluttertoast.showToast(msg: 'Ошибка: $e'); // Оповещение пользователя
//     }
//   }
// }
// VideoPlayerWidget(  key: const Key('main-video-player'),videoUrl: content3.url,),

// Container(
//   padding: EdgeInsets.all(16),
//   height: 260,
//   color: Colors.green,
//   child: Center(
//     child: Text(
//       'А в городе ${content2.city}'
//       ''
//       ' сейчас ${content2.description.toLowerCase()}'
//       ' и температура равна ${content2.temp}°C',
//       style: TextStyle(fontSize: 28, color: Colors.white),
//     ),
//   ),
// ),
// Container(
//   padding: EdgeInsets.all(16),
//   height: 200,
//   color: Colors.amberAccent,
//   child: Center(
//     child: Text(
//       'Nasa ${content3.media_type}       Date ${content3.date}    Url ${content3.url}',
//       style: TextStyle(fontSize: 20, color: Colors.brown),
//     ),
//   ),
// ),
// Container(
//   padding: EdgeInsets.all(16),
//   color: Colors.red,
//   child: Center(
//     child: Text(
//       content1,
//       style: TextStyle(fontSize: 20, color: Colors.white),
//     ),
//   ),
// ),
// Container(
//   height: 400,
//   padding: EdgeInsets.all(16),
//
//     decoration: BoxDecoration(
//       color: Colors.white12,
//       borderRadius: BorderRadius.circular(20),
//     ),
//  child:
//   ListView.builder(
//     itemCount: items.length,
//     itemBuilder: (context, index) {
//       return ListTile(
//         title: Text(items[index]),
//         trailing: IconButton(
//           icon: Icon(Icons.delete),
//           onPressed: () {
//             setState(() {
//               items.removeAt(index); // Удаляем элемент
//             });
//           },
//         ),
//       );
//     },
// ),
// ),
// class VideoPlayerWidget extends StatefulWidget {
//   final String videoUrl;
//
//   const VideoPlayerWidget({Key? key, required this.videoUrl}) : super(key: key);
//
//   @override
//   State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
// }
//
// class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
//   late VideoPlayerController _controller;
//
//
//   @override
//   void initState() {
//     super.initState();
//     _controller = VideoPlayerController.network(widget.videoUrl)
//       ..initialize().then((_) {
//         // Убедитесь, что контроллер готов, прежде чем вызывать play()
//         _controller.play();
//         setState(() {});
//       });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return AspectRatio(
//       aspectRatio: _controller.value.aspectRatio,
//       child: VideoPlayer(_controller),
//     );
//   }
//
//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }
// }
//

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   // This widget is the root of your application.
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Flutter Demo',
//       theme: ThemeData(
//         // This is the theme of your application.
//         //
//         // TRY THIS: Try running your application with "flutter run". You'll see
//         // the application has a purple toolbar. Then, without quitting the app,
//         // try changing the seedColor in the colorScheme below to Colors.green
//         // and then invoke "hot reload" (save your changes or press the "hot
//         // reload" button in a Flutter-supported IDE, or press "r" if you used
//         // the command line to start the app).
//         //
//         // Notice that the counter didn't reset back to zero; the application
//         // state is not lost during the reload. To reset the state, use hot
//         // restart instead.
//         //
//         // This works for code too, not just values: Most code changes can be
//         // tested with just a hot reload.
//         colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
//       ),
//       home: const MyHomePage(title: 'Flutter Demo Home Page'),
//     );
//   }
// }
//
// class MyHomePage extends StatefulWidget {
//   const MyHomePage({super.key, required this.title});
//
//   // This widget is the home page of your application. It is stateful, meaning
//   // that it has a State object (defined below) that contains fields that affect
//   // how it looks.
//
//   // This class is the configuration for the state. It holds the values (in this
//   // case the title) provided by the parent (in this case the App widget) and
//   // used by the build method of the State. Fields in a Widget subclass are
//   // always marked "final".
//
//   final String title;
//
//   @override
//   State<MyHomePage> createState() => _MyHomePageState();
// }
//
// class _MyHomePageState extends State<MyHomePage> {
//   int _counter = 0;
//
//   void _incrementCounter() {
//     setState(() {
//       // This call to setState tells the Flutter framework that something has
//       // changed in this State, which causes it to rerun the build method below
//       // so that the display can reflect the updated values. If we changed
//       // _counter without calling setState(), then the build method would not be
//       // called again, and so nothing would appear to happen.
//       _counter++;
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     // This method is rerun every time setState is called, for instance as done
//     // by the _incrementCounter method above.
//     //
//     // The Flutter framework has been optimized to make rerunning build methods
//     // fast, so that you can just rebuild anything that needs updating rather
//     // than having to individually change instances of widgets.
//     return Scaffold(
//       appBar: AppBar(
//         // TRY THIS: Try changing the color here to a specific color (to
//         // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
//         // change color while the other colors stay the same.
//         backgroundColor: Theme.of(context).colorScheme.inversePrimary,
//         // Here we take the value from the MyHomePage object that was created by
//         // the App.build method, and use it to set our appbar title.
//         title: Text(widget.title),
//       ),
//       body: Center(
//         // Center is a layout widget. It takes a single child and positions it
//         // in the middle of the parent.
//         child: Column(
//           // Column is also a layout widget. It takes a list of children and
//           // arranges them vertically. By default, it sizes itself to fit its
//           // children horizontally, and tries to be as tall as its parent.
//           //
//           // Column has various properties to control how it sizes itself and
//           // how it positions its children. Here we use mainAxisAlignment to
//           // center the children vertically; the main axis here is the vertical
//           // axis because Columns are vertical (the cross axis would be
//           // horizontal).
//           //
//           // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
//           // action in the IDE, or press "p" in the console), to see the
//           // wireframe for each widget.
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: <Widget>[
//             const Text('You have pushed the button this many times:'),
//             Text(
//               '$_counter',
//               style: Theme.of(context).textTheme.headlineMedium,
//             ),
//           ],
//         ),
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: _incrementCounter,
//         tooltip: 'Increment',
//         child: const Icon(Icons.add),
//       ), // This trailing comma makes auto-formatting nicer for build methods.
//     );
//   }
// }
