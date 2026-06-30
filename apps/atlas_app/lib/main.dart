import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/atlas_app.dart';

void main() {
  runApp(const ProviderScope(child: AtlasApp()));
}
