import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'sdui_models.dart';

/// واجهة عربية تعرض تخطيطاً عن بعد (Server-Driven UI)
/// تدعم مفاتيح وأنواع عربية لتسهيل التحرير.
class RemoteViewArabic extends StatelessWidget {
  final AppConfig appConfig;
  final EdgeInsets padding;

  const RemoteViewArabic({
    super.key,
    required this.appConfig,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: appConfig.loadView(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final spec = ViewSpec.fromJson(snapshot.data ?? {});
        return ListView(
          padding: padding,
          children: spec.nodes.map((n) => _buildNode(context, n)).toList(),
        );
      },
    );
  }

  Widget _buildNode(BuildContext context, ViewNode node) {
    switch (node.type) {
      case 'text':
      case 'نص':
        {
          final colorToken = (node.data['color'] ?? node.data['لون'])
              ?.toString();
          final color = _resolveColor(context, colorToken);
          final fontSize =
              (node.data['fontSize'] as num?)?.toDouble() ??
              (node.data['حجم'] as num?)?.toDouble() ??
              18;
          final weightStr = (node.data['weight'] ?? node.data['وزن'])
              ?.toString();
          return Text(
            (node.data['text'] ?? node.data['نص'])?.toString() ?? '',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: _parseFontWeight(weightStr),
              color: color,
            ),
          );
        }
      case 'image':
      case 'صورة':
        {
          final url = (node.data['url'] ?? node.data['رابط'])?.toString() ?? '';
          final width =
              (node.data['width'] as num?)?.toDouble() ??
              (node.data['عرض'] as num?)?.toDouble();
          final height =
              (node.data['height'] as num?)?.toDouble() ??
              (node.data['ارتفاع'] as num?)?.toDouble();
          return url.isEmpty
              ? const SizedBox.shrink()
              : Image.network(
                  url,
                  width: width,
                  height: height,
                  fit: BoxFit.cover,
                );
        }
      case 'button':
      case 'زر':
        {
          final title =
              (node.data['title'] ?? node.data['عنوان'])?.toString() ?? 'تنفيذ';
          final route = (node.data['route'] ?? node.data['مسار'])?.toString();
          final style = (node.data['style'] ?? node.data['نمط'])?.toString();
          final colorToken = (node.data['color'] ?? node.data['لون'])
              ?.toString();
          final color = _resolveColor(context, colorToken);
          final ButtonStyle common = ButtonStyle(
            backgroundColor: color != null
                ? WidgetStatePropertyAll<Color>(color)
                : null,
          );
          Widget buildButton(Widget child, VoidCallback onPressed) {
            switch (style) {
              case 'filled':
              case 'مملوء':
                return FilledButton(
                  onPressed: onPressed,
                  style: common,
                  child: child,
                );
              case 'outlined':
              case 'محدد':
                return OutlinedButton(
                  onPressed: onPressed,
                  style: common,
                  child: child,
                );
              case 'elevated':
              case 'مرتفع':
              default:
                return ElevatedButton(
                  onPressed: onPressed,
                  style: common,
                  child: child,
                );
            }
          }

          return buildButton(Text(title), () async {
            if (route == null || route.isEmpty) {
              final msg =
                  (node.data['message'] ?? node.data['رسالة'])?.toString() ??
                  'تم الضغط';
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(msg)));
              return;
            }
            await _navigateToRoute(context, route);
          });
        }
      case 'list_item':
      case 'عنصر_قائمة':
        {
          final title =
              (node.data['title'] ?? node.data['عنوان'])?.toString() ?? '';
          final subtitle = (node.data['subtitle'] ?? node.data['وصف'])
              ?.toString();
          final iconName = (node.data['icon'] ?? node.data['أيقونة'])
              ?.toString();
          final route = (node.data['route'] ?? node.data['مسار'])?.toString();
          final leading = iconName != null
              ? Icon(_iconFromName(iconName))
              : null;
          return Card(
            child: ListTile(
              leading: leading,
              title: Text(title),
              subtitle: subtitle != null ? Text(subtitle) : null,
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: route != null && route.isNotEmpty
                  ? () async => _navigateToRoute(context, route)
                  : null,
            ),
          );
        }
      case 'card':
      case 'بطاقة':
        {
          final children =
              (node.data['children'] ?? node.data['أطفال']) as List? ?? [];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children
                    .map(
                      (e) => _buildNode(
                        context,
                        ViewNode.fromJson(Map<String, dynamic>.from(e as Map)),
                      ),
                    )
                    .toList(),
              ),
            ),
          );
        }
      case 'row':
      case 'صف':
        {
          final children =
              (node.data['children'] ?? node.data['أطفال']) as List? ?? [];
          return Row(
            children: children
                .map(
                  (e) => _buildNode(
                    context,
                    ViewNode.fromJson(Map<String, dynamic>.from(e as Map)),
                  ),
                )
                .toList(),
          );
        }
      case 'column':
      case 'عمود':
        {
          final children =
              (node.data['children'] ?? node.data['أطفال']) as List? ?? [];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children
                .map(
                  (e) => _buildNode(
                    context,
                    ViewNode.fromJson(Map<String, dynamic>.from(e as Map)),
                  ),
                )
                .toList(),
          );
        }
      case 'divider':
      case 'فاصل_عرضي':
        {
          return const Divider();
        }
      case 'icon':
      case 'أيقونة':
        {
          final iconName =
              (node.data['icon'] ?? node.data['أيقونة'])?.toString() ?? '';
          final colorToken = (node.data['color'] ?? node.data['لون'])
              ?.toString();
          final color = _resolveColor(context, colorToken);
          return Icon(_iconFromName(iconName), color: color);
        }
      case 'spacer':
      case 'فاصل':
        {
          final h =
              (node.data['height'] as num?)?.toDouble() ??
              (node.data['ارتفاع'] as num?)?.toDouble() ??
              12;
          return SizedBox(height: h);
        }
      default:
        return const SizedBox.shrink();
    }
  }

  FontWeight _parseFontWeight(String? w) {
    switch (w) {
      case 'bold':
      case 'عريض':
        return FontWeight.bold;
      case 'w600':
        return FontWeight.w600;
      default:
        return FontWeight.normal;
    }
  }

  Color? _resolveColor(BuildContext context, String? token) {
    if (token == null || token.isEmpty) return null;
    final scheme = Theme.of(context).colorScheme;
    switch (token) {
      case 'primary':
      case 'أساسي':
        return scheme.primary;
      case 'secondary':
      case 'ثانوي':
        return scheme.secondary;
      case 'tertiary':
      case 'ثالث':
        return scheme.tertiary;
      case 'surface':
      case 'سطح':
        return scheme.surface;
      case 'onSurface':
      case 'على_السطح':
        return scheme.onSurface;
      default:
        try {
          String hex = token.trim();
          if (hex.startsWith('#')) hex = hex.substring(1);
          if (hex.length == 6) hex = 'FF' + hex;
          final val = int.parse(hex, radix: 16);
          return Color(val);
        } catch (_) {
          return null;
        }
    }
  }

  Future<void> _navigateToRoute(BuildContext context, String route) async {
    final remote = appConfig.remoteViewUrl;
    if (remote == null ||
        (remote.scheme != 'http' && remote.scheme != 'https')) {
      return;
    }
    final remoteStr = remote.toString();
    final lastSlash = remoteStr.lastIndexOf('/');
    final baseStr = lastSlash >= 0
        ? remoteStr.substring(0, lastSlash + 1)
        : (remoteStr + '/');
    String targetFile = route == 'home' ? 'home.json' : '$route.json';
    try {
      final indexRes = await http.get(Uri.parse(baseStr + 'index.json'));
      if (indexRes.statusCode == 200) {
        final map = ViewSpecIndex._parse(indexRes.body);
        final mapped = map[route];
        if (mapped is String && mapped.isNotEmpty) {
          targetFile = mapped;
        }
      }
    } catch (_) {}
    final next = Uri.parse(baseStr + targetFile);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('تحميل: ' + next.toString())));
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            RemoteViewArabic(appConfig: AppConfig(remoteViewUrl: next)),
      ),
    );
  }

  IconData _iconFromName(String name) {
    switch (name) {
      case 'chat':
      case 'محادثة':
        return Icons.chat;
      case 'receipt_long':
      case 'طلبات':
        return Icons.receipt_long;
      case 'menu_book':
      case 'قائمة':
        return Icons.menu_book;
      case 'add_box':
      case 'إضافة':
        return Icons.add_box;
      case 'schedule':
      case 'جدول':
        return Icons.schedule;
      case 'account_balance_wallet':
      case 'محفظة':
        return Icons.account_balance_wallet;
      default:
        return Icons.circle;
    }
  }
}

class ViewSpecIndex {
  static Map<String, dynamic> _decode(String s) {
    try {
      return Map<String, dynamic>.from(
        (const JsonDecoder()).convert(s) as Map<String, dynamic>,
      );
    } catch (_) {
      return {};
    }
  }

  static Map<String, String> _parse(String s) {
    final root = _decode(s);
    final pages = root['pages'];
    if (pages is Map) {
      return pages.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return {};
  }
}
