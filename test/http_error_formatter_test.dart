import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reins/Utils/http_error_formatter.dart';

void main() {
  group('HttpErrorFormatter.formatException', () {
    test('returns timeout-specific message', () {
      final result = HttpErrorFormatter.formatException(TimeoutException('timed out'));
      expect(result, 'Connection timed out. Please check if the server is running.');
    });

    test('maps host lookup socket error to server address guidance', () {
      final error = const SocketException('Failed host lookup: example.invalid');
      final result = HttpErrorFormatter.formatException(error);
      expect(result, 'Could not find server. Please verify the server address in settings.');
    });

    test('falls back to generic network error for unknown socket error', () {
      final error = const SocketException('Unexpected socket failure');
      final result = HttpErrorFormatter.formatException(error);
      expect(result, startsWith('Network error:'));
      expect(result, contains('Unexpected socket failure'));
    });
  });

  group('HttpErrorFormatter.formatHttpError', () {
    test('formats known status code without body', () {
      final result = HttpErrorFormatter.formatHttpError(404);
      expect(result, 'Resource not found. The requested model or endpoint does not exist.\n(HTTP 404)');
    });

    test('formats unknown status code with trimmed body', () {
      final result = HttpErrorFormatter.formatHttpError(499, body: '  custom response body  ');
      expect(result, 'Server returned an error.\n(HTTP 499)\n\ncustom response body');
    });
  });
}
