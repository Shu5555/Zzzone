// 条件付きエクスポート
// dart.library.ioはモバイル（Android/iOS）やデスクトップで利用可能
// dart.library.htmlはWebで利用可能
export 'database_helper_unsupported.dart' 
  if (dart.library.io) 'database_helper_mobile.dart' 
  if (dart.library.html) 'database_helper_web.dart';