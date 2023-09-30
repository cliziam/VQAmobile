// ignore_for_file: file_names

import 'dart:io';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:porcupine_flutter/porcupine_error.dart';
import 'package:porcupine_flutter/porcupine_manager.dart';
import 'package:porcupine_flutter/porcupine.dart';
import 'package:remove_bg/remove_bg.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'globals.dart' as globals;

class CropImage extends StatelessWidget {
  const CropImage({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return const CropImagePage(title: 'Image Cropper Demo');
  }
}

class CropImagePage extends StatefulWidget {
  final String title;

  const CropImagePage({
    super.key,
    required this.title,
  });

  @override
  // ignore: library_private_types_in_public_api
  _CropImagePageState createState() => _CropImagePageState();
}

class _CropImagePageState extends State<CropImagePage> {
  double linearProgress = 0.0;
  Uint8List? bytes;
  var isLoading = false;
  var isCropped = false;
  String API_REMOVEBG = dotenv.env['REMOVEBG']!;
  late PorcupineManager _porcupineManager;
  String accessKey_porc = dotenv.env['ACCESSKEY']!;

  @override
  void initState() {
    super.initState();

    globals.pathImage = null;
    globals.isFilledImage = false;
    _initialize();
  }

  _initialize() async {
    // create porcupine manager
    try {
      _porcupineManager = await PorcupineManager.fromBuiltInKeywords(
        accessKey_porc,
        [BuiltInKeyword.TERMINATOR],
        _wakeWordCallBack,
      );
      await _porcupineManager.start();
    } on PorcupineException catch (err) {
      // ignore: avoid_print
      print("Porcupine exception: $err.message");
    }
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool? firstTime = prefs.getBool('first_time');
    if (firstTime == null) {
      prefs.setBool('first_time', true);
      showInfoDialog(this.context, true);
    }
  }

  _wakeWordCallBack(int keywordIndex) async {
    if (keywordIndex == 0) {
      // ignore: avoid_print
      print('TERMINATOR word detected');
      //AudioPlayer().play(AssetSource('audio/letsgo.mp3'));
      removeBackground();
    }
  }

  Future<bool> _onWillPop() async {
    await _porcupineManager.stop();
    await _porcupineManager.delete();
    globals.pathImage = null;
    globals.isFilledImage = false;
    // ignore: use_build_context_synchronously
    Navigator.of(context).pop(true);
    return true;
  }

  void removeBackground() async {
    if (globals.pathImage != null && globals.isSegmented == false) {
      var data = await Remove().bg(
        globals.pathImage!,
        privateKey: API_REMOVEBG, // Your API key
        onUploadProgressCallback: (progressValue) {
          if (kDebugMode) {
            print(progressValue);
          }
          setState(() {
            isLoading = true;
            linearProgress = progressValue;
          });
        },
      );
      imageCache.clear();
      setState(() {
        isLoading = false;
      });
      //print(data);
      bytes = data;
      var tempDir = await getTemporaryDirectory();
      var tempPath = '${tempDir.path}/saved_image.png';
      File file = File(tempPath);

      var image = img.decodeImage(bytes!);
      //print(image);
      file = await file.writeAsBytes(img.encodePng(image!), flush: true);

      setState(() {
        globals.pathImage = file;
        globals.isSegmented = true;
      });

      Vibrate.feedback(FeedbackType.success);
    }
  }

  /*for the text-to-speech*/
  FlutterTts fluttertts = FlutterTts();

  void textToSpeech(String text) async {
    await fluttertts.setLanguage("en-US");
    await fluttertts.setVolume(1);
    await fluttertts.setSpeechRate(0.5);
    await fluttertts.setPitch(1);
    await fluttertts.speak(text);
  }

  showInfoDialog(BuildContext context, bool vocalReproduction) async {
    await _porcupineManager.stop();

    String contentDialog =
        "Hi, I am your Visual Question Answering assistant.\n"
        "If you wish to segment an image, simply say 'TERMINATOR,' and I will extract the object from the image.\n"
        "Tap on any border of the screen to close this message.";

    Widget okButton = TextButton(
        child: const Text("Ok"),
        onPressed: () {
          Navigator.of(context).pop(); // dismiss dialog
        });
    AlertDialog alert = AlertDialog(
      actionsAlignment: MainAxisAlignment.center,
      title: const Text("How to use the app"),
      content: Text(contentDialog),
      actions: [
        okButton,
      ],
    );

    // ignore: use_build_context_synchronously
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    ).then((value) {
      if (vocalReproduction) {
        fluttertts.stop();
      }
      _porcupineManager.start();
      Vibrate.feedback(FeedbackType.success);
    });

