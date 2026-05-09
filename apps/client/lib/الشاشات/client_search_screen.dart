import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../الثيم/client_theme.dart';
import 'restaurant_detail_screen.dart' show RestaurantDetailScreen;

class ClientSearchScreen extends StatefulWidget {
  const ClientSearchScreen({super.key, this.clientId = ''});
  final String clientId;

  @override
  State<ClientSearchScreen> createState() => _ClientSearchScreenState();
}

class _ClientSearchScreenState extends State<ClientSearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  String _query = '';
  String _activeCategory = 'الكل';
  bool _showOpenOnly = false;
  bool _sortByRating = false;
  final List<String> _recentSearches = [];

  List<Map<String, dynamic>> _allRestaurants = [];
  bool _loading = true;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = FirebaseFirestore.instance
        .collection('restaurants')
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() {
        _allRestaurants =
            snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        _loading = false;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  void _onSubmitted(String value) {
    final q = value.trim();
    if (q.isNotEmpty && !_recentSearches.contains(q)) {
      setState(() {
        _recentSearches.insert(0, q);
        if (_recentSearches.length > 6) _recentSearches.removeLast();
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _allRestaurants.where((r) {
      // Open filter
      if (_showOpenOnly) {
        final isOpen = r['isOpen'] as bool? ?? true;
        if (!isOpen) return false;
      }
      // Category filter
      if (_activeCategory != 'الكل') {
        final cats =
            (r['categories'] as List?)?.cast<String>().map((c) => c.trim()) ??
                [];
        if (!cats.contains(_activeCategory)) return false;
      }
      // Text filter
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        final name = (r['name'] as String? ?? '').toLowerCase();
        final cats = (r['categories'] as List?)?.cast<String>() ?? [];
        final offers = (r['offers'] as String? ?? '').toLowerCase();
        if (!name.contains(q) &&
            !cats.any((c) => c.toLowerCase().contains(q)) &&
            !offers.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();

    if (_sortByRating) {
      list.sort((a, b) => ((b['rating'] as num?) ?? 0)
          .compareTo((a['rating'] as num?) ?? 0));
    }
    return list;
  }

  List<String> get _availableCategories {
    final seen = <String>{};
    final result = <String>[];
    for (final r in _allRestaurants) {
      final cats = (r['categories'] as List?)?.cast<String>() ?? [];
      for (final c in cats) {
        final t = c.trim();
        if (t.isNotEmpty && seen.add(t)) result.add(t);
      }
    }
    return result;
  }

  bool get _isIdle =>
      _query.isEmpty && _activeCategory == 'الكل' && !_showOpenOnly;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cats = _availableCategories;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          _buildSearchHeader(isDark),
          _buildFilterRow(isDark),
          if (cats.isNotEmpty) _buildCategoryBar(cats, isDark),
          Expanded(
            child: _loading
                ? _buildSkeleton(isDark)
                : _isIdle
                    ? _buildIdleState(isDark)
                    : _buildResults(_filtered, isDark),
          ),
        ],
      ),
    );
  }

  // ── Search header ────────────────────────────────────────────────────────

  Widget _buildSearchHeader(bool isDark) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? const Color(0x33FF6B00)
                  : const Color(0xFFE0E0E0),
            ),
            boxShadow: isDark
                ? null
                : [
                    const BoxShadow(
                        color: Color(0x0A000000), blurRadius: 8),
                  ],
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            onChanged: _onSearch,
            onSubmitted: _onSubmitted,
            textDirection: TextDirection.rtl,
            autofocus: false,
            style: TextStyle(
              color: isDark ? Colors.white : ClientColors.lightTextPrimary,
              fontSize: 15,
            ),
            decoration: InputDecoration(
              hintText: 'ابحث عن مطعم أو صنف...',
              hintStyle: TextStyle(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.40)
                    : const Color(0xFF9E9E9E),
                fontSize: 14,
              ),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: ClientColors.primary),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: isDark
                              ? Colors.white54
                              : const Color(0xFF9E9E9E),
                          size: 18),
                      onPressed: () {
                        _controller.clear();
                        _onSearch('');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ),
    );
  }

  // ── Filter chips ─────────────────────────────────────────────────────────

  Widget _buildFilterRow(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: SizedBox(
        height: 40,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          children: [
            _Chip(
              label: 'مفتوح الآن',
              icon: Icons.access_time_rounded,
              active: _showOpenOnly,
              isDark: isDark,
              onTap: () => setState(() => _showOpenOnly = !_showOpenOnly),
            ),
            const SizedBox(width: 8),
            _Chip(
              label: 'أعلى تقييم',
              icon: Icons.star_rounded,
              active: _sortByRating,
              isDark: isDark,
              onTap: () => setState(() => _sortByRating = !_sortByRating),
            ),
          ],
        ),
      ),
    );
  }

  // ── Category bar (dynamic from restaurants) ───────────────────────────────

  Widget _buildCategoryBar(List<String> categories, bool isDark) {
    final all = ['الكل', ...categories];
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: all.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final c = all[i];
            final isActive = c == _activeCategory;
            return GestureDetector(
              onTap: () => setState(() => _activeCategory = c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
                decoration: BoxDecoration(
                  color: isActive
                      ? ClientColors.primary
                      : isDark
                          ? const Color(0x14FFFFFF)
                          : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive
                        ? ClientColors.primary
                        : isDark
                            ? const Color(0x1AFFFFFF)
                            : const Color(0xFFE0E0E0),
                  ),
                ),
                child: Text(
                  c,
                  style: TextStyle(
                    color: isActive
                        ? Colors.white
                        : isDark
                            ? Colors.white70
                            : ClientColors.lightTextSecondary,
                    fontWeight:
                        isActive ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Skeleton loading ─────────────────────────────────────────────────────

  Widget _buildSkeleton(bool isDark) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => Container(
        height: 90,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }

  // ── Idle state ───────────────────────────────────────────────────────────

  Widget _buildIdleState(bool isDark) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
      children: [
        if (_recentSearches.isNotEmpty) ...[
          _SectionLabel(
              label: 'عمليات البحث الأخيرة', isDark: isDark),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recentSearches
                .map((s) => GestureDetector(
                      onTap: () {
                        _controller.text = s;
                        _onSearch(s);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0x14FFFFFF)
                              : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark
                                ? const Color(0x1AFFFFFF)
                                : const Color(0xFFE0E0E0),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.history_rounded,
                                size: 13,
                                color: isDark
                                    ? Colors.white38
                                    : const Color(0xFF9E9E9E)),
                            const SizedBox(width: 5),
                            Text(s,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white70
                                      : ClientColors.lightTextSecondary,
                                  fontSize: 12,
                                )),
                          ],
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
        ],
        _SectionLabel(
            label: 'جميع المطاعم (${_allRestaurants.length})',
            isDark: isDark),
        const SizedBox(height: 10),
        ..._allRestaurants.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RestaurantTile(
                  data: r, clientId: widget.clientId, isDark: isDark),
            )),
      ],
    );
  }

  // ── Results ───────────────────────────────────────────────────────────────

  Widget _buildResults(List<Map<String, dynamic>> filtered, bool isDark) {
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded,
                size: 62,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.18)
                    : const Color(0xFFBDBDBD)),
            const SizedBox(height: 14),
            Text(
              'لا توجد نتائج',
              style: TextStyle(
                color: isDark
                    ? Colors.white54
                    : ClientColors.lightTextSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'جرّب كلمة مختلفة أو غيّر الفلتر',
              style: TextStyle(
                color: isDark
                    ? Colors.white30
                    : const Color(0xFFBDBDBD),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _RestaurantTile(
        data: filtered[i],
        clientId: widget.clientId,
        isDark: isDark,
      ),
    );
  }
}

