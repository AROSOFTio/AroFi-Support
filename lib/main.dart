import 'package:flutter/material.dart';
import 'src/api/api_client.dart';
import 'src/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final api = await ApiClient.create();
  runApp(AroFiSupportApp(api: api));
}
