import 'dart:io';

import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentAppLaunchConfig {
  const PaymentAppLaunchConfig({
    required this.method,
    required this.androidUrl,
    required this.iosUrl,
    required this.genericUrl,
  });

  final String method;
  final String androidUrl;
  final String iosUrl;
  final String genericUrl;
}

const Map<String, List<String>> _androidSchemeCandidates = {
  'bankk': ['bankak://', 'bankk://'],
  'ocash': ['ocash://'],
  'fawry': ['fawry://', 'fawrypay://'],
};

const Map<String, List<String>> _iosSchemeCandidates = {
  'bankk': ['bankak://', 'bankk://'],
  'ocash': ['ocash://'],
  'fawry': ['fawry://', 'fawrypay://'],
};

const Map<String, String> _androidFallbackUrls = {
  'bankk': 'market://details?id=com.mode.bok.ui',
};

const Map<String, String> _iosFallbackUrls = {
  'bankk': 'itms-apps://itunes.apple.com/app/id1509609935',
};

const Map<String, String> _webFallbackUrls = {
  'bankk':
      'https://play.google.com/store/apps/details?id=com.mode.bok.ui&hl=en',
};

List<String> _orderedLaunchCandidates(PaymentAppLaunchConfig config) {
  final method = config.method.trim().toLowerCase();
  final candidates = <String>[];

  void addCandidate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || candidates.contains(trimmed)) return;
    candidates.add(trimmed);
  }

  if (Platform.isAndroid) {
    addCandidate(config.androidUrl);
    addCandidate(config.genericUrl);
    for (final value in _androidSchemeCandidates[method] ?? const <String>[]) {
      addCandidate(value);
    }
    addCandidate(_androidFallbackUrls[method] ?? '');
    addCandidate(_webFallbackUrls[method] ?? '');
    return candidates;
  }

  if (Platform.isIOS) {
    addCandidate(config.iosUrl);
    addCandidate(config.genericUrl);
    for (final value in _iosSchemeCandidates[method] ?? const <String>[]) {
      addCandidate(value);
    }
    addCandidate(_iosFallbackUrls[method] ?? '');
    addCandidate(_webFallbackUrls[method] ?? '');
    return candidates;
  }

  addCandidate(config.genericUrl);
  addCandidate(_webFallbackUrls[method] ?? '');
  return candidates;
}

Future<bool> launchPaymentApp(
  BuildContext context,
  PaymentAppLaunchConfig config,
) async {
  final candidates = _orderedLaunchCandidates(config);
  if (candidates.isEmpty) {
    if (!context.mounted) return false;
    GFToast.showToast(
        'لا يوجد رابط فتح مباشر مضبوط لهذه الطريقة حالياً.', context);
    return false;
  }

  for (final rawUrl in candidates) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) continue;
    final isWebLike = uri.scheme == 'http' || uri.scheme == 'https';
    final modes = isWebLike
        ? const <LaunchMode>[
            LaunchMode.externalNonBrowserApplication,
            LaunchMode.externalApplication,
            LaunchMode.platformDefault,
          ]
        : const <LaunchMode>[
            LaunchMode.externalNonBrowserApplication,
            LaunchMode.externalApplication,
          ];

    for (final mode in modes) {
      try {
        final launched = await launchUrl(uri, mode: mode);
        if (launched) return true;
      } catch (_) {
        // Try the next mode or candidate.
      }
    }
  }

  if (context.mounted) {
    GFToast.showToast('تعذر فتح التطبيق مباشرة على هذا الجهاز.', context);
  }
  return false;
}
