import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_saver/file_saver.dart';
import 'package:e2v_app/src/core/ui/app_toast.dart';
import 'package:flutter/material.dart';
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
  bool _downloadDialogOpen = false;

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

  Future<void> _showDownloadingDialog() async {
    if (!mounted || _downloadDialogOpen) return;
    _downloadDialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        title: Text('Descargando QR'),
        content: Row(
          children: [
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2)),
            SizedBox(width: 12),
            Expanded(child: Text('Espera un momento...')),
          ],
        ),
      ),
    );
  }

  void _hideDownloadingDialog() {
    if (!mounted || !_downloadDialogOpen) return;
    Navigator.of(context, rootNavigator: true).pop();
    _downloadDialogOpen = false;
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

  MimeType _mimeFromExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return MimeType.pdf;
      case 'png':
        return MimeType.png;
      case 'jpg':
      case 'jpeg':
        return MimeType.jpeg;
      default:
        return MimeType.other;
    }
  }

  Future<void> _saveBytes(Uint8List bytes, String fileName, String ext) async {
    final sanitized = fileName.replaceAll(RegExp(r'[\/:*?"<>|]'), '_');
    final dotIndex = sanitized.lastIndexOf('.');
    final baseName = dotIndex > 0 ? sanitized.substring(0, dotIndex) : sanitized;
    final name = baseName.isEmpty ? 'archivo_${DateTime.now().millisecondsSinceEpoch}' : baseName;
    await FileSaver.instance.saveFile(
      name: name,
      bytes: bytes,
      ext: ext,
      mimeType: _mimeFromExtension(ext),
    );
  }

  Future<void> _downloadToDownloads(String url) async {
    if (_downloading) return;
    setState(() => _downloading = true);
    await _showDownloadingDialog();

    try {
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

      final response = await Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 12),
        ),
      ).get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (s) => s != null && s < 500,
          headers: cookieHeader.isNotEmpty ? {'Cookie': cookieHeader} : null,
        ),
      );

      final bytes = response.data;
      if (bytes == null) {
        throw Exception('Respuesta vacía');
      }

      await _saveBytes(Uint8List.fromList(bytes), fileName, ext);

      _hideDownloadingDialog();
      await _showDownloadedDialog(fileName);
    } catch (e) {
      _hideDownloadingDialog();
      if (!mounted) return;
      showAppToast(context, 'No se pudo descargar: $e', type: AppToastType.error);
    } finally {
      _hideDownloadingDialog();
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _downloadQrFromDom() async {
    try {
      final raw = await _controller.runJavaScriptReturningResult('''
(() => {
  const imgs = Array.from(document.querySelectorAll('img')).filter(i => i.width > 180 && i.height > 180);
  if (imgs.length > 0) {
    const preferred = imgs.find(i => (i.src || '').toLowerCase().includes('qr')) || imgs[0];
    try {
      const c = document.createElement('canvas');
      c.width = preferred.naturalWidth || preferred.width;
      c.height = preferred.naturalHeight || preferred.height;
      const ctx = c.getContext('2d');
      ctx.drawImage(preferred, 0, 0);
      const data = c.toDataURL('image/png');
      if (data && data.startsWith('data:image/')) return data;
    } catch (_) {}
    return preferred.src || '';
  }

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
        await _showDownloadingDialog();
        try {
          final metaAndData = src.split(',');
          if (metaAndData.length < 2) throw Exception('data URL inválida');
          final meta = metaAndData.first;
          final b64 = metaAndData.sublist(1).join(',');
          final ext = meta.contains('png') ? 'png' : (meta.contains('jpeg') || meta.contains('jpg')) ? 'jpg' : 'img';
          final fileName = 'qr_${DateTime.now().millisecondsSinceEpoch}.$ext';
          final bytes = Uint8List.fromList(base64Decode(b64));
          await _saveBytes(bytes, fileName, ext);
          _hideDownloadingDialog();
          await _showDownloadedDialog(fileName);
        } finally {
          _hideDownloadingDialog();
          if (mounted) setState(() => _downloading = false);
        }
        return;
      }
    } catch (e) {
      _hideDownloadingDialog();
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
