#!/bin/sh

# スクリプトが失敗したら処理を中断する
set -e

# Flutter SDKをクローンする
cd /opt/build

git clone https://github.com/flutter/flutter.git --depth 1 --branch $FLUTTER_VERSION

# Flutterのパスを通す
export PATH="$PATH:/opt/build/flutter/bin"

# Flutterのバージョンを確認（ログに残すため）
flutter --version

# プロジェクトのルートディレクトリに戻る
cd $OLDPWD

# 依存パッケージを取得
flutter pub get

# Webアプリをビルド
flutter build web
