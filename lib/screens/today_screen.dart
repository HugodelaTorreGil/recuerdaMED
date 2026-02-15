import 'package:flutter/material.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFEFEF),
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
                children: const [
                  Text(
                    'Hoy',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 18, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Jueves 29 enero 2026',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            //RESUMEN
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: const [
                    _SummaryItem(
                      icon: Icons.error_outline,
                      color: Colors.orange,
                      value: '1',
                      label: 'Pendiente',
                    ),
                    _SummaryItem(
                      icon: Icons.check_circle_outline,
                      color: Colors.green,
                      value: '2',
                      label: 'Tomadas',
                    ),
                    _SummaryItem(
                      icon: Icons.cancel_outlined,
                      color: Colors.redAccent,
                      value: '1',
                      label: 'Omitida',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            //LISTA
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: const [
                  Text(
                    'Tus medicamentos de Hoy',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 12),

                  _MedicationCard(
                    name: 'Paracetamol',
                    detail: '500mg · Tomar con alimentos',
                    time: '08:00',
                    statusText: 'Medicación tomada',
                    statusColor: Colors.green,
                    borderColor: Colors.green,
                    showAction: false,
                  ),

                  _MedicationCard(
                    name: 'Omeprazol',
                    detail: '20mg · 1 cápsula · Antes del desayuno',
                    time: '09:00',
                    action: true,
                  ),

                  _MedicationCard(
                    name: 'Vitamina D',
                    detail: '1000 UI · 1 cápsula',
                    time: '12:00',
                    statusText: 'Medicación omitida',
                    statusColor: Colors.redAccent,
                    borderColor: Colors.redAccent,
                    showAction: false,
                  ),

                  _MedicationCard(
                    name: 'Ibuprofeno',
                    detail: '400mg · Después de comer',
                    time: '08:00',
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
//                     WIDGETS
// =================================================

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _SummaryItem({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            )),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _MedicationCard extends StatelessWidget {
  final String name;
  final String detail;
  final String time;
  final bool action;
  final bool showAction;
  final String? statusText;
  final Color? statusColor;
  final Color? borderColor;

  const _MedicationCard({
    required this.name,
    required this.detail,
    required this.time,
    this.action = false,
    this.showAction = true,
    this.statusText,
    this.statusColor,
    this.borderColor,
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
          left: BorderSide(
            color: borderColor ?? Colors.green,
            width: 4,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(time),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 13,
            ),
          ),
          if (statusText != null) ...[
            const SizedBox(height: 8),
            Text(
              statusText!,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (action) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.check),
                    label: const Text('Marcar como tomada'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      disabledBackgroundColor: const Color(0xFF4CAF50),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: null,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
