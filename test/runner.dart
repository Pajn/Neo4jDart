import 'helpers/guinness.dart';

import 'specs/cypher.dart' as cypher;
import 'specs/repository.dart' as repository;
import 'specs/session.dart' as session;
import 'specs/transactions.dart' as transactions;

import 'warehouse_conformance.dart' as warehouse_conformance;
import 'package:unittest/unittest.dart';

class TestConfiguration extends SimpleConfiguration {
  onTestResult(TestCase result) {
    print(formatResult(result).trim());
  }

  void onSummary(int passed, int failed, int errors, List<TestCase> results,
                 String uncaughtError) {
    // Show the summary.
    print('');

    if (passed == 0 && failed == 0 && errors == 0 && uncaughtError == null) {
      print('No tests found.');
      // This is considered a failure too.
    } else if (failed == 0 && errors == 0 && uncaughtError == null) {
      print('All $passed tests passed.');
    } else {
      if (uncaughtError != null) {
        print('Top-level uncaught error: $uncaughtError');
      }
      print('$passed PASSED, $failed FAILED, $errors ERRORS');
    }
  }
}

main() {
  unittestConfiguration = new TestConfiguration();
  cypher.main();
  transactions.main();

  describe('Object Graph Mapper', () {
    repository.main();
    session.main();
  });

  warehouse_conformance.main();
}
