library cypher_helpers;

final VARIABLES_PATTERN = new RegExp('[\(\[]([a-z0-9]+)', caseSensitive: false);

List<String> getVariables(String cypher) =>
  VARIABLES_PATTERN.allMatches(cypher)
    .map((match) => match.group(1)).toList();
