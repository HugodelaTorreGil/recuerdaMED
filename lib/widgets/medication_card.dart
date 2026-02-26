import 'package:flutter/material.dart';

class MedicationCard extends StatelessWidget {
  const MedicationCard({
    super.key,
    required this.name,
    required this.detail,
    required this.time,
    required this.status, // null | "taken" | "skipped"
    required this.onTaken,
    required this.onSkipped,
    required this.onReset, // NUEVO
  });

  final String name;
  final String detail;
  final String time;
  final String? status;
  final VoidCallback? onTaken;
  final VoidCallback? onSkipped;
  final VoidCallback? onReset;

  Color _borderColor() {
    if (status == 'taken') return Colors.green;
    if (status == 'skipped') return Colors.redAccent;
    return const Color(0xFF4CAF50);
  }

  IconData _rightIcon() {
    if (status == 'taken') return Icons.check;
    if (status == 'skipped') return Icons.close;
    return Icons.access_time;
  }

  Color _rightIconColor() {
    if (status == 'taken') return Colors.green;
    if (status == 'skipped') return Colors.redAccent;
    return Colors.grey;
  }

  IconData _leftIcon() => Icons.medication_outlined;

  String? _statusText() {
    if (status == 'taken') return 'Medicación tomada';
    if (status == 'skipped') return 'Medicación omitida';
    return null;
  }

  Color _statusTextColor() {
    if (status == 'taken') return Colors.green;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    final statusText = _statusText();
    final isPending = status == null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(
            color: _borderColor(),
            width: 4,
          ),
        ),
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
                child: Icon(
                  _leftIcon(),
                  color: const Color(0xFF4CAF50),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      detail,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(_rightIcon(), color: _rightIconColor()),
              const SizedBox(width: 6),
              Text(
                time,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),

          if (statusText != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  status == 'taken' ? Icons.check : Icons.close,
                  color: _statusTextColor(),
                ),
                const SizedBox(width: 8),
                Text(
                  statusText,
                  style: TextStyle(
                    color: _statusTextColor(),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],

          // PENDIENTE -> botones (tomada / omitida)
          if (isPending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: ElevatedButton.icon(
                      onPressed: onTaken,
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: const Text(
                        'Marcar como tomada',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: onSkipped,
                    icon: const Icon(Icons.close, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ],

          // MARCADA -> solo reset
          if (!isPending) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: OutlinedButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.refresh),
                label: const Text(
                  'Resetear',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}