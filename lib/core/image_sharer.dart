import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Hands a rendered image to the operating system share sheet (feature 027).
/// The app itself sends nothing; the user picks the target app.
abstract interface class ImageSharer {
  /// Shares the PNG [bytes] as [fileName] with an optional [text] caption.
  /// Throws when the image cannot be written or the sheet cannot open.
  Future<void> sharePng(
    Uint8List bytes, {
    required String fileName,
    String? text,
  });
}

/// [ImageSharer] backed by `share_plus`. The image is written to a `share`
/// folder in the app's temporary directory, which only ever holds the last
/// shared image.
class SharePlusImageSharer implements ImageSharer {
  const new();

  @override
  Future<void> sharePng(
    Uint8List bytes, {
    required String fileName,
    String? text,
  }) async {
    final tmp = await getTemporaryDirectory();
    final dir = Directory('${tmp.path}/share');
    if (dir.existsSync()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: text,
      ),
    );
  }
}

/// The sharer used by the app; tests override it with a fake.
final imageSharerProvider = Provider<ImageSharer>(
  (ref) => const SharePlusImageSharer(),
);
