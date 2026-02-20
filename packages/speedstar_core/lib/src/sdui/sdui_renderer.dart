import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'sdui_models.dart';

class RemoteView extends StatelessWidget {
  final AppConfig appConfig;
  final EdgeInsets padding;

  const RemoteView({
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
        final colorToken = node.data['color']?.toString();
        final color = _resolveColor(context, colorToken);
        return Text(
          node.data['text']?.toString() ?? '',
          style: TextStyle(
            fontSize: (node.data['fontSize'] as num?)?.toDouble() ?? 18,
            fontWeight: _parseFontWeight(node.data['weight']?.toString()),
            color: color,
          ),
        );
      case 'image':
        final url = node.data['url']?.toString() ?? '';
        final width = (node.data['width'] as num?)?.toDouble();
        final height = (node.data['height'] as num?)?.toDouble();
        return url.isEmpty
            ? const SizedBox.shrink()
            : Image.network(
                url,
                width: width,
                height: height,
                fit: BoxFit.cover,
              );
      case 'button':
        final title = node.data['title']?.toString() ?? 'Action';
        final style = node.data['style']?.toString();
        final colorToken = node.data['color']?.toString();
        final color = _resolveColor(context, colorToken);
        final route = node.data['route']?.toString();
        final ButtonStyle common = ButtonStyle(
          backgroundColor: color != null
            ? WidgetStatePropertyAll<Color>(color)
              : null,
        );
        Widget buildButton(Widget child, VoidCallback onPressed) {
          switch (style) {
            case 'filled':
              return FilledButton(
                onPressed: onPressed,
                style: common,
                child: child,
              );
            case 'outlined':
              return OutlinedButton(
                onPressed: onPressed,
                style: common,
                child: child,
              );
            case 'elevated':
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
            final msg = node.data['message']?.toString() ?? 'Clicked';
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(msg)));
            return;
          }
          final current = appConfig.remoteViewUrl;
          if (current == null ||
              (current.scheme != 'http' && current.scheme != 'https')) {
            return;
          }
          final baseStr = _ensureTrailingSlash(_folderOf(current.toString()));
          String targetFile = route == 'home' ? 'home.json' : '$route.json';
          try {
            final res = await http.get(Uri.parse(baseStr + 'index.json'));
            if (res.statusCode == 200) {
              final mapped = _mapFromIndex(res.body)[route];
              if (mapped is String && mapped.isNotEmpty) {
                targetFile = mapped;
              }
            }
          } catch (_) {}
          final next = Uri.parse(baseStr + targetFile);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Loading: ${next.toString()}')),
          );
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  RemoteView(appConfig: AppConfig(remoteViewUrl: next)),
            ),
          );
        });
      case 'spacer':
        final h = (node.data['height'] as num?)?.toDouble() ?? 12;
        return SizedBox(height: h);
      default:
        return const SizedBox.shrink();
    }
  }

  FontWeight _parseFontWeight(String? w) {
    switch (w) {
      case 'bold':
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
        return scheme.primary;
      case 'secondary':
        return scheme.secondary;
      case 'tertiary':
        return scheme.tertiary;
      case 'surface':
        return scheme.surface;
      case 'onSurface':
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

  String _folderOf(String url) {
    final i = url.lastIndexOf('/');
    if (i < 0) return url;
    return url.substring(0, i + 1);
  }

  String _ensureTrailingSlash(String s) => s.endsWith('/') ? s : ('$s/');

  Map<String, dynamic> _mapFromIndex(String body) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final pages = decoded['pages'];
      if (pages is Map<String, dynamic>) return pages;
    } catch (_) {}
    return {};
  }
}