// ── Chip widget ────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.active,
    required this.isDark,
    required this.onTap,
    this.icon,
  });
  final String label;
  final bool active;
  final bool isDark;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? ClientColors.primary
              : isDark
                  ? const Color(0x14FFFFFF)
                  : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? ClientColors.primary
                : isDark
                    ? const Color(0x1AFFFFFF)
                    : const Color(0xFFDDDDDD),
          ),
          boxShadow: active ? ClientColors.glowShadow(blur: 10) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 13,
                  color: active
                      ? Colors.white
                      : isDark
                          ? Colors.white54
                          : const Color(0xFF9E9E9E)),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: active
                    ? Colors.white
                    : isDark
                        ? Colors.white70
                        : ClientColors.lightTextSecondary,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.isDark});
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: isDark ? Colors.white60 : ClientColors.lightTextSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

// ── Restaurant tile ───────────────────────────────────────────────────────

class _RestaurantTile extends StatelessWidget {
  const _RestaurantTile({
    required this.data,
    required this.clientId,
    required this.isDark,
  });
  final Map<String, dynamic> data;
  final String clientId;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final id = data['id'] as String? ?? '';
    final name = data['name'] as String? ?? 'مطعم';
    final cats = (data['categories'] as List?)?.cast<String>() ?? [];
    final rating =
        (data['rating'] as num?)?.toStringAsFixed(1) ?? '–';
    final isOpen = data['isOpen'] as bool? ?? true;
    final imageUrl =
        (data['logoImageUrl'] ?? data['image'] ?? '').toString();
    final deliveryFee =
        (data['deliveryFee'] as num?)?.toStringAsFixed(0) ?? '–';
    final hasOffer = data['hasOffers'] as bool? ?? false;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RestaurantDetailScreen(
            restaurantId: id,
            name: name,
            image: imageUrl,
            offers: (data['offers'] ?? '').toString(),
            clientId: clientId,
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.transparent : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Image
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _placeholder(),
                          )
                        : _placeholder(),
                  ),
                  if (hasOffer)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: ClientColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('عرض',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : ClientColors.lightTextPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: isOpen
                                ? ClientColors.success
                                    .withValues(alpha: 0.15)
                                : ClientColors.error
                                    .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isOpen ? 'مفتوح' : 'مغلق',
                            style: TextStyle(
                              color: isOpen
                                  ? ClientColors.success
                                  : ClientColors.error,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (cats.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        cats.take(3).join(' · '),
                        style: TextStyle(
                          color: isDark
                              ? Colors.white54
                              : ClientColors.lightTextSecondary,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: ClientColors.accent, size: 13),
                        const SizedBox(width: 3),
                        Text(rating,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : ClientColors.lightTextPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            )),
                        const Spacer(),
                        Icon(Icons.delivery_dining_rounded,
                            size: 13,
                            color: isDark
                                ? Colors.white38
                                : const Color(0xFF9E9E9E)),
                        const SizedBox(width: 3),
                        Text(
                          deliveryFee != '–' ? '$deliveryFee ج.س' : 'مجاني',
                          style: TextStyle(
                            color: isDark
                                ? Colors.white54
                                : ClientColors.lightTextSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios_rounded,
                  color: ClientColors.primary, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0x1AFF6B00),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.restaurant_rounded,
          color: ClientColors.primary, size: 28),
    );
  }
}
