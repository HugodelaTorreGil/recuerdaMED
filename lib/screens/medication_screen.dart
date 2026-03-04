import 'package:flutter/material.dart';
import 'add_medication_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:recuerdamed/services/notification_service.dart';

class MedicationScreen extends StatefulWidget {
  const MedicationScreen({super.key});

  @override
  State<MedicationScreen> createState() => _MedicationScreenState();
}

class _MedicationScreenState extends State<MedicationScreen> {
  String _query = '';

  Future<bool> _confirmDelete(BuildContext context, String name) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Borrar medicamento'),
        content: Text('¿Seguro que quieres borrar "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  Future<void> _deleteMedication({
    required String uid,
    required String medicationId,
  }) async {
    final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);
    final medRef = userDoc.collection('medications').doc(medicationId);

    // 1) Borra el medicamento
    await medRef.delete();

    // 2) (Opcional) Borra registros de history de ese medicamento
    // Si tienes muchos registros, esto no escala (pero para DAM va perfecto).
    final historyQuery = await userDoc
        .collection('history')
        .where('medicationId', isEqualTo: medicationId)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (final d in historyQuery.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('No hay usuario logueado')),
      );
    }

    final medsStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('medications')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFFEFEFEF),
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
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
                    'Mis medicamentos',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      onChanged: (v) => setState(() {
                        _query = v.trim().toLowerCase();
                      }),
                      decoration: const InputDecoration(
                        hintText: 'Buscar medicamento...',
                        hintStyle: TextStyle(
                          color: Color(0xFF9E9E9E),
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(Icons.search, color: Color(0xFF9E9E9E)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: medsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final docs = snapshot.data?.docs ?? [];

                  final filtered = docs.where((d) {
                    final data = d.data();
                    final name = (data['name'] ?? '').toString().toLowerCase();
                    if (_query.isEmpty) return true;
                    return name.contains(_query);
                  }).toList();

                  return Column(
                    children: [
                      // RESUMEN + BOTÓN ADD
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            const Icon(Icons.medication_outlined,
                                color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${docs.length} Medicamentos registrados',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 14),
                              ),
                            ),
                            InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AddMedicationScreen(),
                                  ),
                                );
                              },
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF4CAF50),
                                  shape: BoxShape.circle,
                                ),
                                child:
                                    const Icon(Icons.add, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(
                                child: Text(
                                  'No hay medicamentos',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )
                            : ListView.builder(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final doc = filtered[index];
                                  final data = doc.data();

                                  final name =
                                      (data['name'] ?? '').toString();
                                  final dose =
                                      (data['dose'] ?? '').toString();
                                  final freq =
                                      (data['frequency'] ?? '').toString();
                                  final time =
                                      (data['time'] ?? '').toString();

                                  return _MedicationTile(
                                    name: name,
                                    dose: dose,
                                    tagLeft: freq,
                                    tagRight: time,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => AddMedicationScreen(
                                            medicationId: doc.id,
                                            initialData: data,
                                          ),
                                        ),
                                      );
                                    },
                                    onDelete: () async {
                                      final ok = await _confirmDelete(context, name);
                                      if (!ok) return;

                                      // AÑADE ESTO AQUÍ
                                      final s = data['startDate'];
                                      final e = data['endDate'];

                                      DateTime start = DateTime.now();
                                      DateTime end = DateTime.now();

                                      if (s is Timestamp) start = s.toDate();
                                      if (e is Timestamp) end = e.toDate();

                                      await NotificationService.instance.cancelScheduledBetweenDates(
                                        medicationId: doc.id,
                                        timeHHmm: time,
                                        frequency: freq,
                                        startDate: DateTime(start.year, start.month, start.day),
                                        endDate: DateTime(end.year, end.month, end.day),
                                      );

                                      // y luego tu borrado actual
                                      await _deleteMedication(
                                        uid: user.uid,
                                        medicationId: doc.id,
                                      );
                                    },
                                  );
                                },
                              ),
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

// =================================================
//                    CARD ITEM
// =================================================

class _MedicationTile extends StatelessWidget {
  final String name;
  final String dose;
  final String tagLeft;
  final String tagRight;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _MedicationTile({
    required this.name,
    required this.dose,
    required this.tagLeft,
    required this.tagRight,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF2F2F2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.medication_outlined,
                    color: Color(0xFF4CAF50),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? '(Sin nombre)' : name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dose,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _ChipTag(text: tagLeft),
                const SizedBox(width: 8),
                _ChipTag(text: tagRight),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipTag extends StatelessWidget {
  final String text;

  const _ChipTag({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          color: Colors.grey,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}