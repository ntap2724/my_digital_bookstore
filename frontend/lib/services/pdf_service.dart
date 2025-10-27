import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:my_flutter_app/config.dart';
import 'package:my_flutter_app/services/auth_service.dart';
import 'package:path_provider/path_provider.dart';

class PdfService {
  static final PdfService instance = PdfService._();
  PdfService._();

  /// Download PDF for a book
  /// Returns local file path on success (mobile/desktop) or URL (web)
  Future<String> downloadBookPdf(
    int bookId, {
    Function(double progress)? onProgress,
  }) async {
    // For web: Just return the API URL, browser will handle it
    if (kIsWeb) {
      final token = await AuthService.instance.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required');
      }
      // Return URL with token as query param (for web download)
      final base = AppConfig.apiBaseUrl.replaceFirst(RegExp(r'\/$'), '');
      return '$base/api/books/$bookId/pdf?token=$token';
    }

    // For mobile/desktop: Download to local storage
    try {
      // Get local directory
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/books/book_$bookId.pdf';
      final file = File(filePath);

      // Create directory if not exists
      await file.parent.create(recursive: true);

      // Check if already downloaded
      if (await file.exists()) {
        return filePath;
      }

      // Download from API
      final baseUrl = AppConfig.apiBaseUrl;
      final base = baseUrl.replaceFirst(RegExp(r'\/$'), '');
      final token = await AuthService.instance.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Authentication required');
      }

      final client = http.Client();
      final uri = Uri.parse('$base/api/books/$bookId/pdf');

      IOSink? sink;
      int expectedLength = 0;
      int received = 0;

      Future<void> cleanupPartialDownload() async {
        await sink?.close();
        sink = null;
        if (await file.exists()) {
          await file.delete();
        }
      }

      Future<bool> isAcceptablePartial() async {
        try {
          await sink?.flush();
        } catch (_) {}
        try {
          await sink?.close();
        } catch (_) {}
        sink = null;

        if (!await file.exists()) {
          return false;
        }

        final actualSize = await file.length();
        if (actualSize <= 0) {
          return false;
        }

        if (expectedLength <= 0) {
          return received > 0 && actualSize >= received;
        }

        final diff = expectedLength - actualSize;
        return diff.abs() <= 64;
      }

      try {
        final request = http.Request('GET', uri)
          ..headers.addAll({
            HttpHeaders.authorizationHeader: 'Bearer $token',
            HttpHeaders.acceptHeader: 'application/pdf',
          });

        final response = await client.send(request);
        final status = response.statusCode;

        if (status == HttpStatus.forbidden) {
          final body = await response.stream.bytesToString();
          throw Exception(
            body.isNotEmpty ? body : 'You must purchase this book first',
          );
        }
        if (status == HttpStatus.notFound) {
          final body = await response.stream.bytesToString();
          throw Exception(
            body.isNotEmpty ? body : 'PDF file not available for this book',
          );
        }
        if (status != HttpStatus.ok) {
          final body = await response.stream.bytesToString();
          final reason = response.reasonPhrase?.isNotEmpty == true
              ? response.reasonPhrase!
              : 'status $status';
          final bodySnippet = body.isNotEmpty ? ' - $body' : '';
          throw Exception('Failed to download PDF: $reason$bodySnippet');
        }

        expectedLength = response.contentLength ?? 0;
        sink = file.openWrite();

        await for (final chunk in response.stream) {
          sink!.add(chunk);
          received += chunk.length;
          if (onProgress != null && expectedLength > 0) {
            onProgress(received / expectedLength);
          }
        }

        await sink!.flush();
        await sink!.close();
        sink = null;

        if (expectedLength > 0 && received < expectedLength) {
          await cleanupPartialDownload();
          throw Exception(
            'Download incomplete ($received of $expectedLength bytes)',
          );
        }

        return filePath;
      } on http.ClientException catch (e, stackTrace) {
        if (await isAcceptablePartial()) {
          debugPrint(
            'PDF download completed with minor short read; treating as success '
            '($received/$expectedLength bytes).',
          );
          return filePath;
        }

        await cleanupPartialDownload();
        developer.log(
          'PDF download ClientException',
          name: 'PdfService',
          error: {
            'exception': e,
            'expectedLength': expectedLength,
            'received': received,
          },
          stackTrace: stackTrace,
        );
        debugPrint(
          'PDF download ClientException after $received/$expectedLength bytes: $e',
        );
        throw Exception('Failed to download PDF: ${e.message}');
      } on SocketException catch (e, stackTrace) {
        if (await isAcceptablePartial()) {
          debugPrint(
            'PDF download completed after socket warning; treating as success '
            '($received/$expectedLength bytes).',
          );
          return filePath;
        }

        await cleanupPartialDownload();
        developer.log(
          'PDF download SocketException',
          name: 'PdfService',
          error: {
            'exception': e,
            'expectedLength': expectedLength,
            'received': received,
          },
          stackTrace: stackTrace,
        );
        debugPrint(
          'PDF download SocketException after $received/$expectedLength bytes: $e',
        );
        throw Exception('Failed to download PDF: ${e.message}');
      } finally {
        await sink?.close();
        client.close();
      }
    } catch (e, stackTrace) {
      developer.log(
        'Unexpected error downloading PDF',
        name: 'PdfService',
        error: e,
        stackTrace: stackTrace,
      );
      debugPrint('Unexpected error downloading PDF: $e');
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to download PDF: $e');
    }
  }

  /// Check if PDF is already downloaded
  Future<bool> isPdfDownloaded(int bookId) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/books/book_$bookId.pdf';
      return await File(filePath).exists();
    } catch (_) {
      return false;
    }
  }

  /// Delete downloaded PDF
  Future<void> deletePdf(int bookId) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/books/book_$bookId.pdf';
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      throw Exception('Failed to delete PDF: $e');
    }
  }

  /// Get PDF file size
  Future<int?> getPdfSize(int bookId) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/books/book_$bookId.pdf';
      final file = File(filePath);
      if (await file.exists()) {
        return await file.length();
      }
    } catch (_) {}
    return null;
  }
}

