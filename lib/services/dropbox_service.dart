import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';
import 'package:crypto/crypto.dart';

class DropboxService {
  final _secureStorage = const FlutterSecureStorage();
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  static const String _appKey = '2mmltjxbcy4ijqu';

  // --- Platform-specific Redirect URIs ---
  static const String _mobileRedirectUriScheme = 'zzzoneauth';
  static final String _mobileRedirectUri = '$_mobileRedirectUriScheme://callback';
  static const String _webRedirectUri = 'http://localhost:5000';

  static const String _codeVerifierKey = 'dropbox_code_verifier';
  static const String _backupFileName = '/zzzone_backup.zip';

  /// Initiates the Dropbox authentication flow based on the current platform.
  Future<void> authenticate() async {
    if (kIsWeb) {
      await _webAuthenticate();
    } else {
      await _mobileAuthenticate();
    }
  }

  /// Handles the mobile authentication flow using deep links.
  Future<void> _mobileAuthenticate() async {
    final completer = Completer<String>();

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      if (uri.toString().startsWith(_mobileRedirectUri)) {
        if (!completer.isCompleted) {
          completer.complete(uri.toString());
          _linkSubscription?.cancel();
        }
      }
    });

    final codeVerifier = _generateCodeVerifier();
    final codeChallenge = _generateCodeChallenge(codeVerifier);

    final authUri = _buildAuthUri(codeChallenge, _mobileRedirectUri);

    try {
      if (kDebugMode) {
        print('Launching Dropbox Auth URL for Mobile: ${authUri.toString()}');
      }
      if (!await launchUrl(authUri, mode: LaunchMode.externalApplication)) {
        _linkSubscription?.cancel();
        throw Exception('Could not launch Dropbox authentication URL');
      }

      final result = await completer.future.timeout(const Duration(minutes: 2));
      final code = Uri.parse(result).queryParameters['code'];

      if (code != null) {
        await _exchangeCodeForToken(code, codeVerifier, _mobileRedirectUri);
      } else {
        throw Exception('Authorization code not found in redirect URL.');
      }
    } catch (e) {
      _linkSubscription?.cancel();
      if (kDebugMode) {
        print('Error during mobile authentication: $e');
      }
      rethrow;
    }
  }

  /// Handles the web authentication flow by launching the URL.
  Future<void> _webAuthenticate() async {
    final codeVerifier = _generateCodeVerifier();
    final codeChallenge = _generateCodeChallenge(codeVerifier);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_codeVerifierKey, codeVerifier);

    final authUri = _buildAuthUri(codeChallenge, _webRedirectUri);

    if (kDebugMode) {
      print('Launching Dropbox Auth URL for Web: ${authUri.toString()}');
    }
    if (!await launchUrl(authUri, webOnlyWindowName: '_self')) {
      throw Exception('Could not launch Dropbox authentication URL');
    }
  }

  /// Handles the callback from the web authentication flow.
  Future<bool> handleWebAuthCallback(Uri uri) async {
    final code = uri.queryParameters['code'];
    if (code == null) return false;

    final prefs = await SharedPreferences.getInstance();
    final codeVerifier = prefs.getString(_codeVerifierKey);

    if (codeVerifier == null) {
      throw Exception('Code verifier not found in storage.');
    }

    await prefs.remove(_codeVerifierKey);
    await _exchangeCodeForToken(code, codeVerifier, _webRedirectUri);
    return true;
  }

  Uri _buildAuthUri(String codeChallenge, String redirectUri) {
    return Uri.https('www.dropbox.com', '/oauth2/authorize', {
      'client_id': _appKey,
      'response_type': 'code',
      'redirect_uri': redirectUri,
      'token_access_type': 'offline',
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
    });
  }

  Future<void> _exchangeCodeForToken(String code, String codeVerifier, String redirectUri) async {
    final tokenUri = Uri.https('api.dropboxapi.com', '/oauth2/token');
    try {
      final response = await http.post(
        tokenUri,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'code': code,
          'grant_type': 'authorization_code',
          'redirect_uri': redirectUri,
          'client_id': _appKey,
          'code_verifier': codeVerifier,
        },
      );

      if (response.statusCode == 200) {
        final tokenData = json.decode(response.body);
        final accessToken = tokenData['access_token'];
        final refreshToken = tokenData['refresh_token'];
        if (accessToken != null && refreshToken != null) {
          await saveTokens(accessToken, refreshToken);
        } else {
          throw Exception('Token not found in response');
        }
      } else {
        throw Exception('Failed to exchange code for token: ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error exchanging code for token: $e');
      }
      rethrow;
    }
  }

  /// Uploads the backup file to Dropbox.
  Future<void> uploadBackup(String zipPath) async {
    final accessToken = await getAccessToken();
    if (accessToken == null) throw Exception('Not authenticated with Dropbox.');

    final fileBytes = await File(zipPath).readAsBytes();
    final uri = Uri.https('content.dropboxapi.com', '/2/files/upload');

    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/octet-stream',
        'Dropbox-API-Arg': jsonEncode({
          'path': _backupFileName,
          'mode': 'overwrite',
          'autorename': false,
          'mute': false,
        }),
      },
      body: fileBytes,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to upload backup: ${response.body}');
    }
  }

  /// Downloads the backup file from Dropbox.
  Future<String> downloadBackup() async {
    final accessToken = await getAccessToken();
    if (accessToken == null) throw Exception('Not authenticated with Dropbox.');

    final uri = Uri.https('content.dropboxapi.com', '/2/files/download');

    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Dropbox-API-Arg': jsonEncode({'path': _backupFileName}),
      },
    );

    if (response.statusCode == 200) {
      final tempDir = await getTemporaryDirectory();
      final zipPath = '${tempDir.path}/$_backupFileName';
      await File(zipPath).writeAsBytes(response.bodyBytes);
      return zipPath;
    } else {
      throw Exception('Failed to download backup: ${response.body}');
    }
  }

  /// Fetches metadata for the backup file.
  Future<Map<String, dynamic>?> getLatestBackupInfo() async {
    final accessToken = await getAccessToken();
    if (accessToken == null) throw Exception('Not authenticated with Dropbox.');

    final uri = Uri.https('api.dropboxapi.com', '/2/files/get_metadata');

    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'path': _backupFileName}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 409) {
      return null; // File not found
    } else {
      throw Exception('Failed to get backup info: ${response.body}');
    }
  }

  String _generateCodeVerifier() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  String _generateCodeChallenge(String codeVerifier) {
    final bytes = utf8.encode(codeVerifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await _secureStorage.write(key: 'dropbox_access_token', value: accessToken);
    await _secureStorage.write(key: 'dropbox_refresh_token', value: refreshToken);
  }

  Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: 'dropbox_access_token');
  }

  Future<void> clearTokens() async {
    final accessToken = await getAccessToken();
    if (accessToken != null) {
      final uri = Uri.https('api.dropboxapi.com', '/2/auth/token/revoke');
      try {
        await http.post(
          uri,
          headers: {'Authorization': 'Bearer $accessToken'},
        );
      } catch (e) {
        // Log the error, but don't block the local token deletion.
        if (kDebugMode) {
          print('Failed to revoke Dropbox token: $e');
        }
      }
    }
    // Always clear local tokens regardless of API call success.
    await _secureStorage.delete(key: 'dropbox_access_token');
    await _secureStorage.delete(key: 'dropbox_refresh_token');
  }
}