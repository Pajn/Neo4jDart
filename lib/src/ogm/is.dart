part of neo4j_dart.ogm;

/**
 * Matchers to specify in where queries.
 *
 * More matchers exist in [Do]
 */
class Is {
  final String filter;
  final value;

  const Is([this.filter, this.value]);

  check(field, value) => filter.replaceFirst('{field}', field).replaceFirst('{value}', value);

  /// Allows values which appear in the [list]
  static Is inList(Iterable list) => new Is('{field} IN {value}', list);
  /// Allows values which do not appear in the [list]
  static Is notInList(Iterable list) => new Is('not({field} IN {value})', list);

  /**
   * Allows values which are not equal to [value].
   *
   * Optionally a matcher can be passed to negate its effect
   * Example for allowing values that does not begin with the letter A
   * `Is.not(Do.match('A.*'))`
   */
  static Is not(expected) {
    if (expected is Is) {
      return new Is('not(${expected.filter})', expected.value);
    } else {
      return new Is('{field} <> {value}', expected);
    }
  }

  /// Allows values which are equal to [expected]
  static Is equalTo(expected) => new Is('{field} = {value}', expected);
  /// Allows values which are less than [expected]
  static Is lessThan(num expected) => new Is('{field} < {value}', expected);
  /// Allows values which are less than or equal to [expected]
  static Is lessThanOrEqualTo(num expected) => new Is('{field} <= {value}', expected);
  /// Allows values which are greater than [expected]
  static Is greaterThan(num expected) => new Is('{field} > {value}', expected);
  /// Allows values which are greater than or equal to [expected]
  static Is greaterThanOrEqualTo(num expected) => new Is('{field} >= {value}', expected);

  /// Allows values which are equal to [expected]
  operator ==(expected) => equalTo(expected);
  /// Allows values which are less than [expected]
  operator <(num expected) => lessThan(expected);
  /// Allows values which are less than or equal to [expected]
  operator <=(num expected) => lessThanOrEqualTo(expected);
  /// Allows values which are greater than [expected]
  operator >(num expected) => greaterThan(expected);
  /// Allows values which are greater than or equal to [expected]
  operator >=(num expected) => greaterThanOrEqualTo(expected);
}

/// A constant instance of [Is] that is used for the operator comparisons
const IS = const Is();

/**
 * Matchers to specify in where queries.
 *
 * More matchers exist in [Is]
 */
abstract class Do extends Is {
  /// Only allows nodes which does have the field
  static const exist = const Is('has({field})');
  /// Only allows nodes which does not have the field
  static const notExist = const Is('not(has({field}))');

  /// Allows values which matches the [regexp]
  static Is match(String regexp) => new Is('{field} =~ {value}', regexp);
}
