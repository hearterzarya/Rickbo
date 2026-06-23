import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

/// Translates a raw [DioException] / exception into a clean Hindi message and
/// shows it as a non-blocking SnackBar. Never dumps raw HTTP / HTML / JSON to UI.
class HindiError {
  static String messageOf(Object e) {
    if (e is DioException) {
      // Server replied with a structured Hindi error?
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        final msg = data['message'];
        if (msg is String && msg.trim().isNotEmpty) return msg;
        if (msg is List && msg.isNotEmpty) return msg.first.toString();
      }
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'इंटरनेट धीमा है — दोबारा कोशिश करें';
        case DioExceptionType.badCertificate:
          return 'सुरक्षा प्रमाणपत्र गलत है';
        case DioExceptionType.cancel:
          return 'रद्द कर दिया';
        case DioExceptionType.connectionError:
          return 'सर्वर से जुड़ नहीं पा रहे — नेट चेक करें';
        case DioExceptionType.badResponse:
          final code = e.response?.statusCode ?? 0;
          if (code == 401) return 'सेशन खत्म हो गई — दोबारा लॉगिन करें';
          if (code == 403) return 'इसकी अनुमति नहीं है';
          if (code == 404) return 'नहीं मिला';
          if (code >= 500) return 'सर्वर में दिक़्क़त है — थोड़ी देर बाद कोशिश करें';
          return 'कुछ गलत हुआ (कोड $code)';
        case DioExceptionType.unknown:
          return 'कुछ गलत हुआ — दोबारा कोशिश करें';
      }
    }
    final s = e.toString();
    if (s.contains('SocketException') || s.contains('Failed host lookup')) {
      return 'इंटरनेट नहीं है — नेट चेक करें';
    }
    return 'कुछ गलत हुआ — दोबारा कोशिश करें';
  }

  /// Show as a SnackBar on the current screen.
  static void show(BuildContext context, Object error) {
    final msg = messageOf(error);
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 15)),
      backgroundColor: Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
  }

  /// Maps a backend error to a typed action the UI can take without
  /// re-parsing strings. Returns null for unrecognised errors.
  static ErrorAction? actionOf(Object error) {
    final msg = messageOf(error);
    if (msg.contains('सब्सक्रिप्शन') && (msg.contains('ख़त्म') || msg.contains('समाप्त'))) {
      return ErrorAction.subscriptionExpired;
    }
    if (msg.toLowerCase().contains('suspended') || msg.contains('निलंबित')) {
      return ErrorAction.accountSuspended;
    }
    if (msg.contains('location') || msg.contains('Location') || msg.contains('लोकेशन')) {
      return ErrorAction.locationMissing;
    }
    return null;
  }
}

/// Actions the UI can take based on a backend error message.
enum ErrorAction { subscriptionExpired, accountSuspended, locationMissing }