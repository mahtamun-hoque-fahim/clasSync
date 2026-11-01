import 'package:flutter/material.dart';

import 'theme.dart';

void main() => runApp(const ClasSyncApp());

class ClasSyncApp extends StatelessWidget {
  const ClasSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ClasSync',
      theme: buildTheme('blue'),
      home: const Scaffold(body: Center(child: Text('ClasSync'))),
    );
  }
}
