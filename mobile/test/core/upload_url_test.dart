import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/network/upload_url.dart';
import 'package:netbuis/features/business/data/image_type.dart';

void main() {
  group('resolveUploadUrl', () {
    test('un chemin du serveur est résolu contre l\'ORIGINE de l\'API, pas « base + chemin »', () {
      expect(resolveUploadUrl('http://10.0.2.2:8000/api', '/api/uploads/local/abc/'),
          'http://10.0.2.2:8000/api/uploads/local/abc/');
      expect(resolveUploadUrl('https://api.netbuis.cm/api', '/api/uploads/local/abc/'),
          'https://api.netbuis.cm/api/uploads/local/abc/');
      expect(resolveUploadUrl('https://api.netbuis.cm/api', '/api/uploads/local/abc/'),
          isNot(contains('/api/api/')));
    });

    test('une adresse complète est gardée telle quelle (stockage compatible S3)', () {
      const presigned = 'https://seau.example.test/u1/photo/x.jpg?X-Sig=abc&X-Exp=900';
      expect(resolveUploadUrl('http://10.0.2.2:8000/api', presigned), presigned);
      expect(resolveUploadUrl('http://10.0.2.2:8000/api', 'HTTP://h.example.test/p'),
          'HTTP://h.example.test/p');
    });

    test('tout le reste est refusé', () {
      for (final bad in ['', 'uploads/local/abc/', '//autre.example.test/x', 'ftp://h/x', 'https://']) {
        expect(() => resolveUploadUrl('http://10.0.2.2:8000/api', bad),
            throwsA(isA<ApiException>()),
            reason: bad);
      }
      // Une adresse d'API inutilisable ne produit pas d'adresse bancale.
      expect(() => resolveUploadUrl('pas une adresse', '/api/uploads/local/abc/'),
          throwsA(isA<ApiException>()));
    });
  });

  group('detectImageContentType', () {
    Uint8List b(List<int> v) => Uint8List.fromList(v);

    test('JPEG, PNG et WebP d\'après les premiers octets', () {
      expect(detectImageContentType(b([0xFF, 0xD8, 0xFF, 0xE0, 1, 2])), 'image/jpeg');
      expect(detectImageContentType(b([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0])),
          'image/png');
      expect(
          detectImageContentType(
              b([0x52, 0x49, 0x46, 0x46, 9, 9, 9, 9, 0x57, 0x45, 0x42, 0x50, 1])),
          'image/webp');
    });

    test('GIF, texte, RIFF qui n\'est pas WebP, vide et trop court : refusés', () {
      expect(detectImageContentType(b([0x47, 0x49, 0x46, 0x38, 0x39, 0x61])), isNull);
      expect(detectImageContentType(b('<svg></svg>'.codeUnits)), isNull);
      expect(
          detectImageContentType(b([0x52, 0x49, 0x46, 0x46, 1, 1, 1, 1, 0x57, 0x41, 0x56, 0x45])),
          isNull);
      expect(detectImageContentType(Uint8List(0)), isNull);
      expect(detectImageContentType(b([0xFF, 0xD8])), isNull);
    });
  });
}
