import 'helpers/guinness.dart';

import 'specs/cypher.dart' as cypher;
import 'specs/repository.dart' as repository;
import 'specs/session.dart' as session;
import 'specs/transactions.dart' as transactions;

import 'warehouse_conformance.dart' as warehouse_conformance;

main() {
  cypher.main();
  transactions.main();

  describe('Object Graph Mapper', () {
    repository.main();
    session.main();
  });

  warehouse_conformance.main();
}
