import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0E0E0),
      body: SafeArea(
        child: Column(
          children: [
            //HEADER VERDE
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
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
                    'Historial',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.trending_up, color: Colors.white),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Adherencia general',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 6),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '71%',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Padding(
                                    padding: EdgeInsets.only(bottom: 3),
                                    child: Text(
                                      '(2 tomadas, 1 omitida, 1 pendiente)',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            //CUERPO
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                children: const [
                  _FilterHeader(),
                  SizedBox(height: 14),

                  _DayHeader(text: 'Martes, 27 de Enero de 2026'),
                  SizedBox(height: 10),
                  _HistoryItem(
                    name: 'Paracetamol',
                    dose: '500mg',
                    time: '08:00',
                    status: 'Tomada',
                    statusColor: Colors.green,
                    borderColor: Colors.green,
                    icon: Icons.check,
                    iconColor: Colors.green,
                  ),
                  _HistoryItem(
                    name: 'Omeprazol',
                    dose: '20mg',
                    time: '09:00',
                    status: 'Tomada',
                    statusColor: Colors.green,
                    borderColor: Colors.green,
                    icon: Icons.check,
                    iconColor: Colors.green,
                  ),

                  SizedBox(height: 14),

                  _DayHeader(text: 'Lunes, 26 de Enero de 2026'),
                  SizedBox(height: 10),
                  _HistoryItem(
                    name: 'Paracetamol',
                    dose: '500mg',
                    time: '08:00',
                    status: 'Tomada',
                    statusColor: Colors.green,
                    borderColor: Colors.green,
                    icon: Icons.check,
                    iconColor: Colors.green,
                  ),
                  _HistoryItem(
                    name: 'Vitamina D',
                    dose: '500mg',
                    time: '12:00',
                    status: 'Omitida',
                    statusColor: Colors.redAccent,
                    borderColor: Colors.redAccent,
                    icon: Icons.close,
                    iconColor: Colors.redAccent,
                  ),

                  SizedBox(height: 14),

                  _DayHeader(text: 'Domingo, 25 de Enero de 2026'),
                  SizedBox(height: 10),
                  _HistoryItem(
                    name: 'Paracetamol',
                    dose: '500mg',
                    time: '08:00',
                    status: 'Tomada',
                    statusColor: Colors.green,
                    borderColor: Colors.green,
                    icon: Icons.check,
                    iconColor: Colors.green,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =================================================
//                    COMPONENTES
// =================================================

class _FilterHeader extends StatelessWidget {
  const _FilterHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.filter_alt_outlined, color: Colors.grey),
            SizedBox(width: 10),
            Text(
              'Filtrar por:',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Row(
          children: const [
            _FilterChip(text: 'Todas', selected: true),
            SizedBox(width: 12),
            _FilterChip(text: 'Tomadas'),
            SizedBox(width: 12),
            _FilterChip(text: 'Omitidas'),
          ],
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String text;
  final bool selected;

  const _FilterChip({
    required this.text,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color green = const Color(0xFF4CAF50);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? green : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: selected ? green : const Color(0xFFBDBDBD)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: selected ? Colors.white : const Color(0xFF757575),
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  final String text;

  const _DayHeader({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.calendar_today_outlined,
            size: 18, color: Colors.grey),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final String name;
  final String dose;
  final String time;
  final String status;
  final Color statusColor;
  final Color borderColor;
  final IconData icon;
  final Color iconColor;

  const _HistoryItem({
    required this.name,
    required this.dose,
    required this.time,
    required this.status,
    required this.statusColor,
    required this.borderColor,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: borderColor, width: 4),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  dose,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                time,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                status,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
