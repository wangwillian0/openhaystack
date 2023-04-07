import 'dart:collection';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:io' as IO;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';
import 'package:pointycastle/src/platform_check/platform_check.dart';
import 'package:pointycastle/src/utils.dart' as pc_utils;
import 'package:openhaystack_mobile/findMy/decrypt_reports.dart';
import 'package:openhaystack_mobile/findMy/models.dart';
import 'package:openhaystack_mobile/findMy/reports_fetcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openhaystack_mobile/preferences/user_preferences_model.dart';

class FindMyController {
  static const _storage = FlutterSecureStorage();
  static final ECCurve_secp224r1 _curveParams =  ECCurve_secp224r1();
  static HashMap _keyCache = HashMap();

  /// Starts a new [Isolate], fetches and decrypts all location reports
  /// for the given [FindMyKeyPair].
  /// Returns a list of [FindMyLocationReport]'s.
  static Future<List<FindMyLocationReport>> computeResults(FindMyKeyPair keyPair) async{
    await _loadPrivateKey(keyPair);
    var prefs = await SharedPreferences.getInstance();
    final seemooEndpoint = prefs.getString(serverAddressKey) ?? "https://add-your-proxy-server-here/getLocationReports";
    return compute(_getListedReportResults, [keyPair, seemooEndpoint]);
  }

  /// Fetches and decrypts each location report in a separate [Isolate]
  /// for the given [FindMyKeyPair] from apples FindMy Network.
  /// Each report is decrypted in a separate [Isolate].
  /// Returns a list of [FindMyLocationReport].
  static Future<List<FindMyLocationReport>> _getListedReportResults(List<dynamic> args) async {
    FindMyKeyPair keyPair = args[0];
    String seemooEndpoint = args[1];
    final jsonReports = await ReportsFetcher.fetchLocationReports(keyPair.getHashedAdvertisementKey(), seemooEndpoint);
    final numChunks = kIsWeb ? 1 : IO.Platform.numberOfProcessors+1;
    final chunkSize = (jsonReports.length / numChunks).ceil();
    final chunks = [
      for (var i = 0; i < jsonReports.length; i += chunkSize)
        jsonReports.sublist(i, i + chunkSize < jsonReports.length ? i + chunkSize : jsonReports.length),
    ];
    final decryptedLocations = await Future.wait(chunks.map((jsonChunk) async {
      final decryptedChunk = await compute(_decryptChunk, [jsonChunk, keyPair, keyPair.privateKeyBase64!]);
      return decryptedChunk;
    }));
    final results = decryptedLocations.expand((element) => element).toList();
    return results;
  }

  /// Loads the private key from the local cache or secure storage and adds it
  /// to the given [FindMyKeyPair].
  static Future<void> _loadPrivateKey(FindMyKeyPair keyPair) async {
    String? privateKey;
    if (!_keyCache.containsKey(keyPair.hashedPublicKey)) {
      privateKey = await _storage.read(key: keyPair.hashedPublicKey);
      final newKey = _keyCache.putIfAbsent(keyPair.hashedPublicKey, () => privateKey);
      assert(newKey == privateKey);
    } else {
      privateKey = _keyCache[keyPair.hashedPublicKey];
    }
    keyPair.privateKeyBase64 = privateKey!;
  }

  /// Derives an [ECPublicKey] from a given [ECPrivateKey] on the given curve.
  static ECPublicKey _derivePublicKey(ECPrivateKey privateKey) {
    final pk = _curveParams.G * privateKey.d;
    final publicKey = ECPublicKey(pk, _curveParams);
    debugPrint("Point Data: ${base64Encode(publicKey.Q!.getEncoded(false))}");

    return publicKey;
  }

