import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('アプリ詳細'),
      ),
      body: ListView(
        children: const [
          ListTile(
            title: Text('アプリ名'),
            subtitle: Text('Zzzone（ズォーン）'),
          ),
          ListTile(
            title: Text('制作者名'),
            subtitle: Text('kou09427'),
          ),
          ListTile(
            title: Text('共同編集'),
            subtitle: Text('Gemini-2.5-pro'),
          ),
          ListTile(
            title: Text('制作協力/アイコン制作'),
            subtitle: Text('syuu55'),
          ),
          ListTile(
            title: Text('対応端末'),
            subtitle: Text('Android-11~16'),
          ),
        ],
      ),
    );
  }
}
