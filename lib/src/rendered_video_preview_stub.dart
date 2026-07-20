import 'package:flutter/material.dart';

Widget buildRenderedVideoPreview(String path) => Container(
  constraints: const BoxConstraints(minHeight: 240),
  decoration: BoxDecoration(
    color: const Color(0xFF30455B),
    borderRadius: BorderRadius.circular(24),
  ),
  alignment: Alignment.center,
  padding: const EdgeInsets.all(24),
  child: const Text(
    '当前平台的渲染视频预览适配器尚未加载。',
    style: TextStyle(color: Color(0xFFF6F0E5)),
  ),
);
