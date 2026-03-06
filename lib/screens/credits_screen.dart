import 'package:flutter/material.dart';

//Créditos
class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

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
          'Créditos',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Card(
                title: 'RecuerdaMED',
                body:
                    'Aplicación de recordatorios de medicación con historial y control de tomas.',
              ),
              SizedBox(height: 14),
              _Card(
                title: 'Desarrollo',
                body: 'Hugo de la Torre Gil, 2º CFGS Desarrollo de Aplicaciones Multiplataforma',
              ),
              SizedBox(height: 14),
              _Card(
                title: 'Tecnologías',
                body:
                    'Flutter • Firebase Auth • Cloud Firestore • flutter_local_notifications',
              ),
              SizedBox(height: 14),
              _Card(
                title: 'Icono / Recursos',
                body: 'Recursos propios de Flutter .',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final String body;

  const _Card({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(color: Colors.black87),
          ),
        ],
      ),
    );
  }
}