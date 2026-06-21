//  ЧАСТИНА 5 — ГРАФОВІ АЛГОРИТМИ (GDS)


//  5.1  PageRank на графі фільмів
// 1: матеріалізуємо ребра фільм–фільм через спільних користувачів,
// які обидва фільми оцінили високо. weight = скільки таких користувачів.
MATCH (m1:Movie)<-[r1:RATED]-(u:User)-[r2:RATED]->(m2:Movie)
WHERE r1.rating >= 4 AND r2.rating >= 4 AND id(m1) < id(m2)
WITH m1, m2, count(u) AS weight
WHERE COUNT { (m1)<-[:RATED]-() } > 20
  AND COUNT { (m2)<-[:RATED]-() } > 20
WITH m1, m2, weight
ORDER BY weight DESC
LIMIT 50000
MERGE (m1)-[co:CO_RATED]-(m2)
SET co.weight = weight;

// 2: проєкція в пам'ять GDS
CALL gds.graph.project(
  'movieGraph',
  'Movie',
  { CO_RATED: { orientation: 'UNDIRECTED', properties: 'weight' } }
)
YIELD graphName, nodeCount, relationshipCount;

// 3: PageRank (зважений)
CALL gds.pageRank.stream('movieGraph', {
  relationshipWeightProperty: 'weight',
  maxIterations: 20,
  dampingFactor: 0.85
})
YIELD nodeId, score
WITH gds.util.asNode(nodeId) AS movie, score
RETURN movie.title AS title,
       movie.year  AS year,
       round(score, 4) AS pageRank,
       COUNT { (movie)<-[:RATED]-() } AS ratingCount
ORDER BY score DESC
LIMIT 20;

// 4: прибираємо проєкцію та тимчасові ребра
CALL gds.graph.drop('movieGraph');
MATCH ()-[co:CO_RATED]-() DELETE co;


//  5.2-5.3  Граф схожості користувачів (Louvain + Dijkstra)
// 1: матеріалізуємо SIMILAR батчами
CALL apoc.periodic.iterate(
  "MATCH (u1:User) RETURN u1",
  "MATCH (u1)-[r1:RATED]->(m:Movie)<-[r2:RATED]-(u2:User)
   WHERE r1.rating = 5 AND r2.rating = 5 AND id(u1) < id(u2)
   WITH u1, u2, count(m) AS weight
   WHERE weight >= 3
   MERGE (u1)-[sim:SIMILAR]-(u2)
   SET sim.weight = weight",
  {batchSize: 50, parallel: false}
)
YIELD batches, total, errorMessages
RETURN batches, total, errorMessages;

// 2: проєкція графа схожості
CALL gds.graph.project(
  'userSimilarity',
  'User',
  { SIMILAR: { orientation: 'UNDIRECTED', properties: 'weight' } }
)
YIELD graphName, nodeCount, relationshipCount;

// 5.2 Louvain
// 3a: записуємо communityId у вузли + дивимось modularity і к-сть спільнот
CALL gds.louvain.write('userSimilarity', {
  relationshipWeightProperty: 'weight',
  writeProperty: 'community'
})
YIELD communityCount, modularity, modularities;

// 3b: 10 найбільших спільнот за розміром
MATCH (u:User)
WHERE u.community IS NOT NULL
WITH u.community AS community, count(*) AS communitySize
RETURN community, communitySize
ORDER BY communitySize DESC
LIMIT 10;

// 3c: для 10 найбільших спільнот — топ-3 жанри (фільми з оцінкою >= 4).
MATCH (u:User)
WHERE u.community IS NOT NULL
WITH u.community AS community, count(*) AS sz
ORDER BY sz DESC LIMIT 10
WITH collect(community) AS topCommunities
MATCH (u:User)-[r:RATED]->(:Movie)-[:HAS_GENRE]->(g:Genre)
WHERE r.rating >= 4 AND u.community IN topCommunities
WITH u.community AS community, g.name AS genre, count(*) AS cnt
ORDER BY community, cnt DESC
WITH community, collect(genre)[0..3] AS top3Genres, sum(cnt) AS totalHighRatings
RETURN community, top3Genres, totalHighRatings
ORDER BY totalHighRatings DESC;

// 5.3 Dijkstra
MATCH (source:User {userId: 1}), (target:User {userId: 5000})
CALL gds.shortestPath.dijkstra.stream('userSimilarity', {
  sourceNode: source,
  targetNode: target,
  relationshipWeightProperty: 'weight'
})
YIELD totalCost, nodeIds, costs
RETURN
  totalCost,
  size(nodeIds) - 1 AS hops,
  [nodeId IN nodeIds | gds.util.asNode(nodeId).userId] AS userChain;

// Прибирання: проєкція, тимчасові ребра, властивість community.
CALL gds.graph.drop('userSimilarity');

CALL apoc.periodic.iterate(
  "MATCH ()-[sim:SIMILAR]-() RETURN sim",
  "DELETE sim",
  {batchSize: 10000, parallel: false}
)
YIELD batches, total
RETURN batches, total;

MATCH (u:User) WHERE u.community IS NOT NULL REMOVE u.community;
