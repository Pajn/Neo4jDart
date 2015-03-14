library api_helpers;

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

Future<Map<String, List>> cypherQuery(String query) =>
  http.post('http://127.0.0.1:7474/db/data/cypher', body: JSON.encode({
    'query': query
  }))
  .then((response) => response.body)
  .then(JSON.decode);

