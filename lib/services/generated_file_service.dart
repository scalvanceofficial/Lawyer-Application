import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class GeneratedFile {
  const GeneratedFile({
    required this.path,
    required this.name,
    required this.size,
  });

  final String path;
  final String name;
  final int size;
}

class GeneratedFileService {
  const GeneratedFileService._();

  static Future<GeneratedFile> saveBytes({
    required Uint8List bytes,
    required String fileName,
    Directory? directory,
  }) async {
    if (bytes.isEmpty) {
      throw const GeneratedFileException('The generated file was empty.');
    }
    final documentsDirectory =
        directory ?? await getApplicationDocumentsDirectory();
    debugPrint('GENERATED FILE DIRECTORY: ${documentsDirectory.path}');
    final outputDirectory = Directory('${documentsDirectory.path}/NyaySaarthi');
    await outputDirectory.create(recursive: true);
    final safeName = sanitizeFileName(fileName);
    final file = File('${outputDirectory.path}/$safeName');
    await file.writeAsBytes(bytes, flush: true);
    final validated = await validate(file.path);
    debugPrint('GENERATED FILE PATH: ${validated.path}');
    return validated;
  }

  static Future<GeneratedFile> validate(String path) async {
    final file = File(path);
    final exists = await file.exists();
    debugPrint('GENERATED FILE EXISTS: $exists');
    if (!exists) {
      throw const GeneratedFileException(
        'The generated file could not be found after saving.',
      );
    }
    final size = await file.length();
    debugPrint('GENERATED FILE SIZE: $size');
    if (size <= 0) {
      throw const GeneratedFileException('The generated file was empty.');
    }
    return GeneratedFile(
      path: file.path,
      name: file.uri.pathSegments.last,
      size: size,
    );
  }

  static Future<void> open(String path) async {
    await validate(path);
    final result = await OpenFilex.open(path);
    if (result.type != ResultType.done) {
      throw GeneratedFileException(
        result.message.isEmpty
            ? 'No app could open this file.'
            : result.message,
      );
    }
  }

  static Future<void> share(String path, {String? text}) async {
    final file = await validate(path);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: text),
    );
  }

  static String sanitizeFileName(String value) {
    final dot = value.lastIndexOf('.');
    final extension = dot > 0 ? value.substring(dot).toLowerCase() : '';
    final stem = dot > 0 ? value.substring(0, dot) : value;
    final safeStem = stem
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final safeExtension = extension.replaceAll(RegExp(r'[^a-z0-9.]'), '');
    return '${safeStem.isEmpty ? 'NyaySaarthi_File' : safeStem}'
        '${safeExtension.isEmpty ? '' : safeExtension}';
  }
}

class GeneratedFileException implements Exception {
  const GeneratedFileException(this.message);
  final String message;

  @override
  String toString() => message;
}
