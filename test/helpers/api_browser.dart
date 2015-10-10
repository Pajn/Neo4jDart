library api_helpers;

import 'dart:async';
import 'dart:convert';
import 'package:http/browser_client.dart';

Future<Map<String, List>> cypherQuery(String query) =>
  new BrowserClient()
    .post('http://127.0.0.1:7474/db/data/transaction/commit', headers: {
        'Accept': 'application/json; charset=UTF-8',
        'Content-Type': 'application/json',
      },
      body: JSON.encode({
        'statements': [{'statement': query}]
      }))
      .then((response) => response.body)
      .then(JSON.decode);

