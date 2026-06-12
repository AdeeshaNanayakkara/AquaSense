import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  double _tankValue = 0.0;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchTankValue();
  }

  void _fetchTankValue() {
    _databaseRef
        .child('Inputs/tank')
        .onValue
        .listen(
          (DatabaseEvent event) {
            setState(() {
              _isLoading = false;
              if (event.snapshot.exists) {
                final value = event.snapshot.value;
                if (value is num) {
                  _tankValue = value.toDouble();
                  _errorMessage = '';
                } else if (value is String) {
                  _tankValue = double.tryParse(value) ?? 0.0;
                  _errorMessage = '';
                } else {
                  _errorMessage = 'Invalid data type';
                  _tankValue = 0.0;
                }
              } else {
                _errorMessage = 'Tank value not found in database';
                _tankValue = 0.0;
              }
            });
          },
          onError: (error) {
            setState(() {
              _isLoading = false;
              _errorMessage = 'Error: ${error.message}';
              _tankValue = 0.0;
            });
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Tank Value:', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            if (_isLoading)
              const CircularProgressIndicator()
            else if (_errorMessage.isNotEmpty)
              Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red, fontSize: 16),
                textAlign: TextAlign.center,
              )
            else
              Text(
                '${_tankValue.toStringAsFixed(2)} L',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
          ],
        ),
      ),
    );
  }
}
