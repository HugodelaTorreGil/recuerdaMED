import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:recuerdamed/services/notification_service.dart';

//AVISO (Francis que no te entre nada malo por el cuerpo :) )
//Esta clase tiene tantas lineas de código porque la mayoría son partes del front que simplemente son visuales 
//De lógica hay 300 líneas 

class AddMedicationScreen extends StatefulWidget {
  const AddMedicationScreen({
    super.key,
    this.medicationId,
    this.initialData,
  });

  final String? medicationId; 
  final Map<String, dynamic>? initialData;

  bool get isEdit => medicationId != null;

  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  final _nameCtrl = TextEditingController();
  final _doseCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  int _weeklyDay = DateTime.monday;

  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);
  String _frequency = 'Diario';
  

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  bool _loading = false;
  bool _initialized = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _doseCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    if (!widget.isEdit) return;
    final data = widget.initialData;
    if (data == null) return;

    _nameCtrl.text = (data['name'] ?? '').toString();
    _doseCtrl.text = (data['dose'] ?? '').toString();
    _notesCtrl.text = (data['notes'] ?? '').toString();

    final timeStr = (data['time'] ?? '').toString().trim();
    final parsedTime = _parseTime(timeStr);
    if (parsedTime != null) _time = parsedTime;

    final freq = (data['frequency'] ?? '').toString();
    if (freq.isNotEmpty) _frequency = freq;

    final wd = data['weeklyDay'];
    if (wd is int && wd >= 1 && wd <= 7) {
      _weeklyDay = wd;
    }

    final s = data['startDate'];
    final e = data['endDate'];

    if (s is Timestamp) _startDate = s.toDate();
    if (e is Timestamp) _endDate = e.toDate();

    _startDate = DateTime(_startDate.year, _startDate.month, _startDate.day);
    _endDate = DateTime(_endDate.year, _endDate.month, _endDate.day);

    if (_endDate.isBefore(_startDate)) _endDate = _startDate;

    setState(() {});
  }

  TimeOfDay? _parseTime(String s) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(s);
    if (match == null) return null;
    final h = int.tryParse(match.group(1) ?? '');
    final m = int.tryParse(match.group(2) ?? '');
    if (h == null || m == null) return null;
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = d.year.toString();
    return '$dd/$mm/$yy';
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked != null) {
      setState(() => _time = picked);
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _startDate = DateTime(picked.year, picked.month, picked.day);
        if (_endDate.isBefore(_startDate)) _endDate = _startDate;
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _endDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final name = _nameCtrl.text.trim();
    final dose = _doseCtrl.text.trim();
    final notes = _notesCtrl.text.trim();

    if (name.isEmpty || dose.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rellena nombre y dosis')),
      );
      return;
    }

    if (_endDate.isBefore(_startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La fecha de fin no puede ser anterior a la de inicio'),
        ),
      );
      return;
    }

    //Si es activo hoy y la hora ya pasó y termina hoy => no habrá notificación
    final now = DateTime.now();
    final selectedTime = DateTime(
      now.year,
      now.month,
      now.day,
      _time.hour,
      _time.minute,
    );

    final startOnly = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final endOnly = DateTime(_endDate.year, _endDate.month, _endDate.day);
    final todayOnly = DateTime(now.year, now.month, now.day);

    final isActiveToday = !startOnly.isAfter(todayOnly) && !endOnly.isBefore(todayOnly);
    final timePassedToday = selectedTime.isBefore(now);

    if (isActiveToday && timePassedToday && endOnly.isAtSameMomentAs(todayOnly)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esa hora ya pasó hoy. Cambia la hora o amplía la fecha de fin.'),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final medsCol = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('medications');

      final payload = <String, dynamic>{
        'name': name,
        'dose': dose,
        'time': _formatTime(_time),
        'frequency': _frequency,
        'startDate': Timestamp.fromDate(_startDate),
        'endDate': Timestamp.fromDate(_endDate),
        'notes': notes,
        'updatedAt': FieldValue.serverTimestamp(),
        'weeklyDay': _frequency == 'Semanal' ? _weeklyDay : null,
      };

      if (widget.isEdit) {
        //1) Cancelar notificaciones anteriores
        final old = widget.initialData ?? {};
        final oldTime = (old['time'] ?? '').toString();
        final oldFreq = (old['frequency'] ?? 'Diario').toString();

        final oldStartTs = old['startDate'];
        final oldEndTs = old['endDate'];

        DateTime oldStart = _startDate;
        DateTime oldEnd = _endDate;

        if (oldStartTs is Timestamp) oldStart = oldStartTs.toDate();
        if (oldEndTs is Timestamp) oldEnd = oldEndTs.toDate();

        oldStart = DateTime(oldStart.year, oldStart.month, oldStart.day);
        oldEnd = DateTime(oldEnd.year, oldEnd.month, oldEnd.day);

        if (oldTime.isNotEmpty) {
          await NotificationService.instance.cancelBetweenDates(
            medicationId: widget.medicationId!,
            timeHHmm: oldTime,
            frequency: oldFreq,
            weeklyDay: oldFreq == 'Semanal' ? (old['weeklyDay'] as int?) : null,
            startDate: oldStart,
            endDate: oldEnd,
          );
        }

        //2) Guardar cambios
        await medsCol.doc(widget.medicationId!).update(payload);

        //3) Programar nuevas (con frecuencia)
        await NotificationService.instance.scheduleBetweenDates(
          medicationId: widget.medicationId!,
          title: name,
          body: dose,
          timeHHmm: _formatTime(_time),
          frequency: _frequency,
          weeklyDay: _frequency == 'Semanal' ? _weeklyDay : null,
          startDate: _startDate,
          endDate: _endDate,
        );

        final c = await NotificationService.instance.pendingCount();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pendientes programadas: $c')),
        );
      } else {
        //ADD: necesito tener el ID antes
        final newDoc = medsCol.doc();
        await newDoc.set({
          ...payload,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await NotificationService.instance.scheduleBetweenDates(
          medicationId: newDoc.id,
          title: name,
          body: dose,
          timeHHmm: _formatTime(_time),
          frequency: _frequency,
          startDate: _startDate,
          endDate: _endDate,
        );

        final c = await NotificationService.instance.pendingCount();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pendientes programadas: $c')),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isEdit ? 'Cambios guardados' : 'Medicamento añadido'),
        ),
      );
      Navigator.pop(context);
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error guardando: ${e.code}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openNotesDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Instrucciones especiales'),
        content: TextField(
          controller: _notesCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Ej: Tomar con comida, no mezclar con alcohol...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Listo'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isEdit ? 'Editar medicamento' : 'Añadir medicamento';
    final saveText = widget.isEdit ? 'Guardar cambios' : 'Añadir Medicamento';

    return Scaffold(
      backgroundColor: const Color(0xFFEFEFEF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4CAF50),
        elevation: 0,
        leading: IconButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: Text(
          title,
          style: const TextStyle(
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
                child: _RealTextField(
                  controller: _nameCtrl,
                  hint: 'Ej: Paracetamol',
                ),
              ),
              const SizedBox(height: 14),
              _FormCard(
                icon: Icons.local_hospital_outlined,
                title: 'Dosis',
                child: _RealTextField(
                  controller: _doseCtrl,
                  hint: 'Ej: 500mg',
                ),
              ),
              const SizedBox(height: 14),
              _FormCard(
                icon: Icons.access_time,
                title: 'Hora de la toma',
                child: _TapDropdown(
                  value: _formatTime(_time),
                  onTap: _pickTime,
                ),
              ),
              const SizedBox(height: 14),
              _FormCard(
                icon: Icons.autorenew,
                title: 'Frecuencia',
                child: _FrequencyDropdown(
                  value: _frequency,
                  onChanged: (v) => setState(() => _frequency = v),
                ),
              ),
              if (_frequency == 'Semanal') ...[
                const SizedBox(height: 14),
                _FormCard(
                  icon: Icons.event_repeat,
                  title: 'Día de la semana',
                  child: _WeeklyDayDropdown(
                    value: _weeklyDay,
                    onChanged: (v) => setState(() => _weeklyDay = v),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              _FormCard(
                icon: Icons.calendar_today_outlined,
                title: 'Fecha de inicio',
                child: Column(
                  children: [
                    _TapTextField(
                      text: _formatDate(_startDate),
                      onTap: _pickStartDate,
                    ),
                    const SizedBox(height: 10),
                    const _RowLabel(
                      icon: Icons.calendar_today_outlined,
                      text: 'Fecha de fin',
                    ),
                    const SizedBox(height: 8),
                    _TapTextField(
                      text: _formatDate(_endDate),
                      onTap: _pickEndDate,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: _loading ? null : _openNotesDialog,
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
                  onPressed: _loading ? null : _save,
                  icon: const Icon(Icons.save_outlined, color: Colors.white),
                  label: Text(
                    _loading ? 'Guardando...' : saveText,
                    style: const TextStyle(
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

class _RealTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  const _RealTextField({
    required this.controller,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 13),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFBDBDBD)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 1.5),
        ),
      ),
    );
  }
}

class _TapTextField extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _TapTextField({
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 42,
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
                text,
                style: const TextStyle(fontSize: 13, color: Color(0xFF37474F)),
              ),
            ),
            const Icon(Icons.calendar_month, color: Color(0xFF37474F), size: 18),
          ],
        ),
      ),
    );
  }
}

class _TapDropdown extends StatelessWidget {
  final String value;
  final VoidCallback onTap;

  const _TapDropdown({
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
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
      ),
    );
  }
}

class _FrequencyDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _FrequencyDropdown({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final items = const ['Diario', 'Cada 8 horas', 'Cada 12 horas', 'Semanal'];

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBDBDBD)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF37474F)),
          items: items
              .map(
                (e) => DropdownMenuItem<String>(
                  value: e,
                  child: Text(
                    e,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF37474F)),
                  ),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
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

class _WeeklyDayDropdown extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _WeeklyDayDropdown({
    required this.value,
    required this.onChanged,
  });

  String _label(int d) {
    switch (d) {
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
        return 'Lunes';
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = <int>[
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
      DateTime.saturday,
      DateTime.sunday,
    ];

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBDBDBD)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF37474F)),
          items: items
              .map(
                (d) => DropdownMenuItem<int>(
                  value: d,
                  child: Text(
                    _label(d),
                    style: const TextStyle(fontSize: 13, color: Color(0xFF37474F)),
                  ),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}