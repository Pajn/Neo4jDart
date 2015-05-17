#!/bin/bash

# Fast fail the script on failures.
set -e

# Download and start Neo4j
if [ ! "$(ls -A neo4j-community-$NEO_VERSION)" ]; then
    wget dist.neo4j.org/neo4j-community-$NEO_VERSION-unix.tar.gz
    tar -xzf neo4j-community-$NEO_VERSION-unix.tar.gz
fi

# Disbale auth in 2.2
if [ -d neo4j-community-2.2.1 ]; then
  sed -i.bak s/dbms.security.auth_enabled=true/dbms.security.auth_enabled=false/g neo4j-community-2.2.1/conf/neo4j-server.properties
fi

neo4j-community-$NEO_VERSION/bin/neo4j start

# Make sure the database is stopped after tests
function stopDatabase {
    neo4j-community-$NEO_VERSION/bin/neo4j stop

    # Remove logs so that Travis can cache
    rm neo4j-community-$NEO_VERSION/data/log/*
}
trap stopDatabase EXIT

sleep 1

# Run the tests.
dart --checked test/runner.dart

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
