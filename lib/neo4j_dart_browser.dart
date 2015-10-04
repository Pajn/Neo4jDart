/**
 * A thin Neo4j driver for running Cypher queries though the REST API from
 * the browser.
 */
library neo4j_dart;

import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/browser_client.dart' show BrowserClient;

part 'src/db.dart';
part 'src/exceptions.dart';
part 'src/statement.dart';
part 'src/transaction.dart';

final httpClient = new BrowserClient();
