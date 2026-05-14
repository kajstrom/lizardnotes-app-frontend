import '../providers/attachment_provider.dart';

// Stub used on non-web targets. The real implementation lives in
// web_attachment_io.dart and is selected via conditional import.

class WebBlobSource extends UploadSource {
  WebBlobSource({required this.blob, required int size}) : _size = size;
  final Object blob;
  final int _size;
  @override
  int get size => _size;
  @override
  Stream<List<int>> openRead() =>
      throw UnsupportedError('WebBlobSource is web-only');
}

class WebPickedFile {
  WebPickedFile._();
  String get name => throw UnsupportedError('Web only');
  String get mimeType => throw UnsupportedError('Web only');
  int get size => throw UnsupportedError('Web only');
  Object get blob => throw UnsupportedError('Web only');
}

Future<List<WebPickedFile>> pickWebFiles({required String accept}) async =>
    throw UnsupportedError('pickWebFiles is web-only');

Future<bool> tryUploadWebBlob({
  required UploadSource source,
  required String url,
  required String contentType,
  void Function(int sent, int total)? onProgress,
}) async =>
    false;
