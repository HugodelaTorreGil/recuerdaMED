import 'package:flutter/material.dart';

class AddMedicationScreen extends StatelessWidget {
  const AddMedicationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFEFEF),

      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: const Text(
          'Añadir medicamento',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              _FormCard(
                icon: Icons.medication_outlined,
                title: 'Nombre del medicamento',
                child: const _FakeTextField(hint: 'Ej: Paracetamol'),
              ),
              const SizedBox(height: 14),

              _FormCard(
                icon: Icons.local_hospital_outlined,
                title: 'Dosis',
                child: const _FakeTextField(hint: 'Ej: 500mg'),
              ),
              const SizedBox(height: 14),

              _FormCard(
                icon: Icons.access_time,
                title: 'Hora de la toma',
                child: const _FakeDropdown(value: '08:00'),
              ),
              const SizedBox(height: 14),

              _FormCard(
                icon: Icons.autorenew,
                title: 'Frecuencia',
                child: const _FakeDropdown(value: 'Diario'),
              ),
              const SizedBox(height: 14),

              _FormCard(
                icon: Icons.calendar_today_outlined,
                title: 'Fecha de inicio',
                child: Column(
                  children: const [
                    _FakeTextField(hint: '29/01/2026', filled: true),
                    SizedBox(height: 10),
                    _RowLabel(icon: Icons.calendar_today_outlined, text: 'Fecha de fin'),
                    SizedBox(height: 8),
                    _FakeTextField(hint: '29/01/2026', filled: true),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    disabledBackgroundColor: const Color(0xFF4CAF50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Instrucciones Especiales',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.save_outlined, color: Colors.white),
                  label: const Text(
                    'Añadir Medicamento',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    disabledBackgroundColor: const Color(0xFF4CAF50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =================================================
// ================== COMPONENTES ==================
// =================================================

class _FormCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _FormCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF4CAF50)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _FakeTextField extends StatelessWidget {
  final String hint;
  final bool filled;

  const _FakeTextField({
    required this.hint,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      enabled: false, 
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 13),
        filled: true,
        fillColor: filled ? const Color(0xFFF2F2F2) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFBDBDBD)),
        ),
      ),
    );
  }
}

class _FakeDropdown extends StatelessWidget {
  final String value;

  const _FakeDropdown({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBDBDBD)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Color(0xFF37474F)),
            ),
          ),
          const Icon(Icons.arrow_drop_down, color: Color(0xFF37474F)),
        ],
      ),
    );
  }
}

class _RowLabel extends StatelessWidget {
  final IconData icon;
  final String text;

  const _RowLabel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF4CAF50), size: 18),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
