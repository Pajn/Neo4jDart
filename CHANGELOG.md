# Changelog

## 0.3.2
- Support executing cypher queries from the browser 

## 0.3.1
- Support both list contains and string contains matchers

## 0.3.0
- Add Warehouse adapter
- Deprecate OGM

## 0.2.1
- Add support for Neo4j 2.2 (2.1 is still supported)

## 0.2.0
- Fix UTF-8
- Support open transactions
- Support basic HTTP authentication

### OGM
- Store state in a DbSession
- Fire events when nodes are created, updated or deleted
- Save all changes in the same transaction
- Fix crash when storing an object with a mixin
- Fix inherited relationship properties
- Add getAll method
- Support only storing changes in relations (added, removed) and not the node itself

## 0.1.1
- Polymorphism in OGM (Support returning and saving subclasses of T in repository)

## 0.1.0
- Initial Object Graph Mapper release

## 0.0.1

- Initial version
- Cypher support
