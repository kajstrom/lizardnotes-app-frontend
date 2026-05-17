import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../providers/attachment_provider.dart';

// Web-native attachment IO. Bypasses file_picker and Dio so the browser can
// stream the Blob straight to S3 without ever copying its bytes into the JS
// or Dart heap. Camera-captured JPEGs are already in-memory Blobs, so any
// extra materialisation OOMs mobile browser tabs.

class WebBlobSource extends UploadSource {
  WebBlobSource({required this.blob, required int size}) : _size = size;
  final Object blob; // a web.Blob at runtime; typed as Object to match the stub
  final int _size;
  @override
  int get size => _size;
  @override
  Stream<List<int>> openRead() => throw StateError(
        'WebBlobSource uploads via XHR; openRead() must not be called',
      );
}

class WebPickedFile {
  WebPickedFile({
    required this.name,
    required this.mimeType,
    required this.size,
    required this.blob,
  });
  final String name;
  final String mimeType;
  final int size;
  final Object blob; // a web.File at runtime
}

Future<List<WebPickedFile>> pickWebFiles({required String accept}) {
  final completer = Completer<List<WebPickedFile>>();
  final input =
      (web.document.createElement('input') as web.HTMLInputElement)
        ..type = 'file'
        ..accept = accept
        ..multiple = true;

  void finish(List<WebPickedFile> files) {
    if (!completer.isCompleted) completer.complete(files);
  }

  input.addEventListener(
    'change',
    ((web.Event _) {
      final files = input.files;
      if (files == null) {
        finish(const []);
        return;
      }
      final out = <WebPickedFile>[];
      for (var i = 0; i < files.length; i++) {
        final f = files.item(i);
        if (f == null) continue;
        out.add(WebPickedFile(
          name: f.name,
          mimeType: f.type.isEmpty ? 'application/octet-stream' : f.type,
          size: f.size,
          blob: f,
        ));
      }
      finish(out);
    }).toJS,
  );
  // Detect cancel (no file chosen) via the cancel event where supported.
  input.addEventListener(
    'cancel',
    ((web.Event _) => finish(const [])).toJS,
  );

  input.click();
  return completer.future;
}

Future<void> openUrlInNewTab(String url) async {
  web.window.open(url, '_blank');
}

Future<bool> tryUploadWebBlob({
  required UploadSource source,
  required String url,
  required String contentType,
  void Function(int sent, int total)? onProgress,
}) async {
  if (source is! WebBlobSource) return false;

  final completer = Completer<void>();
  final xhr = web.XMLHttpRequest();
  xhr.open('PUT', url);
  xhr.setRequestHeader('Content-Type', contentType);

  xhr.upload.addEventListener(
    'progress',
    ((web.ProgressEvent e) {
      if (onProgress == null) return;
      final total = e.lengthComputable ? e.total : source.size;
      onProgress(e.loaded, total);
    }).toJS,
  );
  xhr.addEventListener(
    'load',
    ((web.Event _) {
      final status = xhr.status;
      if (status >= 200 && status < 300) {
        if (!completer.isCompleted) completer.complete();
      } else {
        if (!completer.isCompleted) {
          completer.completeError('S3 upload failed: HTTP $status');
        }
      }
    }).toJS,
  );
  xhr.addEventListener(
    'error',
    ((web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError('S3 upload network error');
      }
    }).toJS,
  );
  xhr.addEventListener(
    'abort',
    ((web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError('S3 upload aborted');
      }
    }).toJS,
  );

  xhr.send(source.blob as web.Blob);
  await completer.future;
  return true;
}
