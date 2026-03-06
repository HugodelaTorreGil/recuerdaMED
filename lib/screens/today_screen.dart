import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:recuerdamed/widgets/medication_card.dart';
import 'package:recuerdamed/services/notification_service.dart';

//Pantalla que sale después de iniciar sesión
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  bool _askedExact = false;

  String _dayId(DateTime d) {
    final yyyy = d.year.toString();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$yyyy$mm$dd';
  }

  String _weekdayEs(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Lunes';
      case DateTime.tuesday:
        return 'Martes';
      case DateTime.wednesday:
        return 'Miércoles';
      case DateTime.thursday:
        return 'Jueves';
      case DateTime.friday:
        return 'Viernes';
      case DateTime.saturday:
        return 'Sábado';
      case DateTime.sunday:
        return 'Domingo';
      default:
        return '';
    }
  }

  String _monthEs(int month) {
    switch (month) {
      case 1:
        return 'enero';
      case 2:
        return 'febrero';
      case 3:
        return 'marzo';
      case 4:
        return 'abril';
      case 5:
        return 'mayo';
      case 6:
        return 'junio';
      case 7:
        return 'julio';
      case 8:
        return 'agosto';
      case 9:
        return 'septiembre';
      case 10:
        return 'octubre';
      case 11:
        return 'noviembre';
      case 12:
        return 'diciembre';
      default:
        return '';
    }
  }

  String _prettyDate(DateTime d) {
    return '${_weekdayEs(d.weekday)} ${d.day} ${_monthEs(d.month)} ${d.year}';
  }

  bool _isMedicationActiveToday(Map<String, dynamic> data, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);

    final s = data['startDate'];
    final e = data['endDate'];

    DateTime? start;
    DateTime? end;

    if (s is Timestamp) start = s.toDate();
    if (e is Timestamp) end = e.toDate();

    if (start != null) {
      final sd = DateTime(start.year, start.month, start.day);
      if (sd.isAfter(today)) return false;
    }

    if (end != null) {
      final ed = DateTime(end.year, end.month, end.day);
      if (ed.isBefore(today)) return false;
    }

    return true;
  }

  Future<void> _setStatusForToday({
    required String uid,
    required String medicationId,
    required String name,
    required String dose,
    required String time,
    required String detail,
    required String status,
  }) async {
    final now = DateTime.now();
    final dayId = _dayId(now);
    final docId = '${medicationId}_$dayId';

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('history')
        .doc(docId)
        .set({
      'medicationId': medicationId,
      'name': name,
      'dose': dose,
      'time': time,
      'detail': detail,
      'status': status,
      'dayId': dayId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    Future.microtask(() async {
      if (_askedExact) return;
      _askedExact = true;

      final canExact = await NotificationService.instance.canExactAlarms();
      if (!canExact && context.mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Permiso necesario'),
            content: const Text(
              'Para que los recordatorios salten a la hora exacta, activa "Alarmas exactas" para la app.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Ahora no'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await NotificationService.instance.openExactAlarmsSettings();
                },
                child: const Text('Activar'),
              ),
            ],
          ),
        );
      }
    });

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFEFEFEF),
        body: SafeArea(
          child: Center(
            child: Text('No hay usuario logueado'),
          ),
        ),
      );
    }

    final now = DateTime.now();
    final todayId = _dayId(now);

    final medsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('medications');

    final historyRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('history');

    return Scaffold(
      backgroundColor: const Color(0xFFEFEFEF),

      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await NotificationService.instance.showNowTest(); // inmediata
          await NotificationService.instance.scheduleTestIn2Minutes(); // en 2 min
          final c = await NotificationService.instance.pendingCount();
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Pendientes: $c')),
          );
        },
        child: const Icon(Icons.notifications),
      ),

      body: SafeArea(
        child: Column(
          children: [
            //HEADER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              decoration: const BoxDecoration(
                color: Color(0xFF4CAF50),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(28),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hoy',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        _prettyDate(now),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            //RESUMEN (solo meds activos hoy)
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: medsRef.snapshots(),
              builder: (context, medsSnap) {
                final allDocs = medsSnap.data?.docs ?? [];
                final activeDocs = allDocs.where((d) {
                  return _isMedicationActiveToday(d.data(), now);
                }).toList();

                final totalActive = activeDocs.length;

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream:
                      historyRef.where('dayId', isEqualTo: todayId).snapshots(),
                  builder: (context, histSnap) {
                    int taken = 0;
                    int skipped = 0;

                    if (histSnap.hasData) {
                      for (final d in histSnap.data!.docs) {
                        final m = d.data();
                        final s = (m['status'] ?? '').toString();
                        if (s == 'taken') taken++;
                        if (s == 'skipped') skipped++;
                      }
                    }

                    final pending =
                        (totalActive - taken - skipped).clamp(0, 9999);

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _SummaryItem(
                              icon: Icons.error_outline,
                              color: Colors.orange,
                              value: pending.toString(),
                              label: 'Pendiente',
                            ),
                            _SummaryItem(
                              icon: Icons.check_circle_outline,
                              color: Colors.green,
                              value: taken.toString(),
                              label: 'Tomadas',
                            ),
                            _SummaryItem(
                              icon: Icons.cancel_outlined,
                              color: Colors.redAccent,
                              value: skipped.toString(),
                              label: 'Omitida',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 20),

            //LISTA (solo meds activos hoy)
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: medsRef.snapshots(),
                builder: (context, medsSnap) {
                  if (medsSnap.hasError) {
                    return const Center(
                        child: Text('Error cargando medicamentos'));
                  }
                  if (!medsSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allDocs = medsSnap.data!.docs;
                  final activeDocs = allDocs.where((d) {
                    return _isMedicationActiveToday(d.data(), now);
                  }).toList();

                  if (activeDocs.isEmpty) {
                    return const Center(
                      child: Text('No tienes medicamentos activos hoy'),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      const Text(
                        'Tus medicamentos de Hoy',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final doc in activeDocs)
                        _TodayMedicationRow(
                          uid: user.uid,
                          medicationId: doc.id,
                          data: doc.data(),
                          todayId: todayId,
                          historyRef: historyRef,
                          onSetStatus: _setStatusForToday,
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayMedicationRow extends StatelessWidget {
  const _TodayMedicationRow({
    required this.uid,
    required this.medicationId,
    required this.data,
    required this.todayId,
    required this.historyRef,
    required this.onSetStatus,
  });

  final String uid;
  final String medicationId;
  final Map<String, dynamic> data;
  final String todayId;
  final CollectionReference historyRef;

  final Future<void> Function({
    required String uid,
    required String medicationId,
    required String name,
    required String dose,
    required String time,
    required String detail,
    required String status,
  }) onSetStatus;

  @override
  Widget build(BuildContext context) {
    final name = (data['name'] ?? 'Sin nombre').toString();
    final dose = (data['dose'] ?? '').toString();
    final time = (data['time'] ?? '08:00').toString();
    final notes = (data['notes'] ?? '').toString();

    final detail = [
      if (dose.isNotEmpty) dose,
      if (notes.isNotEmpty) notes,
    ].join(' - ');

    final historyDocId = '${medicationId}_$todayId';

    return StreamBuilder<DocumentSnapshot>(
      stream: historyRef.doc(historyDocId).snapshots(),
      builder: (context, histSnap) {
        String? status; 

        if (histSnap.hasData && histSnap.data!.exists) {
          final m = histSnap.data!.data() as Map<String, dynamic>;
          final s = (m['status'] ?? '').toString();
          if (s == 'taken' || s == 'skipped') {
            status = s;
          }
        }

        final isPending = status == null;

        return MedicationCard(
          name: name,
          detail: detail.isEmpty ? dose : detail,
          time: time,
          status: status,
          onTaken: isPending
              ? () => onSetStatus(
                    uid: uid,
                    medicationId: medicationId,
                    name: name,
                    dose: dose,
                    time: time,
                    detail: detail,
                    status: 'taken',
                  )
              : null,
          onSkipped: isPending
              ? () => onSetStatus(
                    uid: uid,
                    medicationId: medicationId,
                    name: name,
                    dose: dose,
                    time: time,
                    detail: detail,
                    status: 'skipped',
                  )
              : null,
          onReset: !isPending
              ? () async {
                  await historyRef.doc(historyDocId).delete();
                }
              : null,
        );
      },
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}