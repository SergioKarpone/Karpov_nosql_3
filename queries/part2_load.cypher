//  Частина 2. Завантаження даних (локальний Neo4j в Docker)

// 2.1 ОБМЕЖЕННЯ (CONSTRAINTS) - створюємо ПЕРЕД завантаженням
CREATE CONSTRAINT user_id  IF NOT EXISTS FOR (u:User)  REQUIRE u.userId  IS UNIQUE;
CREATE CONSTRAINT movie_id IF NOT EXISTS FOR (m:Movie) REQUIRE m.movieId IS UNIQUE;
CREATE CONSTRAINT genre_nm IF NOT EXISTS FOR (g:Genre) REQUIRE g.name    IS UNIQUE;

// Перевірка, що індекси/обмеження активні:
SHOW CONSTRAINTS;
SHOW INDEXES;

// 2.2 ВУЗЛИ User
LOAD CSV WITH HEADERS FROM 'file:///users.csv' AS row
MERGE (u:User {userId: toInteger(row.userId)})
SET u.gender     = row.gender,
    u.age        = toInteger(row.age),
    u.occupation = toInteger(row.occupation);

// 2.3 Вузли Movie + Genre + ребра HAS_GENRE
LOAD CSV WITH HEADERS FROM 'file:///movies.csv' AS row
MERGE (m:Movie {movieId: toInteger(row.movieId)})
SET m.title = row.title,
    m.year  = toInteger(row.year)
WITH m, row
UNWIND split(row.genres, '|') AS genreName
MERGE (g:Genre {name: genreName})
MERGE (m)-[:HAS_GENRE]->(g);

// 2.4 Ребра RATED - батчами через apoc.periodic.iterate
CALL apoc.periodic.iterate(
  "LOAD CSV WITH HEADERS FROM 'file:///ratings.csv' AS row RETURN row",
  "MATCH (u:User  {userId:  toInteger(row.userId)})
   MATCH (m:Movie {movieId: toInteger(row.movieId)})
   MERGE (u)-[r:RATED]->(m)
   SET r.rating    = toInteger(row.rating),
       r.timestamp = toInteger(row.timestamp)",
  {batchSize: 10000, parallel: false}
)
YIELD batches, total, errorMessages
RETURN batches, total, errorMessages;

// 2.5 Перевірка результату
MATCH (u:User)             RETURN count(u) AS users;
MATCH (m:Movie)            RETURN count(m) AS movies;
MATCH (g:Genre)            RETURN count(g) AS genres;
MATCH ()-[r:RATED]->()     RETURN count(r) AS ratings;
MATCH ()-[h:HAS_GENRE]->() RETURN count(h) AS hasGenre;