    if (vocalReproduction) {
      textToSpeech(contentDialog);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: _onWillPop,
        child: Scaffold(
          appBar: AppBar(
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.info_outline_rounded,
                  color: Colors.black,
                  size: 30,
                ),
                onPressed: () {
                  showInfoDialog(this.context, false);
                },
              ),
            ],
            title: const Text(
              'Editable photograph',
              style: TextStyle(color: Colors.black),
            ),
            backgroundColor: const Color.fromARGB(255, 217, 229, 222),
          ),
          body: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (kIsWeb)
                Padding(
                  padding: const EdgeInsets.all(kIsWeb ? 24.0 : 16.0),
                  child: Text(
                    widget.title,
                    style: Theme.of(context)
                        .textTheme
                        .displayMedium!
                        .copyWith(color: Theme.of(context).highlightColor),
                  ),
                ),
              Expanded(child: _body()),
            ],
          ),
        ));
  }

  Widget _body() {
    if (globals.pathImage != null) {
      return _imageCard();
    } else {
      return _uploaderCard();
    }
  }

  Widget _imageCard() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: kIsWeb ? 24.0 : 16.0),
            child: Card(
              elevation: 4.0,
              child: Padding(
                padding: const EdgeInsets.all(kIsWeb ? 24.0 : 16.0),
                child: _image(),
              ),
            ),
          ),
          _menu(),
        ],
      ),
    );
  }

  Widget _image() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    if (globals.pathImage != null) {
      var path = globals.pathImage!.path;
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 0.8 * screenWidth,
          maxHeight: 0.7 * screenHeight,
        ),
        child: kIsWeb ? Image.network(path) : Image.file(File(path)),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget _menu() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          mini: true,
          heroTag: 'check',
          onPressed: () {
            _check();
          },
          backgroundColor: const Color.fromARGB(255, 253, 235, 222),
          tooltip: 'Check',
          child: const Icon(Icons.check),
        ),
        FloatingActionButton(
          mini: true,
          heroTag: 'clear',
          onPressed: () {
            _clear();
          },
          backgroundColor: const Color.fromARGB(255, 253, 235, 222),
          tooltip: 'Delete',
          child: const Icon(Icons.delete),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 32.0),
          child: FloatingActionButton(
            mini: true,
            heroTag: 'crop',
            onPressed: () {
              _cropImage();
            },
            backgroundColor: const Color.fromARGB(255, 235, 186, 141),
            tooltip: 'Crop',
            child: const Icon(Icons.crop),
          ),
        ),
        if (globals.isSegmented == false)
          Padding(
              padding: const EdgeInsets.only(left: 32.0),
              child: FloatingActionButton(
                mini: true,
                heroTag: 'remove',
                onPressed: () => removeBackground(),
                backgroundColor: const Color.fromARGB(255, 235, 186, 141),
                tooltip: 'Remove Background',
                child: isLoading
                    ? const Center(
                        child: SizedBox(
                            width: 25,
                            height: 25,
                            child: CircularProgressIndicator(
                                color: Color.fromARGB(255, 217, 229, 222))))
                    : const Icon(Icons.auto_fix_high),
              ))
      ],
    );
  }

  Widget _uploaderCard() {
    return Center(
      child: Card(
        elevation: 4.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: SizedBox(
          width: 350.0,
          height: 300.0,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: DottedBorder(
                    radius: const Radius.circular(12.0),
                    borderType: BorderType.RRect,
                    dashPattern: const [8, 4],
                    color: Theme.of(context).highlightColor.withOpacity(0.4),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image,
                            color: Theme.of(context).highlightColor,
                            size: 80.0,
                          ),
                          const SizedBox(height: 24.0),
                          Text(
                            'Upload an image to start',
                            style: kIsWeb
                                ? Theme.of(context)
                                    .textTheme
                                    .headlineSmall!
                                    .copyWith(
                                        color: Theme.of(context).highlightColor)
                                : Theme.of(context)
                                    .textTheme
                                    .bodyMedium!
                                    .copyWith(
                                        color:
                                            Theme.of(context).highlightColor),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: ElevatedButton(
                  onPressed: () {
                    _uploadImage();
                  },
                  child: const Text('Upload'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cropImage() async {
    if (globals.pathImage != null) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: globals.pathImage!.path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 100,
        uiSettings: [
          AndroidUiSettings(
              toolbarTitle: 'Cropper',
              toolbarColor: const Color.fromARGB(255, 217, 229, 222),
              toolbarWidgetColor: Colors.black,
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: false),
          IOSUiSettings(
            title: 'Cropper',
          ),
          WebUiSettings(
            context: context,
            presentStyle: CropperPresentStyle.dialog,
            boundary: const CroppieBoundary(
              width: 520,
              height: 520,
            ),
            viewPort:
                const CroppieViewPort(width: 480, height: 480, type: 'circle'),
            enableExif: true,
            enableZoom: true,
            showZoomer: true,
          ),
        ],
      );
      if (croppedFile != null) {
        setState(() {
          globals.pathImage = File(croppedFile.path);
          globals.isFilledImage = true;
          isCropped = true;
        });
      }
    }
  }

  void _uploadImage() {
    ImagePicker().pickImage(source: ImageSource.gallery).then((image) {
      final imageTemporary = File(image!.path);
      setState(() {
        bytes = null;
        isCropped = false;
        globals.pathImage = imageTemporary;
        globals.isFilledImage = true;
        globals.isSegmented = false;
      });
    }).catchError((e) {
      // Handle any errors that occur during image picking.
      print("Failed to pick image: $e");
    });
  }

  void _clear() {
    setState(() {
      bytes = null;
      isCropped = false;
      globals.isSegmented = false;
      globals.pathImage = null;
      globals.isFilledImage = false;
    });
  }

  void _check() async {
    await _porcupineManager.stop();
    await _porcupineManager.delete();
    Navigator.pop(context);
  }
}
