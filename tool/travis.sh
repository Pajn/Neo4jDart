#!/bin/bash

# Fast fail the script on failures.
set -e

# Download and start Neo4j
if [ ! -d neo4j-community-$NEO_VERSION ]; then
    wget dist.neo4j.org/neo4j-community-$NEO_VERSION-unix.tar.gz
tar -xzf neo4j-community-$NEO_VERSION-unix.tar.gz
fi
neo4j-community-$NEO_VERSION/bin/neo4j start

# Make sure the database is stopped after tests
function stopDatabase {
    neo4j-community-$NEO_VERSION/bin/neo4j stop
}
trap stopDatabase EXIT

# Run the tests.
if [ "$TRAVIS_DART_VERSION" == "stable" ]; then
    dart --checked --enable-async test/runner.dart
else
    dart --checked test/runner.dart
fi

# If the COVERALLS_TOKEN token is set on travis
# Install dart_coveralls
# Rerun tests with coverage and send to coveralls
if [ "$COVERALLS_TOKEN" ]; then
  pub global activate dart_coveralls
  pub global run dart_coveralls report \
    --token $COVERALLS_TOKEN \
    --retry 2 \
    --exclude-test-files \
    test/runner.dart
fi
