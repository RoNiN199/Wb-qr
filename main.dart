import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

void main() => runApp(const QrLabelApp());

class QrLabelApp extends StatelessWidget {
  const QrLabelApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'QR этикетки',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
        home: const HomePage(),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _controller = TextEditingController();
  final _labelKey = GlobalKey();
  final List<String> _history = [];
  String _code = '';

  // Размер этикетки в мм. Поменяйте под свой рулон.
  static const double _labelW = 58;
  static const double _labelH = 40;

  void _generate() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _code = value;
      _history.remove(value);
      _history.insert(0, value);
      if (_history.length > 20) _history.removeLast();
    });
  }

  Future<void> _share() async {
    final boundary =
        _labelKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 4);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/label_$_code.png');
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    await Share.shareXFiles([XFile(file.path)]);
  }

  Future<void> _print() async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          _labelW * PdfPageFormat.mm,
          _labelH * PdfPageFormat.mm,
          marginAll: 2 * PdfPageFormat.mm,
        ),
        build: (_) => pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: _code,
                width: 80,
                height: 80,
              ),
              pw.SizedBox(height: 4),
              pw.Text(_code, style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (_) => doc.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR этикетки')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _generate(),
            decoration: InputDecoration(
              labelText: 'Номер ШК',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: _controller.clear,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _generate,
            icon: const Icon(Icons.qr_code_2),
            label: const Text('Создать'),
          ),
          if (_code.isNotEmpty) ...[
            const SizedBox(height: 24),
            Center(
              child: RepaintBoundary(
                key: _labelKey,
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      QrImageView(data: _code, size: 200),
                      const SizedBox(height: 4),
                      Text(
                        _code,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _print,
                    icon: const Icon(Icons.print),
                    label: const Text('Печать'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _share,
                    icon: const Icon(Icons.share),
                    label: const Text('Поделиться'),
                  ),
                ),
              ],
            ),
          ],
          if (_history.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Недавние', style: Theme.of(context).textTheme.titleMedium),
            for (final c in _history)
              ListTile(
                dense: true,
                title: Text(c),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _controller.text = c;
                  _generate();
                },
              ),
          ],
        ],
      ),
    );
  }
}
