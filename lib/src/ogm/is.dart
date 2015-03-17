part of neo4j_dart.ogm;

class Is {
  final String filter;
  final value;

  const Is([this.filter, this.value]);

  check(field, value) => filter.replaceFirst('{field}', field).replaceFirst('{value}', value);

  static Is inList(Iterable collection) => new Is('{field} IN {value}', collection);
  static Is notInList(Iterable collection) => new Is('not({field} IN {value})', collection);

  static Is not(where) {
    if (where is Is) {
      return new Is('not(${where.filter})', where.value);
    } else {
      return new Is('{field} <> {value}', where);
    }
  }

  static Is equalTo(value) => new Is('{field} = {value}', value);
  static Is lessThan(num value) => new Is('{field} < {value}', value);
  static Is lessThanOrEqualTo(num value) => new Is('{field} <= {value}', value);
  static Is greaterThan(num value) => new Is('{field} > {value}', value);
  static Is greaterThanOrEqualTo(num value) => new Is('{field} >= {value}', value);

  operator ==(value) => equalTo(value);
  operator <(num value) => lessThan(value);
  operator <=(num value) => lessThanOrEqualTo(value);
  operator >(num value) => greaterThan(value);
  operator >=(num value) => greaterThanOrEqualTo(value);
}

const IS = const Is();

class Do extends Is {
  static const exist = const Is('has({field})');
  static const notExist = const Is('not(has({field}))');

  const Do(filter, [value]) : super(filter, value);

  static Is match(String regexp) => new Is('{field} =~ {value}', regexp);
}
