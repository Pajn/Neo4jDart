library neo4j_dart.warehouse.where_clause;

import 'package:warehouse/warehouse.dart';
import 'package:warehouse/adapters/base.dart';

String setParameter(Map parameters, value, LookingGlass lg) {
  var converter = lg.convertedTypes[value.runtimeType];
  if (converter != null) {
    value = converter.toDatabase(value);
  }

  parameters['v${parameters.keys.length}'] = value;

  return '{v${parameters.keys.length - 1}}';
}

String buildWhereClause(Map where, Map parameters, LookingGlass lg) {
  var whereClause = '';

  if (where != null && where.isNotEmpty) {
    var filters = [];

    where.forEach((property, value) {

      if (value is Matcher) {
        filters.add(visitMatcher(value, parameters, lg).replaceAll('{field}', 'n.$property'));
      } else {
        var parameter = setParameter(parameters, value, lg);
        filters.add('n.$property = $parameter');
      }
    });

    whereClause = 'Where ' + filters.join(' AND ');
  }

  return whereClause;
}

String visitMatcher(Matcher matcher, Map parameters, LookingGlass lg) {
  if (matcher is ExistMatcher) {
    return 'has({field})';
  } else if (matcher is NotMatcher) {
    if (matcher.invertedMatcher is EqualsMatcher) {
      var parameter = setParameter(parameters, matcher.invertedMatcher.expected, lg);
      return '{field} <> $parameter';
    } else {
      return 'not(${visitMatcher(matcher.invertedMatcher, parameters, lg)})';
    }
  } else if (matcher is ContainMatcher) {
    var parameter = setParameter(parameters, matcher.expected, lg);
    return '$parameter IN {field}';
  } else if (matcher is ListMatcher) {
    var parameter = setParameter(parameters, matcher.list, lg);
    return '{field} IN $parameter';
  } else if (matcher is EqualsMatcher) {
    var parameter = setParameter(parameters, matcher.expected, lg);
    return '{field} = $parameter';
  } else if (matcher is LessThanMatcher) {
    var parameter = setParameter(parameters, matcher.expected, lg);
    return '{field} < $parameter';
  } else if (matcher is LessThanOrEqualToMatcher) {
    var parameter = setParameter(parameters, matcher.expected, lg);
    return '{field} <= $parameter';
  } else if (matcher is GreaterThanMatcher) {
    var parameter = setParameter(parameters, matcher.expected, lg);
    return '{field} > $parameter';
  } else if (matcher is GreaterThanOrEqualToMatcher) {
    var parameter = setParameter(parameters, matcher.expected, lg);
    return '{field} >= $parameter';
  } else if (matcher is InRangeMatcher) {
    var min = setParameter(parameters, matcher.min, lg);
    var max = setParameter(parameters, matcher.max, lg);
    return '{field} >= $min AND {field} <= $max';
  } else if (matcher is RegexpMatcher) {
    var parameter = setParameter(parameters, matcher.regexp, lg);
    return '{field} =~ $parameter';
  } else {
    throw 'Unsuported matcher ${matcher.runtimeType}';
  }
}
