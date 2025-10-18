import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/backup_service.dart';
import '../services/database_helper.dart';
import '../services/dropbox_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _backupService = BackupService();
  final _dropboxService = DropboxService();

  String _lastBackupDate = '確認中...';
  bool _isBackingUp = false;
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();
    _loadLastBackupDate();
  }

  Future<void> _loadLastBackupDate() async {
    try {
      final backupInfo = await _dropboxService.getLatestBackupInfo();
      if (mounted) {
        if (backupInfo != null) {
          final serverModified = backupInfo['server_modified'] as String?;
          if (serverModified != null) {
            final backupDate = DateTime.parse(serverModified).toLocal();
            final formattedDate = DateFormat('yyyy年MM月dd日 HH:mm', 'ja_JP').format(backupDate);
            setState(() {
              _lastBackupDate = formattedDate;
            });
          } else {
            setState(() {
              _lastBackupDate = 'バックアップ履歴がありません';
            });
          }
        } else {
          setState(() {
            _lastBackupDate = 'バックアップ履歴がありません';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastBackupDate = '日時の取得に失敗しました';
        });
      }
    }
  }

  Future<void> _performBackup() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('この機能はWeb版ではサポートされていません。'),
          backgroundColor: Colors.grey,
        ),
      );
      return;
    }

    setState(() {
      _isBackingUp = true;
    });

    try {
      // 1. Get files to back up
      final files = await _backupService.getFilesToBackup();
      if (files.isEmpty) {
        throw Exception('バックアップ対象のファイルが見つかりませんでした。');
      }

      // 2. Create a zip archive
      final zipPath = await _backupService.createBackupZip(files);

      // 3. Upload to Dropbox
      await _dropboxService.uploadBackup(zipPath);

      // 4. Show success message and update date
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('バックアップが正常に完了しました。')),
        );
      }
      await _loadLastBackupDate();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('バックアップに失敗しました: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBackingUp = false;
        });
      }
    }
  }

  Future<void> _performRestore() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('この機能はWeb版ではサポートされていません。'),
          backgroundColor: Colors.grey,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('データを復元'),
        content: const Text('現在のローカルデータはすべて上書きされます。よろしいですか？この操作は元に戻せません。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('キャンセル')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('復元する', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed || !mounted) return;

    setState(() {
      _isRestoring = true;
    });

    try {
      // 1. Close the local database to release file lock
      await DatabaseHelper.instance.close();

      // 2. Download the backup file
      final zipPath = await _dropboxService.downloadBackup();

      // 3. Restore files from the zip
      await _backupService.restoreFromZip(zipPath);

      // 4. Show success and restart dialog
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('復元が完了しました'),
            content: const Text('アプリを終了します。手動で再起動してデータを反映してください。'),
            actions: [
              TextButton(
                onPressed: () {
                  SystemNavigator.pop(); // Exit the app
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('復元に失敗しました: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRestoring = false;
        });
      }
    }
  }

  Future<void> _showDropboxUnlinkDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dropbox連携を解除'),
        content: const Text('連携を解除しますか？バックアップ機能が利用できなくなります。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('キャンセル')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('連携解除', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    ) ?? false;

    if (confirmed && mounted) {
      await _dropboxService.clearTokens();
      // Pop back to settings screen after unlinking
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLoading = _isBackingUp || _isRestoring;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dropbox バックアップ'),
      ),
      body: AbsorbPointer(
        absorbing: isLoading,
        child: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('最終バックアップ日時'),
              subtitle: Text(_lastBackupDate),
            ),
            const Divider(),
            if (_isBackingUp)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 16),
                    Text('バックアップを実行中...'),
                  ],
                ),
              )
            else
              ListTile(
                leading: const Icon(Icons.cloud_upload),
                title: const Text('今すぐバックアップ'),
                subtitle: const Text('現在のデータをDropboxに保存します。'),
                onTap: _performBackup,
              ),
            const Divider(),
            if (_isRestoring)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 16),
                    Text('データを復元中...'),
                  ],
                ),
              )
            else
              ListTile(
                leading: const Icon(Icons.cloud_download),
                title: const Text('データを復元'),
                subtitle: const Text('Dropboxからデータを復元します。現在のデータは上書きされます。'),
                onTap: _performRestore,
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.link_off, color: Colors.redAccent),
              title: const Text(
                'Dropboxとの連携を解除',
                style: TextStyle(color: Colors.redAccent),
              ),
              onTap: _showDropboxUnlinkDialog,
            ),
            const Divider(),
          ],
        ),
      ),
    );
  }
}
