import 'package:flutter/material.dart';

class BillingFlowPage extends StatefulWidget {
  const BillingFlowPage({
    super.key,
    required this.initialType,
    required this.initialDocumento,
    required this.initialComplemento,
    required this.initialRazonSocial,
  });

  final String initialType;
  final String initialDocumento;
  final String initialComplemento;
  final String initialRazonSocial;

  @override
  State<BillingFlowPage> createState() => _BillingFlowPageState();
}

class _BillingFlowPageState extends State<BillingFlowPage> {
  late String type;
  late final TextEditingController documentoCtrl;
  late final TextEditingController complementoCtrl;
  late final TextEditingController razonCtrl;

  @override
  void initState() {
    super.initState();
    type = widget.initialType;
    documentoCtrl = TextEditingController(text: widget.initialDocumento);
    complementoCtrl = TextEditingController(text: widget.initialComplemento);
    razonCtrl = TextEditingController(text: widget.initialRazonSocial);
  }

  @override
  void dispose() {
    documentoCtrl.dispose();
    complementoCtrl.dispose();
    razonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Datos de Facturación')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Paso 1: Tipo de dato', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'CI', label: Text('C.I.')),
              ButtonSegment(value: 'NIT', label: Text('NIT')),
            ],
            selected: {type},
            onSelectionChanged: (v) => setState(() => type = v.first),
          ),
          const SizedBox(height: 16),
          const Text('Paso 2: Completa los datos', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          TextField(
            controller: documentoCtrl,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              labelText: type == 'NIT' ? 'NIT' : 'C.I.',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          if (type == 'CI') ...[
            TextField(
              controller: complementoCtrl,
              decoration: const InputDecoration(
                labelText: 'Complemento (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
          ],
          TextField(
            controller: razonCtrl,
            decoration: InputDecoration(
              labelText: type == 'NIT' ? 'Razón Social' : 'Nombre completo (opcional)',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () {
              Navigator.pop(context, {
                'doc_type': type,
                'documento': documentoCtrl.text.trim(),
                'complemento': type == 'NIT' ? '' : complementoCtrl.text.trim(),
                'razon_social': razonCtrl.text.trim(),
              });
            },
            child: const Text('Guardar datos'),
          ),
        ],
      ),
    );
  }
}
