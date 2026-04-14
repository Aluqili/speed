import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speedstar_core/الثيم/ثيم_التطبيق.dart';

const Color primaryColor = AppThemeArabic.storePrimary;
const Color backgroundColor = AppThemeArabic.storeBackground;

class StoreWorkingHoursScreen extends StatefulWidget {
  final String restaurantId;

  const StoreWorkingHoursScreen({Key? key, required this.restaurantId})
      : super(key: key);

  @override
  State<StoreWorkingHoursScreen> createState() =>
      _StoreWorkingHoursScreenState();
}

class _StoreWorkingHoursScreenState extends State<StoreWorkingHoursScreen> {
  final List<String> days = [
    'saturday',
    'sunday',
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday'
  ];
  final Map<String, String> dayLabels = {
    'saturday': 'السبت',
    'sunday': 'الأحد',
    'monday': 'الاثنين',
    'tuesday': 'الثلاثاء',
    'wednesday': 'الأربعاء',
    'thursday': 'الخميس',
    'friday': 'الجمعة',
  };
  final List<String> shiftTypes = ['كامل', 'صباحي ومسائي', 'مغلق'];
  final List<String> amPm = ['ص', 'م'];
  final List<String> hours = List.generate(12, (i) => '${i + 1}');
  final List<String> minutes =
      List.generate(60, (i) => i.toString().padLeft(2, '0'));

