import 'package:flutter/material.dart';

import 'app.dart';

// TODO(yame): initialiser Firebase ici avant runApp, une fois le projet
// créé sur console.firebase.google.com et `flutterfire configure` exécuté :
//
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

void main() {
  runApp(const YameApp());
}
