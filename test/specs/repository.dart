library repository_spec;

import '../helpers.dart';
import '../helpers/domain.dart';

main() {
  var db = setUp();

  describe('Repository', () {
    DbSession session;
    Repository<Actor> actorRepository;
    MovieRepository movieRepository;
    Repository<Person> personRepository;
    Repository<SpecialCases> specialsRepository;
    Person anna, peter;
    Actor owen, maggie, will;
    Movie avatar, badBoys, cars, cars2, fury, theGreenMile, up;

    beforeEach(() async {
      session = new DbSession(db);

      actorRepository = new Repository<Actor>(session);
      movieRepository = new MovieRepository(session);
      personRepository = new Repository<Person>(session);
      specialsRepository = new Repository<SpecialCases>(session);

      cars = new Movie()
        ..name = 'Cars'
        ..year = 2006;
      cars2 = new Movie()
        ..name = 'Cars 2'
        ..year = 2011
        ..predecessor = cars;
      up = new Movie()
        ..name = 'Up'
        ..year = 2009
        ..releaseDates = [
          new DateTime.utc(2009, 05, 13),
          new DateTime.utc(2009, 05, 16),
        ];
      owen = new Actor()
        ..name = 'Owen Wilson'
        ..actedIn = [
          new ActedIn()
            ..role = 'Lightning McQueen'
            ..end = cars,
          new ActedIn()
            ..role = 'Lightning McQueen'
            ..end = cars2,
        ];
      maggie = new Actor()
        ..name = 'Maggie Denise Quigley'
        ..nicknames = ['Maggie Q', 'Q'];

      await setUpTestData();

      avatar = await movieRepository.find({'name': 'Avatar'});
      badBoys = await movieRepository.find({'name': 'Bad Boys'});
      fury = await movieRepository.find({'name': 'Fury'});
      theGreenMile = await movieRepository.find({'name': 'The Green Mile'});
      will = await actorRepository.find({'name': 'Will Smith'});

      anna = new Person()
        ..name = 'Anna'
        ..favoriteMovie = avatar;

      peter = new Person()
        ..name = 'Peter'
        ..favoriteMovie = avatar;
    });

    it('should be able to create a node', () {
      movieRepository.store(cars);

      var query = movieRepository.saveChanges();
      return expect(query).toHaveWritten('(a:Movie {name:"Cars", year:2006})');
    });

    it('should be able to create multiple nodes', () {
      movieRepository.store(cars);
      movieRepository.store(up);

      var query = movieRepository.saveChanges();
      return expect(query).toHaveWritten('''
        (a:Movie {name:"Cars", year:2006}),
        (b:Movie {name:"Up", year:2009})
      ''');
    });

    it('should be able to handle collections', () async {
      actorRepository.store(maggie);

      var query = actorRepository.saveChanges();
      await expect(query).toHaveWritten(
          '(a:Actor {name:"Maggie Denise Quigley", nicknames: ["Maggie Q", "Q"]})'
      );

      var m = await actorRepository.find({'name': 'Maggie Denise Quigley'});
      expect(m.nicknames).toEqual(['Maggie Q', 'Q']);
    });

    it('should be able to handle of collections of dates', () async {
      movieRepository.store(up);

      var query = movieRepository.saveChanges();
      await expect(query).toHaveWritten(
          '(a:Movie {name:"Up", year:2009, releaseDates: [1242172800000,1242432000000]})'
      );

      var movie = await movieRepository.find({'name': 'Up'});
      expect(movie.releaseDates).toEqual([
          new DateTime.utc(2009, 05, 13),
          new DateTime.utc(2009, 05, 16),
      ]);
    });

    it('should be able to create a node with inherited properties', () {
      actorRepository.store(owen);

      var query = actorRepository.saveChanges();
      return expect(query).toHaveWritten('(a:Actor:Person {name:"Owen Wilson"})');
    });

    it('should be able to create multiple nodes with relations', () {
      movieRepository.store(cars);
      movieRepository.store(cars2);

      var query = movieRepository.saveChanges();
      return expect(query).toHaveWritten('''
        (cars:Movie {name:"Cars", year:2006}),
        (cars2:Movie {name:"Cars 2", year:2011}),
        (cars2)-[:predecessor]->(cars)
      ''');
    });

    it('should be able to create a node with a collection of relations', () async {
      movieRepository.store(cars);
      movieRepository.store(cars2);

      await movieRepository.saveChanges();
      actorRepository.store(owen);

      var query = actorRepository.saveChanges();
      return expect(query).toHaveWritten('''
        (owen:Actor:Person {name:"Owen Wilson"}),
        (cars:Movie {name:"Cars", year:2006}),
        (cars2:Movie {name:"Cars 2", year:2011}),
        (owen)-[:actedIn {role: "Lightning McQueen"}]->(cars),
        (owen)-[:actedIn {role: "Lightning McQueen"}]->(cars2)
      ''');
    });

    it('should be able to create a relation from a collection', () async {
      will.actedIn.add(
          new ActedIn()
            ..role = 'just a test'
            ..end = avatar
      );
      actorRepository.store(will);

      var query = actorRepository.saveChanges();
      await expect(query).toHaveWritten('''
        (ws:Actor {name:"Will Smith"})-[:actedIn {role: "just a test"}]->(:Movie {name: "Avatar"})
      ''');
      await expect(query).not.toHaveDeleted('''
        (ws:Actor {name:"Will Smith"})-[:actedIn]->(:Movie {name: "Bad Boys"}),
                                  (ws)-[:actedIn]->(:Movie {name: "Bad Boys II"}),
                                  (ws)-[:actedIn]->(:Movie {name: "Bad Boys 3"})
      ''');
    });

    it('should be able to handle one-to-many relations', () async {
      session..store(anna)..store(peter);
      await session.saveChanges();

      anna = await personRepository.find({'name': 'Anna'}, maxDepth: 2);

      anna.favoriteMovie.favoredBy.sort((a, b) => a.name.compareTo(b.name));

      expect(anna.favoriteMovie.favoredBy.length).toEqual(2);
      expect(anna.favoriteMovie.favoredBy.first).toBe(anna);
      expect(anna.favoriteMovie.favoredBy.last.name).toEqual('Peter');
      expect(anna.favoriteMovie.favoredBy.last.favoriteMovie).toBe(anna.favoriteMovie);
    });

    it('should be able to create a relation from a collection from a getter', () async {
      var special = new SpecialCases();
      specialsRepository.store(special);
      await specialsRepository.saveChanges();

      will.specials = [special];
      actorRepository.store(will);

      var query = actorRepository.saveChanges();
      await expect(query).toHaveWritten('''
        (ws:Actor {name:"Will Smith"})-[:specials]->(:SpecialCases)
      ''');

      will = await actorRepository.find({'name': 'Will Smith'});
      expect(will.specials.length).toEqual(1);
      expect(will.specials.first).toBeA(SpecialCases);
    });

    it('should save class and library information', () {
      movieRepository.store(cars);

      var query = movieRepository.saveChanges();
      return expect(query).toHaveWritten(
          '(a:Movie {name:"Cars", year:2006, `@class`: "Movie", `@library`: "test_domain"})'
      );
    });

    it('should be able to update a node', () {
      avatar.name = 'Profile';
      movieRepository.store(avatar);

      var query = movieRepository.saveChanges();
      return expect(query).toHaveWritten('(a:Movie {name:"Profile", year:2009})');
    });

    it('should be able to update multiple nodes', () {
        fury.year = 10;
        theGreenMile.name = 'The Red Mile';

        movieRepository.store(fury);
        movieRepository.store(theGreenMile);

        var query = movieRepository.saveChanges();
        return expect(query).toHaveWritten('''
          (a:Movie {name:"Fury", year:10}),
          (b:Movie {name:"The Red Mile", year:1999})
        ''');
    });

    it('should be able to delete a node', () {
        movieRepository.delete(fury);

        var query = movieRepository.saveChanges();
        return expect(query).toHaveDeleted('(a:Movie {name:"Fury", year:2014})');
    });

    it('should be able to delete multiple nodes', () {
      movieRepository.delete(fury);
      movieRepository.delete(theGreenMile);

      var query = movieRepository.saveChanges();
      return expect(query).toHaveDeleted('''
        (a:Movie {name:"Fury", year:2014}),
        (b:Movie {name:"The Green Mile", year:1999})
      ''');
    });

    it('should not be able to delete a node with relations', () {
      movieRepository.delete(avatar);

      var query = movieRepository.saveChanges().catchError(expectAsync((error) {
        expect(error['errors'][0]['code']).toEqual('Neo.DatabaseError.Transaction.CouldNotCommit');
        expect(error['errors'][0]['message']).toContain('still has relationships');
      }));

      return expect(query).not.toHaveDeleted('(a:Movie {name:"Avatar", year:2009})');
    });

    it('should be able to delete a node with relations forcefully', () {
      movieRepository.delete(avatar, deleteRelations: true);

      var query = movieRepository.saveChanges();
      return expect(query).toHaveDeleted('(a:Movie {name:"Avatar", year:2009})');
    });

    it('should not be able to delete a node by first removing the relations', () async {
      avatar.centralCharacter = null;
      movieRepository.store(avatar);
      movieRepository.delete(avatar);
      await movieRepository.saveChanges();

      movieRepository.delete(avatar);

      var query = movieRepository.saveChanges();
      return expect(query).toHaveDeleted('(a:Movie {name:"Avatar", year:2009})');
    });

    it('should be able to delete a relation from a collection', () async {
      will.actedIn.removeWhere((role) => role.end.name == 'Bad Boys');
      actorRepository.store(will);

      var query = actorRepository.saveChanges();
      await expect(query).toHaveDeleted('''
        (ws:Actor {name:"Will Smith"})-[:actedIn]->(:Movie {name: "Bad Boys"})
      ''');
      await expect(query).not.toHaveDeleted('''
        (ws:Actor {name:"Will Smith"})-[:actedIn]->(:Movie {name: "Bad Boys II"}),
                                  (ws)-[:actedIn]->(:Movie {name: "Bad Boys 3"})
      ''');
    });

    describe('get', () {
      it('should get a node', () async {
        var f = await movieRepository.get(fury.id);

        expect(f).toHaveSameProps(fury);
      });

      it('should handle relations without a reverse field', () async {
        var a = await movieRepository.get(avatar.id);

        expect(a.name).toEqual('Avatar');
        expect(a.centralCharacter.role).toEqual('Jake Sully');
        expect(a.centralCharacter.end.name).toEqual('Sam Worthington');
        expect(a.centralCharacter.end.birthDate).toEqual(new DateTime.utc(1976, 08, 02));
        expect(a.centralCharacter.start).toBe(a);
        expect(a.centralCharacter.end).toBeA(Actor);
        expect(a.centralCharacter).toBeA(Role);
      });

      it('should be able to create referenses to related nodes', () async {
        var badBoys1 = await movieRepository.get(badBoys.id);

        expect(badBoys1.name).toEqual('Bad Boys');
        expect(badBoys1.year).toEqual(1995);
        expect(badBoys1.sequel.name).toEqual('Bad Boys II');
        expect(badBoys1.sequel.year).toEqual(2003);
        expect(badBoys1.sequel.predecessor).toBe(badBoys1);
        expect(badBoys1.cast.length).toEqual(1);
        expect(badBoys1.cast.first.role).toEqual('Mike Lowrey');
        expect(badBoys1.cast.first.start.name).toEqual('Will Smith');
        expect(badBoys1.cast.first.start.actedIn.length).toEqual(1);
        expect(badBoys1.cast.first.start.actedIn.first).toBe(badBoys1.cast.first);
        expect(badBoys1.cast.first.start).toBeA(Actor);
        expect(badBoys1.cast.first.end).toBe(badBoys1);
        expect(badBoys1.sequel.sequel).toBeNull();
        expect(badBoys1.predecessor).toBeNull();
      });

      it('should be able to create referenses to related nodes with extended depth', () async {
        var badBoys1 = await movieRepository.get(badBoys.id, maxDepth: 2);

        expect(badBoys1.name).toEqual('Bad Boys');
        expect(badBoys1.year).toEqual(1995);
        expect(badBoys1.sequel.name).toEqual('Bad Boys II');
        expect(badBoys1.sequel.year).toEqual(2003);
        expect(badBoys1.sequel.sequel.name).toEqual('Bad Boys 3');
        expect(badBoys1.sequel.cast.length).toEqual(1);
        expect(badBoys1.sequel.cast.first.start.name).toEqual('Will Smith');
        expect(badBoys1.sequel.sequel.year).toBeNull();
        expect(badBoys1.cast.length).toEqual(1);
        expect(badBoys1.sequel.cast.first.start).toBe(badBoys1.cast.first.start);
        expect(badBoys1.sequel.cast.first).not.toBe(badBoys1.cast.first);
        expect(badBoys1.sequel.sequel.predecessor).toBe(badBoys1.sequel);
        expect(badBoys1.sequel.predecessor).toBe(badBoys1);
        expect(badBoys1.sequel.sequel.sequel).toBeNull();
        expect(badBoys1.predecessor).toBeNull();
      });

      it('should create an instance of the same class the was saved', () async {
        var f = await movieRepository.get(theGreenMile.id);

        expect(f).toBeA(SpecificMovie);
        expect(f.genre).toEqual("Drama");
      });
    });

    describe('findAll', () {
      it('should get all nodes', () async {
        var allMovies = await movieRepository.findAll();

        expect(allMovies.map((movie) => movie.name).toList()..sort()).toEqual([
            'Avatar',
            'Bad Boys',
            'Bad Boys 3',
            'Bad Boys II',
            'Fury',
            'The Green Mile',
        ]);
      });

      it('should create referenses to related nodes', () async {
        var allMovies = await movieRepository.findAll(maxDepth: 1);
        var badBoys = allMovies.singleWhere((movie) => movie.name == 'Bad Boys');
        var badBoys2 = allMovies.singleWhere((movie) => movie.name == 'Bad Boys II');
        var badBoys3 = allMovies.singleWhere((movie) => movie.name == 'Bad Boys 3');

        expect(badBoys.sequel).toBe(badBoys2);
        expect(badBoys2.sequel).toBe(badBoys3);
        expect(badBoys3.sequel).toBeNull();
        expect(badBoys.predecessor).toBeNull();
        expect(badBoys2.predecessor).toBe(badBoys);
        expect(badBoys3.predecessor).toBe(badBoys2);
      });

      describe('where', () {
        it('should be able to filter on a property', () async {
          var movies = await movieRepository.findAll(where: {'name': 'Avatar'});
          var movies1 = await movieRepository.findAll(where: {'name': Is.equalTo('Avatar')});
          var movies2 = await movieRepository.findAll(where: {'name': IS == 'Avatar'});

          expect(movies.length).toEqual(1);
          expect(movies.first.name).toEqual('Avatar');
          expect(movies1).toHaveSameProps(movies);
          expect(movies2).toHaveSameProps(movies);
        });

        it('should be able to filter on what a property is not', () async {
          var movies = await movieRepository.findAll(where: {'name': Is.not('Avatar')});

          expect(movies.length).toEqual(5);
          expect(movies.map((m) => m.name).toList()..sort()).toEqual([
              'Bad Boys',
              'Bad Boys 3',
              'Bad Boys II',
              'Fury',
              'The Green Mile'
          ]);
        });

        it('should be able to filter on existense of a property', () async {
          var movies = await movieRepository.findAll(where: {'year': Do.exist});

          expect(movies.length).toEqual(5);
          expect(movies.map((m) => m.name).toList()..sort()).toEqual([
              'Avatar',
              'Bad Boys',
              'Bad Boys II',
              'Fury',
              'The Green Mile'
          ]);
        });

        it('should be able to filter on absense of a property', () async {
          var movies = await movieRepository.findAll(where: {'year': Do.notExist});

          expect(movies.length).toEqual(1);
          expect(movies.first.name).toEqual('Bad Boys 3');
        });

        it('should be able to filter on the existense of a property in a list', () async {
          var movies = await movieRepository.findAll(where: {'name': Is.inList(['Avatar', 'Fury'])});

          expect(movies.length).toEqual(2);
          expect(movies.map((m) => m.name).toList()..sort()).toEqual([
              'Avatar',
              'Fury',
          ]);
        });

        it('should be able to filter on the absense of a property in a list', () async {
          var movies = await movieRepository.findAll(
              where: {'name': Is.notInList(['Avatar', 'Fury'])}
          );

          expect(movies.length).toEqual(4);
          expect(movies.map((m) => m.name).toList()..sort()).toEqual([
              'Bad Boys',
              'Bad Boys 3',
              'Bad Boys II',
              'The Green Mile',
          ]);
        });

        it('should be able to filter properties less than', () async {
          var movies = await movieRepository.findAll(where: {'year': Is.lessThan(2009)});
          var movies1 = await movieRepository.findAll(where: {'year': IS < 2009});

          expect(movies.length).toEqual(3);
          expect(movies.map((m) => m.year).toList()..sort()).toEqual([
              1995,
              1999,
              2003,
          ]);
          expect(movies1).toHaveSameProps(movies);
        });

        it('should be able to filter properties less than or equal to', () async {
          var movies = await movieRepository.findAll(where: {'year': Is.lessThanOrEqualTo(2009)});
          var movies1 = await movieRepository.findAll(where: {'year': IS <= 2009});

          expect(movies.length).toEqual(4);
          expect(movies.map((m) => m.year).toList()..sort()).toEqual([
              1995,
              1999,
              2003,
              2009,
          ]);
          expect(movies1).toHaveSameProps(movies);
        });

        it('should be able to filter properties greather than', () async {
          var movies = await movieRepository.findAll(where: {'year': Is.greaterThan(2009)});
          var movies1 = await movieRepository.findAll(where: {'year': IS > 2009});

          expect(movies.length).toEqual(1);
          expect(movies.map((m) => m.year).toList()..sort()).toEqual([
              2014,
          ]);
          expect(movies1).toHaveSameProps(movies);
        });

        it('should be able to filter properties greather than or equal to', () async {
          var movies = await movieRepository.findAll(where: {'year': Is.greaterThanOrEqualTo(2009)});
          var movies1 = await movieRepository.findAll(where: {'year': IS >= 2009});

          expect(movies.length).toEqual(2);
          expect(movies.map((m) => m.year).toList()..sort()).toEqual([
              2009,
              2014,
          ]);
          expect(movies1).toHaveSameProps(movies);
        });

        it('should be able to negate other filters', () async {
          var movies = await movieRepository.findAll(where: {'year': Is.not(IS > 2009)});

          expect(movies.length).toEqual(4);
          expect(movies.map((m) => m.year).toList()..sort()).toEqual([
              1995,
              1999,
              2003,
              2009,
          ]);

          movies = await movieRepository.findAll(
              where: {'name': Is.not(Is.inList(['Avatar', 'Fury']))}
          );

          expect(movies.length).toEqual(4);
          expect(movies.map((m) => m.name).toList()..sort()).toEqual([
              'Bad Boys',
              'Bad Boys 3',
              'Bad Boys II',
              'The Green Mile',
          ]);
        });

        it('should be able to filter on a regex', () async {
          var movies = await movieRepository.findAll(
              where: {'name': Do.match('Bad.*')}
          );

          expect(movies.length).toEqual(3);
          expect(movies.map((m) => m.name).toList()..sort()).toEqual([
              'Bad Boys',
              'Bad Boys 3',
              'Bad Boys II',
          ]);
        });

        it('should be able to combine filters', () async {
          var movies = await movieRepository.findAll(
              where: {'name': Do.match('Bad.*'), 'year': IS > 2000}
          );

          expect(movies.length).toEqual(1);
          expect(movies.map((m) => m.name).toList()..sort()).toEqual([
              'Bad Boys II',
          ]);

          movies = await movieRepository.findAll(
              where: {'name': Is.not('Avatar'), 'year': Do.exist}
          );

          expect(movies.length).toEqual(4);
          expect(movies.map((m) => m.name).toList()..sort()).toEqual([
              'Bad Boys',
              'Bad Boys II',
              'Fury',
              'The Green Mile'
          ]);
        });
      });
    });

    describe('cypher', () {
      it('should instanciate the returned nodes', () async {
        var recentMovies = await movieRepository.recentMovies;
        recentMovies = recentMovies.map((movie) => movie.name).toList()..sort();

        expect(recentMovies).toEqual(['Avatar', 'Fury']);
      });
    });

    it('should ignore values that have the same name as a method', () async {
      var entity = await specialsRepository.find({'method': 'Value on method'});

      expect(entity.method).toBeA(Function);
    });

    it('should ignore values that are private and only have a public getter', () async {
      var entity = await specialsRepository.find({'private': 5});

      expect(entity.private).toEqual(10);
    });

    it('should overwrite default values', () async {
      var entity = await specialsRepository.find({'defaultValue': 'changed'});

      expect(entity.defaultValue).toEqual('changed');
    });

    it('should be able to set private values that have a getter and a setter', () async {
      var entity = await specialsRepository.find({'gettersAndSetters': 5});

      expect(entity.gettersAndSetters).toEqual(4);
    });

    it('should ignore properties of wrong type', () async {
      var entity = await specialsRepository.find({'integer': 'String'});

      expect(entity.id).toBeNull();
      expect(entity.integer).toBeNull();
    });

    it('should be able to set via a setter', () async {
      var entity = await specialsRepository.find({'setter': 'set'});

      expect(entity.withSetter).toEqual('set');
    });

    it('should be able to save via a getter', () {
      var entity = new SpecialCases()
        ..gettersAndSetters = 15;

      specialsRepository.store(entity);

      var query = specialsRepository.saveChanges();
      return expect(query).toHaveWritten(
          '(a:SpecialCases {gettersAndSetters: 14, private: 10, defaultValue: "default"})'
      );
    });

    it('should be able to handle mixins', () async {
      var entity = new MixedIn();

      specialsRepository.store(entity);
      await specialsRepository.saveChanges();
    });
  });
}