  Map<String, Map<String, dynamic>> workingHours = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    for (var day in days) {
      workingHours[day] = {
        'type': 'مغلق',
        'openHour': '6',
        'openMinute': '00',
        'openPeriod': 'ص',
        'closeHour': '18',
        'closeMinute': '00',
        'closePeriod': 'م',
        'morningOpenHour': '6',
        'morningOpenMinute': '00',
        'morningOpenPeriod': 'ص',
        'morningCloseHour': '11',
        'morningCloseMinute': '00',
        'morningClosePeriod': 'ص',
        'eveningOpenHour': '17',
        'eveningOpenMinute': '00',
        'eveningOpenPeriod': 'م',
        'eveningCloseHour': '22',
        'eveningCloseMinute': '00',
        'eveningClosePeriod': 'م',
      };
    }
    _loadFromFirestore();
  }

  Future<void> _loadFromFirestore() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.restaurantId)
          .get();
      final data = doc.data()?['workingHours'] as Map<String, dynamic>?;
      if (data != null) {
        data.forEach((day, v) {
          final entry = workingHours[day]!;
          final status = v['status'];
          entry['type'] = status;
          if (status == 'كامل') {
            final open = (v['open'] as String).split(' ');
            final partsO = open[0].split(':');
            entry['openHour'] = partsO[0];
            entry['openMinute'] = partsO[1];
            entry['openPeriod'] = open[1];
            final close = (v['close'] as String).split(' ');
            final partsC = close[0].split(':');
            entry['closeHour'] = partsC[0];
            entry['closeMinute'] = partsC[1];
            entry['closePeriod'] = close[1];
          } else if (status == 'صباحي ومسائي') {
            final m = v['morning'] as Map<String, dynamic>;
            final o = (m['open'] as String).split(' ');
            final pO = o[0].split(':');
            entry['morningOpenHour'] = pO[0];
            entry['morningOpenMinute'] = pO[1];
            entry['morningOpenPeriod'] = o[1];
            final c = (m['close'] as String).split(' ');
            final pC = c[0].split(':');
            entry['morningCloseHour'] = pC[0];
            entry['morningCloseMinute'] = pC[1];
            entry['morningClosePeriod'] = c[1];
            final e = v['evening'] as Map<String, dynamic>;
            final eo = (e['open'] as String).split(' ');
            final pEO = eo[0].split(':');
            entry['eveningOpenHour'] = pEO[0];
            entry['eveningOpenMinute'] = pEO[1];
            entry['eveningOpenPeriod'] = eo[1];
            final ec = (e['close'] as String).split(' ');
            final pEC = ec[0].split(':');
            entry['eveningCloseHour'] = pEC[0];
            entry['eveningCloseMinute'] = pEC[1];
            entry['eveningClosePeriod'] = ec[1];
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحميل أوقات الدوام: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _formatTime(String h, String m, String p) => '$h:$m $p';

  Future<void> _saveWorkingHours() async {
    final Map<String, dynamic> formatted = {};
    workingHours.forEach((day, data) {
      final t = data['type'];
      if (t == 'مغلق') {
        formatted[day] = {'status': 'مغلق'};
      } else if (t == 'كامل') {
        formatted[day] = {
          'status': 'كامل',
          'open': _formatTime(
              data['openHour'], data['openMinute'], data['openPeriod']),
          'close': _formatTime(
              data['closeHour'], data['closeMinute'], data['closePeriod']),
        };
      } else {
        formatted[day] = {
          'status': 'صباحي ومسائي',
          'morning': {
            'open': _formatTime(data['morningOpenHour'],
                data['morningOpenMinute'], data['morningOpenPeriod']),
            'close': _formatTime(data['morningCloseHour'],
                data['morningCloseMinute'], data['morningClosePeriod']),
          },
          'evening': {
            'open': _formatTime(data['eveningOpenHour'],
                data['eveningOpenMinute'], data['eveningOpenPeriod']),
            'close': _formatTime(data['eveningCloseHour'],
                data['eveningCloseMinute'], data['eveningClosePeriod']),
          },
        };
          }
    });
    try {
      await FirebaseFirestore.instance
          .collection('restaurants')
          .doc(widget.restaurantId)
          .set({'workingHours': formatted}, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم حفظ أوقات الدوام')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حفظ أوقات الدوام: $e')),
      );
    }
  }

  String _daySummary(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? 'مغلق';
    if (type == 'مغلق') {
      return 'المطعم مغلق في هذا اليوم';
    }
    if (type == 'كامل') {
      return '${_formatTime(data['openHour'], data['openMinute'], data['openPeriod'])} - ${_formatTime(data['closeHour'], data['closeMinute'], data['closePeriod'])}';
    }
    return 'فترتان: ${_formatTime(data['morningOpenHour'], data['morningOpenMinute'], data['morningOpenPeriod'])} - ${_formatTime(data['morningCloseHour'], data['morningCloseMinute'], data['morningClosePeriod'])} ثم ${_formatTime(data['eveningOpenHour'], data['eveningOpenMinute'], data['eveningOpenPeriod'])} - ${_formatTime(data['eveningCloseHour'], data['eveningCloseMinute'], data['eveningClosePeriod'])}';
  }

  int get _closedDaysCount =>
      days.where((day) => workingHours[day]?['type'] == 'مغلق').length;

  Widget _sectionCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: backgroundColor,
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: const Text('أوقات عمل المطعم'),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppThemeArabic.storePrimary, Color(0xFF14B8A6)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'نظّم ساعات الدوام بدقة',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'هذه الأوقات تُستخدم لعرض حالة المطعم ومزامنة الفتح والإغلاق التلقائي.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _summaryMetric('أيام العمل', '${days.length - _closedDaysCount}'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _summaryMetric('أيام الإغلاق', '$_closedDaysCount'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...days.map((day) {
              final d = workingHours[day]!;
              return _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dayLabels[day]!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'Tajawal',
                                  fontSize: 19,
                                  color: AppThemeArabic.storeTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _daySummary(d),
                                style: const TextStyle(
                                  color: AppThemeArabic.storeTextSecondary,
                                  fontFamily: 'Tajawal',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _typeBadge(d['type'].toString()),
                      ],
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'نوع الدوام',
                        labelStyle: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontWeight: FontWeight.bold,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        filled: true,
                        fillColor: AppThemeArabic.storeSurface,
                      ),
                      value: d['type'],
                      items: shiftTypes
                          .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(t,
                                    style: const TextStyle(fontFamily: 'Tajawal')),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => d['type'] = v),
                      dropdownColor: Colors.white,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (d['type'] == 'كامل')
                      _timeBlock(
                        title: 'الفترة الكاملة',
                        icon: Icons.schedule_outlined,
                        children: [
                          _timeRow(d, 'open', 'من'),
                          _timeRow(d, 'close', 'إلى'),
                        ],
                      )
                    else if (d['type'] == 'صباحي ومسائي') ...[
                      _timeBlock(
                        title: 'الفترة الصباحية',
                        icon: Icons.wb_sunny_outlined,
                        children: [
                          _timeRow(d, 'morningOpen', 'من'),
                          _timeRow(d, 'morningClose', 'إلى'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _timeBlock(
                        title: 'الفترة المسائية',
                        icon: Icons.nights_stay_outlined,
                        children: [
                          _timeRow(d, 'eveningOpen', 'من'),
                          _timeRow(d, 'eveningClose', 'إلى'),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            }),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save, color: Colors.white),
                label: const Text('حفظ',
                    style: TextStyle(fontFamily: 'Tajawal', fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
                onPressed: _saveWorkingHours,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeRow(Map<String, dynamic> d, String key, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppThemeArabic.storePrimary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.bold,
                color: AppThemeArabic.storePrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _dropdown(hours, d, '${key}Hour'),
          const SizedBox(width: 4),
          _dropdown(minutes, d, '${key}Minute'),
          const SizedBox(width: 4),
          _dropdown(amPm, d, '${key}Period'),
        ],
      ),
    );
  }

  Widget _dropdown(List<String> items, Map<String, dynamic> d, String k) {
    if (!items.contains(d[k])) {
      d[k] = items.first;
    }
    return Expanded(
      child: DropdownButtonFormField<String>(
        value: d[k],
        items: items
            .map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(e, style: const TextStyle(fontFamily: 'Tajawal')),
                ))
            .toList(),
        onChanged: (v) => setState(() => d[k] = v),
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          filled: true,
          fillColor: AppThemeArabic.storeSurface,
        ),
        dropdownColor: Colors.white,
        style: const TextStyle(fontFamily: 'Tajawal', color: Colors.black),
      ),
    );
  }

  Widget _summaryMetric(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              fontFamily: 'Tajawal',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontFamily: 'Tajawal',
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeBadge(String type) {
    Color color;
    switch (type) {
      case 'كامل':
        color = Colors.green;
        break;
      case 'صباحي ومسائي':
        color = Colors.orange;
        break;
      default:
        color = Colors.redAccent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        type,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontFamily: 'Tajawal',
        ),
      ),
    );
  }

  Widget _timeBlock({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppThemeArabic.storeSurface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppThemeArabic.storePrimary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}
