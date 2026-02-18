import 'dart:io';

import 'package:dio/dio.dart';
import 'package:e2v_app/src/core/ui/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaymentWebViewModal extends StatefulWidget {
  const PaymentWebViewModal({super.key, required this.url, this.title = 'Pasarela Libélula'});
  final String url;
  final String title;

  @override
  State<PaymentWebViewModal> createState() => _PaymentWebViewModalState();
}

class _PaymentWebViewModalState extends State<PaymentWebViewModal> {
  late final WebViewController _controller;
  int progress = 0;
  bool _downloading = false;

  bool _looksLikeDownload(String url) {
    final u = url.toLowerCase();
    return u.contains('download') ||
        u.contains('descargar') ||
        u.endsWith('.pdf') ||
        u.endsWith('.xml') ||
        u.endsWith('.png') ||
        u.endsWith('.jpg') ||
        u.endsWith('.jpeg') ||
        u.endsWith('.webp');
  }

  Future<String> _fileNameFromUrl(String url, {String fallbackExt = 'bin'}) async {
    try {
      final uri = Uri.parse(url);
      final last = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      if (last.isNotEmpty && last.contains('.')) return last;
    } catch (_) {}
    final ts = DateTime.now().millisecondsSinceEpoch;
    return 'descarga_$ts.$fallbackExt';
  }

  Future<void> _downloadToDownloads(String url) async {
    if (_downloading) return;
    setState(() => _downloading = true);

    try {
      if (Platform.isAndroid) {
        final storage = await Permission.storage.request();
        if (!mounted) return;
        if (!storage.isGranted && !storage.isLimited) {
          showAppToast(context, 'Permiso de almacenamiento denegado', type: AppToastType.error);
          setState(() => _downloading = false);
          return;
        }
      }

      String cookieHeader = '';
      try {
        final cookieJs = await _controller.runJavaScriptReturningResult('document.cookie');
        cookieHeader = cookieJs.toString().replaceAll('"', '').replaceAll("'", '');
      } catch (_) {}

      final ext = url.toLowerCase().contains('.pdf')
          ? 'pdf'
          : url.toLowerCase().contains('.xml')
              ? 'xml'
              : url.toLowerCase().contains('.png')
                  ? 'png'
                  : url.toLowerCase().contains('.jpg') || url.toLowerCase().contains('.jpeg')
                      ? 'jpg'
                      : 'bin';
      final fileName = await _fileNameFromUrl(url, fallbackExt: ext);
      final downloadDir = Directory('/storage/emulated/0/Download');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      final savePath = '${downloadDir.path}/$fileName';

      await Dio().download(
        url,
        savePath,
        options: Options(
          followRedirects: true,
          validateStatus: (s) => s != null && s < 500,
          headers: cookieHeader.isNotEmpty ? {'Cookie': cookieHeader} : null,
          responseType: ResponseType.bytes,
        ),
      );

      if (!mounted) return;
      showAppToast(context, 'Descarga completada: $fileName', type: AppToastType.success);
    } catch (e) {
      if (!mounted) return;
      showAppToast(context, 'No se pudo descargar: $e', type: AppToastType.error);
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => setState(() => progress = p),
          onNavigationRequest: (request) {
            if (_looksLikeDownload(request.url)) {
              _downloadToDownloads(request.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(14),
      child: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.82,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    tooltip: 'Abrir externo (fallback)',
                    onPressed: () async {
                      final uri = Uri.tryParse(widget.url);
                      if (uri != null) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.open_in_new),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            LinearProgressIndicator(value: progress < 100 ? progress / 100 : 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: _downloading
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.download_for_offline_outlined),
                  label: Text(_downloading ? 'Descargando...' : 'Descargar en Descargas'),
                  onPressed: _downloading ? null : () => _downloadToDownloads(widget.url),
                ),
              ),
            ),
            Expanded(child: WebViewWidget(controller: _controller)),
          ],
        ),
      ),
    );
  }
}
