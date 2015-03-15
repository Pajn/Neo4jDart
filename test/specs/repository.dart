library node_repository_spec;

import '../helpers.dart';
import '../helpers/domain.dart';

main() {
  var db = setUp();

  describe('repository', () {
    Repository<Actor> actorRepository;
    MovieRepository movieRepository;
    Movie avatar, badBoys, cars, cars2, fury, theGreenMile, up;

    beforeEach(() async {
      actorRepository = new Repository<Actor>(db);
      movieRepository = new MovieRepository(db);

      cars = new Movie()
        ..name = 'Cars'
        ..year = 2006;
      cars2 = new Movie()
        ..name = 'Cars 2'
        ..year = 2011
        ..predecessor = cars;
      up = new Movie()
        ..name = 'Up'
        ..year = 2009;

      await setUpTestData();

      avatar = await movieRepository.find('name', 'Avatar');
      badBoys = await movieRepository.find('name', 'Bad Boys');
      fury = await movieRepository.find('name', 'Fury');
      theGreenMile = await movieRepository.find('name', 'The Green Mile');
    });

    it('should be able to create a node', () {
      movieRepository.store(up);

      var query = movieRepository.saveChanges();
      return expect(query).toHaveWritten('(a:Movie {name:"Up", year:2009})');
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
        expect(badBoys1.cast.role).toEqual('Mike Lowrey');
        expect(badBoys1.cast.start.name).toEqual('Will Smith');
        expect(badBoys1.cast.start.actedIn).toBe(badBoys1.cast);
        expect(badBoys1.cast.start).toBeA(Actor);
        expect(badBoys1.cast.end).toBe(badBoys1);
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
        expect(badBoys1.sequel.cast.start.name).toEqual('Will Smith');
        expect(badBoys1.sequel.sequel.year).toBeNull();
        expect(badBoys1.sequel.cast.start).toBe(badBoys1.cast.start);
        expect(badBoys1.sequel.cast).not.toBe(badBoys1.cast);
        expect(badBoys1.sequel.sequel.predecessor).toBe(badBoys1.sequel);
        expect(badBoys1.sequel.predecessor).toBe(badBoys1);
        expect(badBoys1.sequel.sequel.sequel).toBeNull();
        expect(badBoys1.predecessor).toBeNull();
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
    });

    describe('cypher', () {
      it('should instanciate the returned nodes', () async {
        var recentMovies = await movieRepository.recentMovies;
        recentMovies = recentMovies.map((movie) => movie.name).toList()..sort();

        expect(recentMovies).toEqual(['Avatar', 'Fury']);
      });
    });
  });
}
