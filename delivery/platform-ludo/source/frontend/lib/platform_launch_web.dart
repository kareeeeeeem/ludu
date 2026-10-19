import 'package:web/web.dart' as web;

String? takeWebLaunchSession() {
  final hash = web.window.location.hash;
  if (!hash.startsWith('#session=')) return null;
  final session = Uri.decodeComponent(hash.substring(9));
  web.window.history.replaceState(null, '',
      '${web.window.location.pathname}${web.window.location.search}');
  return session;
}

void returnToPlatform() => web.window.history.back();
