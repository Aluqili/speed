import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const Color primaryColor = Color(0xFFFE724C);
const Color backgroundColor = Color(0xFFF5F5F5);

class StoreWorkingHoursScreen extends StatefulWidget {
  final String restaurantId;

  const StoreWorkingHoursScreen({Key? key, required this.restaurantId}) : super(key: key);

  @override
  State<StoreWorkingHoursScreen> createState() => _StoreWorkingHoursScreenState();
}

class _StoreWorkingHoursScreenState extends State<StoreWorkingHoursScreen> {
  final List<String> days = ['saturday', 'sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday'];
  final Map<String, String> dayLabels = {
    'saturday': 'السبت', 'sunday': 'الأحد', 'monday': 'الاثنين',
    'tuesday': 'الثلاثاء', 'wednesday': 'الأربعاء', 'thursday': 'الخميس',
    'friday': 'الجمعة',
  };
  final List<String> shiftTypes = ['كامل', 'صباحي ومسائي', 'مغلق'];
  final List<String> amPm = ['ص', 'م'];
  final List<String> hours = List.generate(12, (i) => '${i + 1}');
  final List<String> minutes = List.generate(60, (i) => i.toString().padLeft(2, '0'));

  Map<String, Map<String, dynamic>> workingHours = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    for (var day in days) {
      workingHours[day] = {
        'type': 'مغلق',
        'openHour': '6', 'openMinute': '00', 'openPeriod': 'ص',
        'closeHour': '18', 'closeMinute': '00', 'closePeriod': 'م',
        'morningOpenHour': '6', 'morningOpenMinute': '00', 'morningOpenPeriod': 'ص',
        'morningCloseHour': '11', 'morningCloseMinute': '00', 'morningClosePeriod': 'ص',
        'eveningOpenHour': '17', 'eveningOpenMinute': '00', 'eveningOpenPeriod': 'م',
        'eveningCloseHour': '22', 'eveningCloseMinute': '00', 'eveningClosePeriod': 'م',
      };
    }
    _loadFromFirestore();
  }

  Future<void> _loadFromFirestore() async {
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
    setState(() => _loading = false);
  }

  String _formatTime(String h, String m, String p) => '$h:$m $p';

  Future<void> _saveWorkingHours() async {
    final Map<String, dynamic> formatted = {};
    workingHours.forEach((day, data) {
      final t = data['type'];
      if (t == 'مغلق') formatted[day] = {'status': 'مغلق'};
      else if (t == 'كامل') formatted[day] = {
        'status': 'كامل',
        'open': _formatTime(data['openHour'], data['openMinute'], data['openPeriod']),
        'close': _formatTime(data['closeHour'], data['closeMinute'], data['closePeriod']),
      };
      else formatted[day] = {
        'status': 'صباحي ومسائي',
        'morning': {
          'open': _formatTime(data['morningOpenHour'], data['morningOpenMinute'], data['morningOpenPeriod']),
          'close': _formatTime(data['morningCloseHour'], data['morningCloseMinute'], data['morningClosePeriod']),
        },
        'evening': {
          'open': _formatTime(data['eveningOpenHour'], data['eveningOpenMinute'], data['eveningOpenPeriod']),
          'close': _formatTime(data['eveningCloseHour'], data['eveningCloseMinute'], data['eveningClosePeriod']),
        },
      };
    });
    await FirebaseFirestore.instance
        .collection('restaurants')
        .doc(widget.restaurantId)
        .update({'workingHours': formatted});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ تم حفظ أوقات الدوام')),
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
          title: const Text(
            'أوقات عمل المطعم',
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 22,
              fontFamily: 'Tajawal',
              letterSpacing: 1.1,
            ),
          ),
          backgroundColor: Colors.white,
          centerTitle: true,
          iconTheme: const IconThemeData(color: primaryColor),
          elevation: 2,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            ...days.map((day) {
              final d = workingHours[day]!;
              return Card(
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              dayLabels[day]!,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Tajawal',
                                fontSize: 17,
                                color: primaryColor,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              d['type'],
                              style: const TextStyle(fontFamily: 'Tajawal', color: Colors.black54),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'نوع الدوام',
                          labelStyle: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                        value: d['type'],
                        items: shiftTypes
                            .map((t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(t, style: const TextStyle(fontFamily: 'Tajawal')),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => d['type'] = v),
                        dropdownColor: Colors.white,
                        style: const TextStyle(fontFamily: 'Tajawal', color: Colors.black),
                      ),
                      const SizedBox(height: 12),
                      if (d['type'] == 'كامل') ...[
                        const Text('الفترة الكاملة:', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                        _timeRow(d, 'open', 'من'),
                        _timeRow(d, 'close', 'إلى'),
                      ] else if (d['type'] == 'صباحي ومسائي') ...[
                        const Text('الصباح:', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                        _timeRow(d, 'morningOpen', 'من'),
                        _timeRow(d, 'morningClose', 'إلى'),
                        const SizedBox(height: 8),
                        const Text('المساء:', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                        _timeRow(d, 'eveningOpen', 'من'),
                        _timeRow(d, 'eveningClose', 'إلى'),
                      ],
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save, color: Colors.white),
                label: const Text('حفظ', style: TextStyle(fontFamily: 'Tajawal', fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label:', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
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
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          filled: true,
          fillColor: Colors.grey[100],
        ),
        dropdownColor: Colors.white,
        style: const TextStyle(fontFamily: 'Tajawal', color: Colors.black),
      ),
    );
  }
}
