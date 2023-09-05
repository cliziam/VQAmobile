import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:porcupine_flutter/porcupine.dart';
import 'package:replicate/replicate.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'CropImage.dart';
import 'api/speech_api.dart';
import 'package:porcupine_flutter/porcupine_manager.dart';
import 'package:porcupine_flutter/porcupine_error.dart';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart';
import 'globals.dart' as globals;

void main() async {
  await dotenv.load(fileName: ".env");
  Replicate.apiKey = dotenv.env['API_KEY']!;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    return MaterialApp(
      title: 'VQAsk',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            // ignore: use_full_hex_values_for_flutter_colors
            seedColor: const Color(0xD9E5DE),
            background: Colors.white),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'VQAsk Application'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool isListening = false;
  bool isLoading = false;
  bool isFilledQuestion = false;
  bool _isEmpty = false;
  bool _isShort = false;
  bool _isSwitched = false;

  // use this controller to get what the user typed
  final TextEditingController _textController = TextEditingController();
  String displayedAnswer = " ";
  String answer = "";
  var buttonAudioState = const Icon(Icons.volume_off);
  late PorcupineManager _porcupineManager;
  String accessKey = dotenv.env['ACCESSKEY']!;
  final FlutterTts tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _createPorcupineManager();
  }

  /*for the text-to-speech*/
  FlutterTts fluttertts = FlutterTts();

  void textToSpeech(String text) async {
    await fluttertts.setLanguage("en-US");
    await fluttertts.setVolume(10);
    await fluttertts.setSpeechRate(0.5);
    await fluttertts.setPitch(1);
    await fluttertts.speak(text);
  }

  Future getImage(ImageSource source, bool calledByWakeWord) async {
    try {
      final image = await ImagePicker().pickImage(source: source);
      if (calledByWakeWord) _porcupineManager.start();
      if (image == null) return;
      //final imageTemporary = File(image.path); // if we do not want to save the image on the device
      final imagePermanent = await saveFilePermanently(image.path);
      globals.pathImage = imagePermanent;
      setState(() {
        globals.pathImage = imagePermanent; //imageTemporary
        globals.isFilledImage = true;
      });
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print("Failed to pick image: $e");
    }
  }

  Future<File> saveFilePermanently(String imagePath) async {
    final directory = await getApplicationDocumentsDirectory();
    final name = basename(imagePath);
    final image = File('${directory.path}/$name');
    return File(imagePath).copy(image.path);
  }

  _createPorcupineManager() async {
    try {
      _porcupineManager = await PorcupineManager.fromBuiltInKeywords(
        accessKey,
        [
          BuiltInKeyword.PICOVOICE,
          BuiltInKeyword.PORCUPINE,
          BuiltInKeyword.BLUEBERRY
        ],
        _wakeWordCallBack,
      );
      _porcupineManager.start();
    } on PorcupineException catch (err) {
      // ignore: avoid_print
      print("Porcupine exception: $err.message");
    }
  }

  _wakeWordCallBack(int keywordIndex) async {
    if (keywordIndex <= 1) _porcupineManager.stop();
    if (keywordIndex == 0) {
      // ignore: avoid_print
      print('PICOVOICE word detected');
      //AudioPlayer().play(AssetSource('audio/letsgo.mp3'));
      toggleRecording();
    } else if (keywordIndex == 1) {
      // ignore: avoid_print
      print('PORCUPINE word detected');
      //toggleRecording();
      getImage(ImageSource.camera, true);
    } else if (keywordIndex == 2) {
      // ignore: avoid_print
      print("BLUEBERRY word detected");
      onButtonPress();
    }
  }

  Future<String> getAnswer(String question) async {
    //ByteData bytes = await rootBundle.load('assets/images/cat.jpg');
    //var buffer = bytes.buffer;
    //var encodedImg = base64.encode(Uint8List.view(buffer));
    List<int> fileInByte = globals.pathImage!.readAsBytesSync();
    String fileInBase64 = base64Encode(fileInByte);
    try {
      // ignore: unused_local_variable
      Prediction prediction = await Replicate.instance.predictions.create(
        version:
            "b96a2f33cc8e4b0aa23eacfce731b9c41a7d9466d9ed4e167375587b54db9423",
        input: {
          "prompt": question,
          "image": "data:image/jpg;base64,$fileInBase64"
        },
      );
    } catch (e) {
      // ignore: avoid_print
      print("Failed to create the prediction: $e");
    }
    await Future.delayed(const Duration(seconds: 7));
    PaginatedPredictions predictionsPageList =
        await Replicate.instance.predictions.list();

    Prediction prediction = await Replicate.instance.predictions.get(
      id: predictionsPageList.results.elementAt(0).id,
    );
    isLoading = false;
    return prediction.output;
  }

  void displayAnswer(answer) {
    setState(() {
      displayedAnswer = answer;
    });
  }

  Future toggleRecording() => SpeechApi.toggleRecording(
      onResult: (text) => setState(() {
            _textController.text = text;
          }),
      onListening: (isListening) {
        this.isListening = isListening;
        if (this.isListening == false) _porcupineManager.start();
      });

  Widget customButton({
    required String title,
    required IconData icon,
    required VoidCallback onClick,
    required context,
  }) {
    return Expanded(
      child: ElevatedButton(
          onPressed: onClick,
          child: Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10),
              ),
            ],
          )),
    );
  }

  void showAlertDialog(BuildContext context) {
    Widget okButton = TextButton(
      child: const Text("Ok"),
      onPressed: () {
        Navigator.of(context).pop(); // dismiss dialog
      },
    );
    AlertDialog alert = AlertDialog(
      title: const Text("Error!"),
      content: const Text("You have to upload an image and a "
          "question in order to proceed."),
      actions: [
        okButton,
      ],
    );
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }

  void setBooleans(bool isShort) {
    if (isShort) {
      _isShort = true;
      _isEmpty = false;
    } else {
      _isShort = false;
      _isEmpty = false;
    }
  }

  Future<dynamic> onButtonPress() async {
    final text = _textController.value.text;
    setState(() {
      isFilledQuestion = text.isNotEmpty;
    });
    if (globals.isFilledImage && isFilledQuestion && !_isShort && !_isEmpty) {
      textToSpeech('I am thinking...');
      setState(() {
        isLoading = true; //true
      });
      answer = await getAnswer(_textController.text);
      displayAnswer(answer);
    } else {
      showAlertDialog(this.context);
      textToSpeech(
          'You have to upload an image and a question in order to proceed. Please check.');
    }
    if (_isSwitched) textToSpeech(answer);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          backgroundColor: const Color.fromARGB(255, 217, 229, 222),
          title: Text(widget.title),
          actions: <Widget>[
            IconButton(
              icon: const Icon(
                Icons.photo_size_select_large,
                color: Colors.black,
                size: 30,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CropImage()),
                );
              },
            )
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                const SizedBox(height: 10),
                globals.isFilledImage
                    ? Image.file(globals.pathImage!,
                        width: 250, height: 250, fit: BoxFit.contain)
                    : Image.asset("assets/images/logo.png",
                        width: 250, height: 250),
                const SizedBox(height: 10),
                Row(children: <Widget>[
                  customButton(
                      title: 'Pick from Gallery',
                      icon: Icons.image_outlined,
                      onClick: () => getImage(ImageSource.gallery, false),
                      context: context),
                  const SizedBox(
                    width: 5,
                  ),
                  customButton(
                      title: 'Pick from Camera',
                      icon: Icons.camera,
                      onClick: () => getImage(ImageSource.camera, false),
                      context: context),
                ]),
                const Padding(padding: EdgeInsets.fromLTRB(0, 40, 0, 0)),
                TextField(
                  onChanged: (text) {
                    setState(() {
                      _textController.text.isEmpty
                          ? _isEmpty = true
                          : _textController.text.length < 4
                              ? setBooleans(true)
                              : setBooleans(false);
                    });
                  },
                  controller: _textController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15.0),
                    ),
                    hintText: 'Enter a question...',
                    errorText: _isEmpty
                        ? 'Question can\'t be empty'
                        : _isShort
                            ? 'Question too short'
                            : null,
                    suffixIcon: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween, // added line
                      mainAxisSize: MainAxisSize.min, // added line
                      children: <Widget>[
                        IconButton(
                            icon: const Icon(Icons.mic),
                            onPressed: () {
                              _porcupineManager.stop();
                              //AudioPlayer().play(AssetSource('audio/letsgo.mp3'));
                              toggleRecording();
                              //_porcupineManager.start();
                            }),
                        IconButton(
                          icon: const Icon(Icons.volume_up),
                          onPressed: () async {
                            textToSpeech(_textController.text);
                          },
                        ),
                        IconButton(
                          onPressed: () => {
                            _textController.clear(),
                          },
                          icon: const Icon(Icons.clear),
                        ),
                      ],
                    ),
                  ),
                ),
                const Padding(padding: EdgeInsets.fromLTRB(0, 20, 0, 0)),
                ElevatedButton(
                  onPressed: () => onButtonPress(),
                  style: ButtonStyle(
                    shadowColor: MaterialStateProperty.all(
                        const Color.fromARGB(255, 235, 186, 141)),
                    backgroundColor: MaterialStateProperty.all(
                        const Color.fromARGB(255, 235, 186, 141)),
                    textStyle: MaterialStateProperty.all(
                      const TextStyle(fontSize: 16),
                    ),
                    minimumSize: MaterialStateProperty.all(const Size(150, 50)),
                  ),
                  child: const Text('Ask Me!',
                      style: TextStyle(color: Colors.white)),
                ),
                const Padding(padding: EdgeInsets.fromLTRB(0, 20, 0, 0)),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SizedBox(
                      height: 200,
                      child: Card(
                        color: Colors.white,
                        elevation: 3,
                        margin: const EdgeInsets.all(8.0),
                        child: Column(children: <Widget>[
                          const Padding(
                              padding: EdgeInsets.fromLTRB(0, 20, 0, 0)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              const SizedBox(width: 10),
                              const Text('Answer',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold)),
                              IconButton(
                                  onPressed: () async => {
                                        textToSpeech(answer),
                                      },
                                  icon: const Icon(Icons.volume_up)),
                              Switch(
                                  value: _isSwitched,
                                  onChanged: (value) =>
                                      setState(() => _isSwitched = value))
                            ],
                          ),
                          const Padding(
                              padding: EdgeInsets.fromLTRB(0, 10, 0, 0)),
                          Expanded(
                              flex: 1,
                              child: Padding(
                                padding: const EdgeInsets.all(15),
                                child: !isLoading
                                    ? SingleChildScrollView(
                                        scrollDirection: Axis.vertical,
                                        child: Text(displayedAnswer,
                                            style:
                                                const TextStyle(fontSize: 15)),
                                      )
                                    : const SizedBox(
                                        width: 40,
                                        height: 10,
                                        child: Center(
                                            child: CircularProgressIndicator()),
                                      ),
                              )),
                        ]),
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        ));
  }

  Image newMethod() {
    return Image.file(globals.pathImage!,
        width: 250, height: 250, fit: BoxFit.cover);
  }
}
