/// نموذج عنصر واجهة مُحرّك SDUI.
///
/// يدعم قراءة نوع العنصر من مفاتيح إنجليزية أو عربية:
/// - الإنجليزية: `type`
/// - العربية: `نوع` / `العنصر`
class ViewNode {
  final String type;
  final Map<String, dynamic> data;

  ViewNode({required this.type, required this.data});

  factory ViewNode.fromJson(Map<String, dynamic> json) {
    final t = (json['type'] ?? json['نوع'] ?? json['العنصر'])?.toString() ??
        'unknown';
    return ViewNode(type: t, data: json);
  }
}

/// مواصفات العرض (قائمة عناصر SDUI).
///
/// يدعم قراءة القائمة من مفاتيح:
/// - الإنجليزية: `nodes`
/// - العربية: `عناصر` / `مكونات`
class ViewSpec {
  final List<ViewNode> nodes;

  ViewSpec({required this.nodes});

  factory ViewSpec.fromJson(Map<String, dynamic> json) {
    final raw =
        (json['nodes'] ?? json['عناصر'] ?? json['مكونات'] ?? []) as List;
    final list =
        raw.map((e) => ViewNode.fromJson(e as Map<String, dynamic>)).toList();
    return ViewSpec(nodes: list);
  }
}