  /// Decrypts the encrypted reports with the given list of [FindMyKeyPair] and private key.
  /// Returns the list of decrypted reports as a list of [FindMyLocationReport].
  static Future<List<FindMyLocationReport>> _decryptChunk(List<dynamic> args) async {
    List<dynamic> jsonChunk = args[0];
    FindMyKeyPair keyPair = args[1];
    String privateKey = args[2];

    final reportChunk = jsonChunk.map((jsonReport) {
      assert (jsonReport["id"]! == keyPair.getHashedAdvertisementKey(),
      "Returned FindMyReport hashed key != requested hashed key");

      final unixTimestampInMillis =  jsonReport["datePublished"];
      final datePublished = DateTime.fromMillisecondsSinceEpoch(unixTimestampInMillis); 

      final report = FindMyReport(
        datePublished,
        base64Decode(jsonReport["payload"]),
        keyPair.getHashedAdvertisementKey(),
        jsonReport["statusCode"]);

      return report;
    }).toList();

    final decryptedReports = await DecryptReports.decryptReportChunk(reportChunk, base64Decode(privateKey));

    return decryptedReports;
  }

  /// Returns the to the base64 encoded given hashed public key
  /// corresponding [FindMyKeyPair] from the local [FlutterSecureStorage].
  static Future<FindMyKeyPair> getKeyPair(String base64HashedPublicKey) async {
    final privateKeyBase64 = await _storage.read(key: base64HashedPublicKey);

    ECPrivateKey privateKey = ECPrivateKey(
        pc_utils.decodeBigIntWithSign(1, base64Decode(privateKeyBase64!)), _curveParams);
    ECPublicKey publicKey = _derivePublicKey(privateKey);

    return FindMyKeyPair(publicKey, base64HashedPublicKey, privateKey, DateTime.now(), -1);
  }

  /// Imports a base64 encoded private key to the local [FlutterSecureStorage].
  /// Returns a [FindMyKeyPair] containing the corresponding [ECPublicKey].
  static Future<FindMyKeyPair> importKeyPair(String privateKeyBase64) async {
    final privateKeyBytes = base64Decode(privateKeyBase64);
    final ECPrivateKey privateKey = ECPrivateKey(
        pc_utils.decodeBigIntWithSign(1, privateKeyBytes), _curveParams);
    final ECPublicKey publicKey = _derivePublicKey(privateKey);
    final hashedPublicKey = getHashedPublicKey(publicKey: publicKey);
    final keyPair = FindMyKeyPair(
        publicKey,
        hashedPublicKey,
        privateKey,
        DateTime.now(),
        -1);
    
    await _storage.write(key: hashedPublicKey, value: keyPair.getBase64PrivateKey());
    
    return keyPair;
  }

  /// Generates a [ECCurve_secp224r1] keypair.
  /// Returns the newly generated keypair as a [FindMyKeyPair] object.
  static Future<FindMyKeyPair> generateKeyPair() async {
    final ecCurve = ECCurve_secp224r1();
    final secureRandom = SecureRandom('Fortuna')
      ..seed(KeyParameter(
          Platform.instance.platformEntropySource().getBytes(32)));
    ECKeyGenerator keyGen = ECKeyGenerator()
      ..init(ParametersWithRandom(ECKeyGeneratorParameters(ecCurve), secureRandom));

    final newKeyPair = keyGen.generateKeyPair();
    final ECPublicKey publicKey = newKeyPair.publicKey as ECPublicKey;
    final ECPrivateKey privateKey = newKeyPair.privateKey as ECPrivateKey;
    final hashedKey = getHashedPublicKey(publicKey: publicKey);
    final keyPair =  FindMyKeyPair(publicKey, hashedKey, privateKey, DateTime.now(), -1);
    await _storage.write(key: hashedKey, value: keyPair.getBase64PrivateKey());

    return keyPair;
  }

  /// Returns hashed, base64 encoded public key for given [publicKeyBytes]
  /// or for an [ECPublicKey] object [publicKey], if [publicKeyBytes] equals null.
  /// Returns the base64 encoded hashed public key as a [String].
  static String getHashedPublicKey({Uint8List? publicKeyBytes, ECPublicKey? publicKey}) {
    var pkBytes = publicKeyBytes ?? publicKey!.Q!.getEncoded(false);
    final shaDigest = SHA256Digest();
    shaDigest.update(pkBytes, 0, pkBytes.lengthInBytes);
    Uint8List out = Uint8List(shaDigest.digestSize);
    shaDigest.doFinal(out, 0);
    return base64Encode(out);
  }
}