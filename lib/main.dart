import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:replicate/replicate.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'api/speech_api.dart';
import 'ttstate.dart';

void main() async {
  await dotenv.load(fileName: ".env");
  Replicate.apiKey = dotenv.env['API_KEY']!;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VQAsk',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xD9E5DE), background: Colors.white),
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
  File? _image;
  bool isListening = false;

  /*for the text-to-speech*/
  FlutterTts fluttertts = FlutterTts();

  void textToSpeech(String text) async {
    await fluttertts.setLanguage("en-US");
    await fluttertts.setVolume(10);
    await fluttertts.setSpeechRate(0.5);
    await fluttertts.setPitch(1);
    await fluttertts.speak(text);
  }

  Future getImage(ImageSource source) async {
    try {
      final image = await ImagePicker().pickImage(source: source);
      if (image == null) return;
      //final imageTemporary = File(image.path);
      final imagePermanent = await saveFilePermanently(image.path);

      setState(() {
        this._image = imagePermanent; //imageTemporary;
      });
    } on PlatformException catch (e) {
      print("Failed to pick image: $e");
    }
  }

  Future<File> saveFilePermanently(String imagePath) async {
    final directory = await getApplicationDocumentsDirectory();
    final name = basename(imagePath);
    final image = File('${directory.path}/$name');
    return File(imagePath).copy(image.path);
  }

  Future<String> getAnswer(String question) async {
    //ByteData bytes = await rootBundle.load('assets/images/cat.jpg');
    //var buffer = bytes.buffer;
    //var encodedImg = base64.encode(Uint8List.view(buffer));
    List<int> fileInByte = _image!.readAsBytesSync();
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
      //nothing
    }
    await Future.delayed(const Duration(seconds: 7));
    PaginatedPredictions predictionsPageList =
        await Replicate.instance.predictions.list();

    Prediction prediction = await Replicate.instance.predictions.get(
      id: predictionsPageList.results.elementAt(0).id,
    );
    return prediction.output;
  }

  // use this controller to get what the user typed
  TextEditingController _textController = TextEditingController();
  String displayedAnswer = "Answer: ";

  void displayAnswer(answer) {
    setState(() {
      displayedAnswer = "Answer: " + answer;
    });
  }

  Future toggleRecording() => SpeechApi.toggleRecording(
      onResult: (text) => setState(() {
            _textController.text = text;
          }),
      onListening: (isListening) {
        this.isListening = isListening;
      });

  Widget customButton({
    required String title,
    required IconData icon,
    required VoidCallback onClick,
  }) {
    return Container(
        width: 400,
        child: ElevatedButton(
            onPressed: onClick,
            child: Row(
              children: [
                Icon(icon),
                SizedBox(width: 80),
                Text(
                  title,
                  textAlign: TextAlign.center,
                ),
              ],
            )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(widget.title),
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                SizedBox(height: 20),
                _image != null
                    ? Image.file(_image!,
                        width: 250, height: 250, fit: BoxFit.cover)
                    : Image.asset("assets/images/logo.jpg"),
                SizedBox(height: 20),
                customButton(
                    title: 'Pick from Gallery',
                    icon: Icons.image_outlined,
                    onClick: () => getImage(ImageSource.gallery)),
                customButton(
                    title: 'Pick from Camera',
                    icon: Icons.camera,
                    onClick: () => getImage(ImageSource.camera)),
                Padding(padding: EdgeInsets.fromLTRB(0, 40, 0, 0)),
                TextField(
                  controller: _textController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15.0),
                    ),
                    hintText: 'Enter a question...',
                    suffixIcon: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween, // added line
                      mainAxisSize: MainAxisSize.min, // added line
                      children: <Widget>[
                        IconButton(
                            icon: Icon(Icons.mic), onPressed: toggleRecording),
                        IconButton(
                          icon: Icon(Icons.volume_up),
                          onPressed: () async {
                            textToSpeech(_textController.text);
                          },
                        ),
                        IconButton(
                          onPressed: () => _textController.clear(),
                          icon: const Icon(Icons.clear),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(padding: EdgeInsets.fromLTRB(0, 20, 0, 0)),
                ElevatedButton(
                  onPressed: () async {
                    //textToSpeech(_textController.text);

                    String answer = await getAnswer(_textController.text);
                    displayAnswer(answer);
                    textToSpeech(answer);
                  },
                  style: ButtonStyle(
                    backgroundColor:
                        MaterialStateProperty.all(Colors.orange[400]),
                    textStyle: MaterialStateProperty.all(
                      const TextStyle(fontSize: 16),
                    ),
                    minimumSize: MaterialStateProperty.all(const Size(150, 50)),
                  ),
                  child: const Text('Ask Me!',
                      style: TextStyle(color: Colors.white)),
                ),
                Expanded(
                    child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: Text('$displayedAnswer',
                            style: TextStyle(fontSize: 15)))),
              ],
            ),
          ),
        ));
  }
}
