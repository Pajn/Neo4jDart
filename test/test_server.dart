import 'dart:async';
import 'dart:io';

class Route {
  final int statusCode;
  final String content;

  final String path;

  Route({
    required this.statusCode,
    required this.content,
    required this.path,
  });
}

class TestServer {
  List<Route>? routes;
  HttpServer? _server;

  Route? matchingRoute(String path) {
    print('Request route $path');
    if (routes == null) return null;

    for (var r in routes!) {
      if (r.path == path) return r;
    }

    return null;
  }

  Future<void> start() async {
    if (_server == null) {
      _server = await HttpServer.bind('localhost', 0);
    }

    _server!.listen((HttpRequest request) async {
      final route = matchingRoute(request.uri.path);

      if (route == null) {
        request.response.write('Could not find any simulating route');
      } else {
        request.response
          ..statusCode = route.statusCode
          ..headers.contentType = ContentType('application', 'json')
          ..write(route.content);
      }

      request.response.close();
    });
  }

  String get url => 'http://localhost:${_server?.port}';

  void stop() {
    _server?.close();
    _server = null;
  }
}
