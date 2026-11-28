import 'package:flutter/services.dart';

class MicroHaptics {
  static const _channel = MethodChannel('app.micro_haptics');

  static Future<void> microTick({double intensity = 0.5}) async {
    try {
      await _channel.invokeMethod('microTick', {'intensity': intensity});
    } catch (_) {}
  }

  static Future<void> info() async {
    try {
      await _channel.invokeMethod('microTick', {'intensity': 0.6});
      await Future.delayed(Duration(milliseconds: 200));
      await _channel.invokeMethod('microTick', {'intensity': 0.4});
    } catch (_) {}
  }

  static Future<void> success() async {
    try {
      await _channel.invokeMethod('microTick', {'intensity': 0.4});
      await Future.delayed(Duration(milliseconds: 150));
      await _channel.invokeMethod('microTick', {'intensity': 0.2});
    } catch (_) {}
  }

  static Future<void> warning() async {
    try {
      await _channel.invokeMethod('microTick', {'intensity': 0.6});
      await Future.delayed(Duration(milliseconds: 200));
      await _channel.invokeMethod('microTick', {'intensity': 0.4});
    } catch (_) {}
  }

  static Future<void> error() async {
    try {
      await _channel.invokeMethod('microTick', {'intensity': 0.2});
      await Future.delayed(Duration(milliseconds: 100));
      await _channel.invokeMethod('microTick', {'intensity': 0.4});
      await Future.delayed(Duration(milliseconds: 150));
      await _channel.invokeMethod('microTick', {'intensity': 0.6});
    } catch (_) {}
  }
}
