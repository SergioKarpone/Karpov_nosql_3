//  Частина 3. Запити різної складності

// Запит 1 (базовий). Фільми жанру Thriller із середнім рейтингом > 4.0
MATCH (m:Movie)-[:HAS_GENRE]->(:Genre {name: 'Thriller'})
MATCH (m)<-[r:RATED]-()
WITH m, avg(r.rating) AS avgRating, count(r) AS numRatings
WHERE avgRating > 4.0
RETURN m.title AS title, round(avgRating, 2) AS avgRating, numRatings
ORDER BY avgRating DESC, numRatings DESC;

// Запит 2 (базовий). Користувачі, які поставили «5» більш ніж 50 фільмам
MATCH (u:User)-[r:RATED]->(m:Movie)
WHERE r.rating = 5
WITH u, count(m) AS numFiveStars
WHERE numFiveStars > 50
RETURN u.userId AS userId, numFiveStars
ORDER BY numFiveStars DESC;


// Запит 3 (середній). Фільми, які userId=1 і userId=2 обидва оцінили >= 4
MATCH (u1:User {userId: 1})-[r1:RATED]->(m:Movie)<-[r2:RATED]-(u2:User {userId: 2})
WHERE r1.rating >= 4 AND r2.rating >= 4
RETURN m.title       AS title,
       r1.rating     AS rating_user1,
       r2.rating     AS rating_user2
ORDER BY title;


// Запит 4 (середній). Жанри зі стабільно високими оцінками
MATCH (g:Genre)<-[:HAS_GENRE]-(:Movie)<-[r:RATED]-()
WITH g, avg(r.rating) AS avgRating, count(r) AS numRatings
RETURN g.name AS genre, round(avgRating, 3) AS avgRating, numRatings
ORDER BY avgRating DESC;


// Запит 5 (складний). Колаборативна рекомендація:
// «користувачі зі схожими смаками також дивилися»
MATCH (target:User {userId: 1})-[tr:RATED]->(:Movie)
WHERE tr.rating >= 4
WITH target, count(*) AS _seed   // лише щоб зафіксувати target у пайплайні

MATCH (target)-[r1:RATED]->(common:Movie)<-[r2:RATED]-(other:User)
WHERE r1.rating >= 4 AND r2.rating >= 4 AND other <> target
WITH target, other, count(common) AS overlap
ORDER BY overlap DESC
LIMIT 50                          // 50 найсхожіших сусідів

MATCH (other)-[r3:RATED]->(rec:Movie)
WHERE r3.rating >= 4
  AND NOT EXISTS { (target)-[:RATED]->(rec) }   // target ще не дивився
WITH rec, count(DISTINCT other) AS recommendedBy, avg(r3.rating) AS neighAvg
RETURN rec.title       AS title,
       recommendedBy,
       round(neighAvg, 2) AS neighboursAvg
ORDER BY recommendedBy DESC, neighboursAvg DESC
LIMIT 10;


// Запит 6 (складний). Найкоротший ланцюжок між двома користувачами
// через спільні фільми
MATCH path = shortestPath(
  (u1:User {userId: 1})-[:RATED*..6]-(u2:User {userId: 5000})
)
RETURN
  length(path) AS pathLength,
  [n IN nodes(path) |
     CASE WHEN n:User  THEN 'User#'  + toString(n.userId)
          WHEN n:Movie THEN 'Movie:' + n.title
     END] AS chain;
