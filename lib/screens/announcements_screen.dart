import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/announcement.dart';
import '../services/announcement_service.dart';
import 'announcement_detail_screen.dart'; // 後で作成します

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final AnnouncementService _announcementService = AnnouncementService();
  late Future<List<Announcement>> _announcementsFuture;

  @override
  void initState() {
    super.initState();
    _announcementsFuture = _loadAndMarkAsRead();
  }

  Future<List<Announcement>> _loadAndMarkAsRead() async {
    final announcements = await _announcementService.loadAnnouncements();
    // This is a fire-and-forget call. We don't need to wait for it to finish
    // as the UI doesn't depend on its completion.
    _announcementService.markAnnouncementsAsRead(announcements);
    return announcements;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('お知らせ'),
      ),
      body: FutureBuilder<List<Announcement>>(
        future: _announcementsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('お知らせはありません。'));
          }

          final announcements = snapshot.data!;

          return ListView.separated(
            itemCount: announcements.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final announcement = announcements[index];
              return ListTile(
                title: Text(announcement.title),
                subtitle: Text(DateFormat('yyyy/MM/dd').format(announcement.createdAt)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => AnnouncementDetailScreen(announcement: announcement),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
