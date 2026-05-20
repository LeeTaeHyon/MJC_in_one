import "package:file_picker/file_picker.dart";
import "package:flutter/foundation.dart";
import "package:flutter_image_compress/flutter_image_compress.dart";
import "package:image/image.dart" as img;
import "package:mjc_in_one/utils/community_image_file_bytes_stub.dart"
    if (dart.library.io) "package:mjc_in_one/utils/community_image_file_bytes_io.dart";

/// 학과 공지 이미지 업로드 전 압축 (Storage·다운로드 비용 절감).
class CommunityImageCompressor {
  CommunityImageCompressor._();

  /// 긴 변 기준 최대 픽셀.
  static const int maxLongEdge = 1080;

  /// 목표 최대 파일 크기 (이보다 크면 quality를 낮춤).
  static const int targetMaxBytes = 400 * 1024;

  /// 압축 후에도 이 크기를 넘기면 업로드 거부.
  static const int hardMaxBytes = 512 * 1024;

  static const int initialQuality = 75;
  static const int minQuality = 48;
  static const int qualityStep = 7;

  static Future<CompressedCommunityImage> compress(PlatformFile file) async {
    final Uint8List raw = await _readRawBytes(file);
    if (raw.isEmpty) {
      throw CommunityImageCompressException("이미지를 읽을 수 없습니다.");
    }

    final int originalBytes = raw.length;
    Uint8List compressed = await _compressOnce(file, raw, initialQuality);

    int quality = initialQuality;
    while (compressed.length > targetMaxBytes && quality > minQuality) {
      quality -= qualityStep;
      compressed = await _compressOnce(file, raw, quality);
    }

    if (compressed.length > hardMaxBytes) {
      throw CommunityImageCompressException(
        "압축 후에도 용량이 큽니다 (${_formatKb(compressed.length)}). "
        "더 작은 이미지를 선택해 주세요.",
      );
    }

    return CompressedCommunityImage(
      bytes: compressed,
      originalBytes: originalBytes,
      compressedBytes: compressed.length,
      quality: quality,
    );
  }

  static Future<Uint8List> _compressOnce(
    PlatformFile file,
    Uint8List raw,
    int quality,
  ) async {
    final Uint8List? out;
    if (kIsWeb) {
      out = _compressWithImagePackage(raw, quality);
    } else if ((file.path ?? "").isNotEmpty) {
      out = await _compressNativeFile(file.path!, quality);
    } else {
      out = await _compressNativeBytes(raw, quality);
    }
    if (out == null || out.isEmpty) {
      throw CommunityImageCompressException("이미지 압축에 실패했습니다.");
    }
    return out;
  }

  static Future<Uint8List> _readRawBytes(PlatformFile file) =>
      readPlatformFileBytes(file);

  static Future<Uint8List?> _compressNativeFile(String path, int quality) {
    return FlutterImageCompress.compressWithFile(
      path,
      minWidth: maxLongEdge,
      minHeight: maxLongEdge,
      quality: quality,
      format: CompressFormat.jpeg,
      keepExif: false,
      autoCorrectionAngle: true,
    );
  }

  static Future<Uint8List?> _compressNativeBytes(
    Uint8List raw,
    int quality,
  ) {
    return FlutterImageCompress.compressWithList(
      raw,
      minWidth: maxLongEdge,
      minHeight: maxLongEdge,
      quality: quality,
      format: CompressFormat.jpeg,
      keepExif: false,
      autoCorrectionAngle: true,
    );
  }

  static Uint8List? _compressWithImagePackage(Uint8List raw, int quality) {
    final img.Image? decoded = img.decodeImage(raw);
    if (decoded == null) return null;

    final int w = decoded.width;
    final int h = decoded.height;
    final int longEdge = w > h ? w : h;
    img.Image working = decoded;

    if (longEdge > maxLongEdge) {
      if (w >= h) {
        working = img.copyResize(
          decoded,
          width: maxLongEdge,
          interpolation: img.Interpolation.linear,
        );
      } else {
        working = img.copyResize(
          decoded,
          height: maxLongEdge,
          interpolation: img.Interpolation.linear,
        );
      }
    }

    return Uint8List.fromList(
      img.encodeJpg(working, quality: quality.clamp(1, 100)),
    );
  }

  static String _formatKb(int bytes) =>
      "${(bytes / 1024).toStringAsFixed(0)}KB";
}

class CompressedCommunityImage {
  const CompressedCommunityImage({
    required this.bytes,
    required this.originalBytes,
    required this.compressedBytes,
    required this.quality,
  });

  final Uint8List bytes;
  final int originalBytes;
  final int compressedBytes;
  final int quality;

  double get ratio =>
      originalBytes > 0 ? compressedBytes / originalBytes : 1.0;
}

class CommunityImageCompressException implements Exception {
  CommunityImageCompressException(this.message);
  final String message;

  @override
  String toString() => message;
}
