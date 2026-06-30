import 'package:flutter/material.dart';

class AiPanelPlaceholder extends StatelessWidget {
  const AiPanelPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 320,
      child: Center(child: Text('AI 面板将在阶段 C 接入')),
    );
  }
}
