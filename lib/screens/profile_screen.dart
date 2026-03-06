import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:recuerdamed/services/notification_service.dart';
import 'package:recuerdamed/screens/credits_screen.dart';
import 'package:recuerdamed/screens/edit_profile_screen.dart';

//Perfil del usuario
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  String _dayId(DateTime d) {
    final yyyy = d.year.toString();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$yyyy$mm$dd';
  }

  DateTime? _dateFromDayId(String s) {
    // Formato esperado: yyyymmdd
    if (s.length != 8) return null;
    final y = int.tryParse(s.substring(0, 4));
    final m = int.tryParse(s.substring(4, 6));
    final d = int.tryParse(s.substring(6, 8));
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFEFEFEF),
        body: SafeArea(child: Center(child: Text('No hay usuario logueado'))),
      );
    }

    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final medsRef = userRef.collection('medications');
    final historyRef = userRef.collection('history');

    final now = DateTime.now();
    final todayId = _dayId(now);

    //Yo tiro de 60 días para poder calcular racha sin quedarme corto.
    final since60 = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 60));
    final since30 = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30));

    return Scaffold(
      backgroundColor: const Color(0xFFE0E0E0),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: userRef.snapshots(),
          builder: (context, userSnap) {
            final data = userSnap.data?.data() ?? {};
            final displayName = (data['displayName'] ?? user.displayName ?? 'Usuario').toString();
            final email = (user.email ?? data['email'] ?? '').toString();

            return Column(
              children: [
                // HEADER
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
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
                        'Mi Perfil',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person_outline,
                              size: 34,
                              color: Color(0xFF4CAF50),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  email,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                //STATS reales
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: medsRef.snapshots(),
                      builder: (context, medsSnap) {
                        final medsDocs = medsSnap.data?.docs ?? [];
                        final activeMeds = medsDocs.where((d) => _isMedicationActiveToday(d.data(), now)).length;

                        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          //Uso createdAt/updatedAt para acotar por rango.
                          //Si algún doc antiguo no tiene createdAt, lo cuento igual usando dayId si existe.
                          stream: historyRef
                              .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since60))
                              .snapshots(),
                          builder: (context, histSnap) {
                            final histDocs = histSnap.data?.docs ?? [];

                            //1) ADHERENCIA 30 días
                            int taken30 = 0;
                            int skipped30 = 0;

                            //2) RACHA
                            //Agrupo por dayId => {taken, skipped}
                            final Map<String, _DayAgg> byDay = <String, _DayAgg>{};

                            for (final d in histDocs) {
                              final m = d.data();

                              final status = (m['status'] ?? '').toString();
                              final dayId = (m['dayId'] ?? '').toString();

                              //Fechas (para filtrar 30 días). Si falta createdAt, uso updatedAt.
                              DateTime? ts;
                              final c = m['createdAt'];
                              final u = m['updatedAt'];
                              if (c is Timestamp) ts = c.toDate();
                              if (ts == null && u is Timestamp) ts = u.toDate();

                              //Adherencia 30 días:
                              if (ts != null && !ts.isBefore(since30)) {
                                if (status == 'taken') taken30++;
                                if (status == 'skipped') skipped30++;
                              } else if (ts == null) {
                                //Si no hay timestamps, al menos no rompo nada.
                                //No lo cuento en adherencia para no inventar rango.
                              }

                              //Racha (por dayId):
                              if (dayId.isNotEmpty) {
                                final agg = byDay.putIfAbsent(dayId, () => _DayAgg());
                                if (status == 'taken') agg.taken++;
                                if (status == 'skipped') agg.skipped++;
                              }
                            }

                            final total30 = taken30 + skipped30;
                            final adherencePct = total30 == 0 ? 0 : ((taken30 / total30) * 100).round();

                            //Defino “día bueno” como: tuvo al menos un taken y 0 skipped.
                            int streak = 0;
                            DateTime cursor = DateTime(now.year, now.month, now.day);

                            while (true) {
                              final id = _dayId(cursor);

                              //Si hoy no hay entradas, racha = 0 y paro (es lo típico en apps).
                              final agg = byDay[id];
                              if (agg == null) break;

                              final goodDay = agg.taken > 0 && agg.skipped == 0;
                              if (!goodDay) break;

                              streak++;
                              cursor = cursor.subtract(const Duration(days: 1));

                              //Por seguridad, no me vuelvo loco si algo falla
                              if (streak > 365) break;
                            }

                            return Row(
                              children: [
                                Expanded(
                                  child: _StatItem(
                                    value: activeMeds.toString(),
                                    label: 'Medicamentos\nactivos',
                                    valueColor: Colors.black,
                                  ),
                                ),
                                const _DividerLine(),
                                Expanded(
                                  child: _StatItem(
                                    value: '$adherencePct%',
                                    label: 'Adherencia\n(30 días)',
                                    valueColor: const Color(0xFF4CAF50),
                                  ),
                                ),
                                const _DividerLine(),
                                Expanded(
                                  child: _StatItem(
                                    value: streak.toString(),
                                    label: 'Días seguidos',
                                    valueColor: const Color(0xFF4CAF50),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      const Text(
                        'Configuración',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),

                      _ConfigItem(
                        icon: Icons.person_outline,
                        text: 'Editar Perfil',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                          );
                        },
                      ),
                      _ConfigItem(
                        icon: Icons.copyright,
                        text: 'Créditos',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CreditsScreen()),
                          );
                        },
                      ),
                      _ConfigItem(
                        icon: Icons.notifications_none,
                        text: 'Notificaciones (test 2 min)',
                        onTap: () async {
                          await NotificationService.instance.scheduleTestIn2Minutes();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Test programado en 2 minutos')),
                          );
                        },
                      ),

                      const SizedBox(height: 26),

                      const _LogoutButton(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DayAgg {
  int taken = 0;
  int skipped = 0;
}

// =================================================
// COMPONENTES
// =================================================

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;

  const _StatItem({
    required this.value,
    required this.label,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DividerLine extends StatelessWidget {
  const _DividerLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 42,
      color: const Color(0xFFE0E0E0),
    );
  }
}

class _ConfigItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _ConfigItem({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFFEFEFEF),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF4CAF50)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton.icon(
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Cerrar sesión'),
                content: const Text('¿Seguro que quieres cerrar sesión?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Salir'),
                  ),
                ],
              ),
            );

            if (ok == true) {
              await FirebaseAuth.instance.signOut();
            }
          },
          icon: const Icon(Icons.logout, color: Colors.redAccent),
          label: const Text(
            'Cerrar Sesión',
            style: TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.redAccent, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}