import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:e2v_app/src/core/ui/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
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

  Future<void> _showDownloadedDialog(String fileName) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Descarga completada'),
        content: Text('Archivo guardado: $fileName'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _downloadToDownloads(String url) async {
    if (_downloading) return;
    setState(() => _downloading = true);

    try {
      if (Platform.isAndroid) {
        final storage = await Permission.storage.request();
        final photos = await Permission.photos.request();
        if (!mounted) return;
        final okStorage = storage.isGranted || storage.isLimited;
        final okPhotos = photos.isGranted || photos.isLimited;
        if (!okStorage && !okPhotos) {
          showAppToast(context, 'Permiso de almacenamiento/galería denegado', type: AppToastType.error);
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
      final picsDir = Directory('/storage/emulated/0/Pictures');
      if (!await picsDir.exists()) {
        await picsDir.create(recursive: true);
      }
      final savePathPictures = '${picsDir.path}/$fileName';

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
      try {
        await File(savePath).copy(savePathPictures);
      } catch (_) {}

      await _showDownloadedDialog(fileName);
    } catch (e) {
      if (!mounted) return;
      showAppToast(context, 'No se pudo descargar: $e', type: AppToastType.error);
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _downloadQrFromDom() async {
    try {
      final raw = await _controller.runJavaScriptReturningResult('''
(() => {
  const imgs = Array.from(document.querySelectorAll('img'))
    .map(i => i.src)
    .filter(Boolean)
    .filter(src => src.startsWith('http') || src.startsWith('data:image/'));
  const bestImg = imgs.find(s => s.toLowerCase().includes('qr')) || imgs[0];
  if (bestImg) return bestImg;

  const canvases = Array.from(document.querySelectorAll('canvas'));
  if (canvases.length > 0) {
    try {
      return canvases[0].toDataURL('image/png');
    } catch (_) {}
  }

  const bg = Array.from(document.querySelectorAll('*')).map(el => {
    const style = window.getComputedStyle(el);
    return style.backgroundImage || '';
  }).find(v => v.includes('data:image/') || v.includes('http'));
  if (bg) {
    const m = bg.match(/url[(]["']?(.*?)["']?[)]/i);
    if (m && m[1]) return m[1];
  }

  return '';
})()
''');
      final src = raw.toString().replaceAll('"', '').replaceAll("'", '').trim();
      if (src.isEmpty) {
        if (!mounted) return;
        showAppToast(context, 'No se encontró imagen QR para descargar', type: AppToastType.warning);
        return;
      }

      if (src.startsWith('http')) {
        await _downloadToDownloads(src);
        return;
      }

      if (src.startsWith('data:image/')) {
        if (_downloading) return;
        setState(() => _downloading = true);
        try {
          final metaAndData = src.split(',');
          if (metaAndData.length < 2) throw Exception('data URL inválida');
          final meta = metaAndData.first;
          final b64 = metaAndData.sublist(1).join(',');
          final ext = meta.contains('png') ? 'png' : (meta.contains('jpeg') || meta.contains('jpg')) ? 'jpg' : 'img';
          final fileName = 'qr_${DateTime.now().millisecondsSinceEpoch}.$ext';
          final downloadDir = Directory('/storage/emulated/0/Download');
          if (!await downloadDir.exists()) await downloadDir.create(recursive: true);
          final out = File('${downloadDir.path}/$fileName');
          final bytes = base64Decode(b64);
          await out.writeAsBytes(bytes);
          try {
            final picsDir = Directory('/storage/emulated/0/Pictures');
            if (!await picsDir.exists()) await picsDir.create(recursive: true);
            final picPath = '${picsDir.path}/$fileName';
            await out.copy(picPath);
          } catch (_) {}
          await _showDownloadedDialog(fileName);
        } finally {
          if (mounted) setState(() => _downloading = false);
        }
      }
    } catch (e) {
      if (!mounted) return;
      showAppToast(context, 'No se pudo descargar QR: $e', type: AppToastType.error);
    }
  }

  Future<void> _installDownloadHook() async {
    try {
      await _controller.runJavaScript('''
(() => {
  if (window.__e2vDownloadHookInstalled) return;
  window.__e2vDownloadHookInstalled = true;

  document.addEventListener('click', function(ev) {
    const target = ev.target;
    if (!target) return;
    const el = target.closest('a,button,input[type="button"],input[type="submit"]');
    if (!el) return;
    const txt = (el.innerText || el.textContent || el.value || '').toLowerCase();
    if (txt.includes('descargar qr') || txt.includes('descargar')) {
      if (window.E2VDownloadChannel && window.E2VDownloadChannel.postMessage) {
        window.E2VDownloadChannel.postMessage('download_click');
      }
    }
  }, true);
})();
''');
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'E2VDownloadChannel',
        onMessageReceived: (msg) async {
          if (msg.message == 'download_click') {
            await Future.delayed(const Duration(milliseconds: 450));
            if (!mounted) return;
            await _downloadQrFromDom();
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => setState(() => progress = p),
          onPageFinished: (_) async {
            await _installDownloadHook();
          },
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
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            LinearProgressIndicator(value: progress < 100 ? progress / 100 : 1),
            if (_downloading)
              const Padding(
                padding: EdgeInsets.fromLTRB(10, 8, 10, 4),
                child: LinearProgressIndicator(minHeight: 3),
              ),
            Expanded(child: WebViewWidget(controller: _controller)),
          ],
        ),
      ),
    );
  }
}
