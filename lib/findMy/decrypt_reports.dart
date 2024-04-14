import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:collection/collection.dart';

import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';
import 'package:pointycastle/src/utils.dart' as pc_utils;
import 'package:openhaystack_mobile/findMy/models.dart';
import 'package:openhaystack_mobile/ffi/ffi.dart'
    if (dart.library.html) 'package:openhaystack_mobile/ffi/ffi_web.dart';

class DecryptReports {
  /// Decrypts a given [FindMyReport] with the given private key.
  static Future<List<FindMyLocationReport>> decryptReports(List<FindMyReport> reports, Uint8List privateKeyBytes) async {
    final curveDomainParam = ECCurve_secp224r1();

    final ephemeralKeys = reports.map((report) {
      final payloadData = report.payload;
      final ephemeralKeyBytes = payloadData.sublist(payloadData.length - 16 - 10 - 57, payloadData.length - 16 - 10);
      return ephemeralKeyBytes;
    }).toList();

    late final List<Uint8List> sharedKeys;

    try {
      debugPrint("Trying native ECDH");
      final ephemeralKeyBlob = Uint8List.fromList(ephemeralKeys.expand((element) => element).toList()); 
      final sharedKeyBlob = await api.ecdh(publicKeyBlob: ephemeralKeyBlob, privateKey: privateKeyBytes);
      final keySize = (sharedKeyBlob.length / ephemeralKeys.length).ceil();
      sharedKeys = [
        for (var i = 0; i < sharedKeyBlob.length; i += keySize)
          sharedKeyBlob.sublist(i, i + keySize < sharedKeyBlob.length ? i + keySize : sharedKeyBlob.length),
      ];
    }
    catch (e) {
      debugPrint("Native ECDH failed: $e");
      debugPrint("Falling back to pure Dart ECDH on single thread!");
      final privateKey = ECPrivateKey(
        pc_utils.decodeBigIntWithSign(1, privateKeyBytes),
        curveDomainParam);
      sharedKeys = ephemeralKeys.map((ephemeralKey) {
        final decodePoint = curveDomainParam.curve.decodePoint(ephemeralKey);
        final ephemeralPublicKey = ECPublicKey(decodePoint, curveDomainParam);

        final sharedKeyBytes = _ecdh(ephemeralPublicKey, privateKey);
        return sharedKeyBytes;
      }).toList();
    }

    final decryptedLocations = reports.mapIndexed((index, report) {
      final derivedKey = _kdf(sharedKeys[index], ephemeralKeys[index]);
      final payloadData = report.payload;
      _decodeTimeAndConfidence(payloadData, report);
      final encData = payloadData.sublist(payloadData.length - 16 - 10, payloadData.length - 16);
      final tag = payloadData.sublist(payloadData.length - 16, payloadData.length);
      final decryptedPayload = _decryptPayload(encData, derivedKey, tag);
      final locationReport = _decodePayload(decryptedPayload, report);
      return locationReport;
    }).toList();
    
    return decryptedLocations;
  }

  /// Decodes the unencrypted timestamp and confidence
  static void _decodeTimeAndConfidence(Uint8List payloadData, FindMyReport report) {
    final seenTimeStamp = payloadData.sublist(0, 4).buffer.asByteData()
        .getInt32(0, Endian.big);
    final timestamp = DateTime(2001).add(Duration(seconds: seenTimeStamp));
    final confidence = payloadData.elementAt(4);
    report.timestamp = timestamp;
    report.confidence = confidence;
  }

  /// Performs an Elliptic Curve Diffie-Hellman with the given keys.
  /// Returns the derived raw key data.
  static Uint8List _ecdh(ECPublicKey ephemeralPublicKey, ECPrivateKey privateKey) {
    final sharedKey = ephemeralPublicKey.Q! * privateKey.d;
    final sharedKeyBytes = pc_utils.encodeBigIntAsUnsigned(
        sharedKey!.x!.toBigInteger()!);
    debugPrint("Shared Key (shared secret): ${base64Encode(sharedKeyBytes)}");

    return sharedKeyBytes;
  }

  /// Decodes the raw decrypted payload and constructs and returns
  /// the resulting [FindMyLocationReport].
  static FindMyLocationReport _decodePayload(
      Uint8List payload, FindMyReport report) {

    final latitude = payload.buffer.asByteData(0, 4).getInt32(0, Endian.big);
    final longitude = payload.buffer.asByteData(4, 4).getInt32(0, Endian.big);
    final accuracy = payload.buffer.asByteData(8, 1).getUint8(0);

    final latitudeDec = latitude / 10000000.0;
    final longitudeDec = longitude / 10000000.0;

    return FindMyLocationReport(latitudeDec, longitudeDec, accuracy,
        report.datePublished, report.timestamp, report.confidence);
  }

  /// Decrypts the given cipher text with the key data using an AES-GCM block cipher.
  /// Returns the decrypted raw data.
  static Uint8List _decryptPayload(
      Uint8List cipherText, Uint8List symmetricKey, Uint8List tag) {
    final decryptionKey = symmetricKey.sublist(0, 16);
    final iv = symmetricKey.sublist(16, symmetricKey.length);

    final aesGcm = GCMBlockCipher(AESEngine())
      ..init(false, AEADParameters(KeyParameter(decryptionKey),
          tag.lengthInBytes * 8, iv, tag));

    final plainText = Uint8List(cipherText.length);
    var offset = 0;
    while (offset < cipherText.length) {
      offset += aesGcm.processBlock(cipherText, offset, plainText, offset);
    }

    assert(offset == cipherText.length);
    return plainText;
  }

  /// ANSI X.963 key derivation to calculate the actual (symmetric) advertisement
  /// key and returns the raw key data.
  static Uint8List _kdf(Uint8List secret, Uint8List ephemeralKey) {
    var shaDigest = SHA256Digest();
    if (secret.length < 28) {
      var pad = Uint8List(28 - secret.length);
      shaDigest.update(pad, 0, pad.length);
    }
    shaDigest.update(secret, 0, secret.length);

    var counter = 1;
    var counterData = ByteData(4)..setUint32(0, counter);
    var counterDataBytes = counterData.buffer.asUint8List();
    shaDigest.update(counterDataBytes, 0, counterDataBytes.lengthInBytes);

    shaDigest.update(ephemeralKey, 0, ephemeralKey.lengthInBytes);

    Uint8List out = Uint8List(shaDigest.digestSize);
    shaDigest.doFinal(out, 0);

    debugPrint("Derived key: ${base64Encode(out)}");
    return out;
  }
}
