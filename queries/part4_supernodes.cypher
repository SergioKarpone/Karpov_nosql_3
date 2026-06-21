//  Частина 4. Виявлення супервузлів

// 1. Топ-20 фільмів за ступенем (кількістю вхідних RATED)
MATCH (m:Movie)
RETURN m.title AS title,
       COUNT { (m)<-[:RATED]-() } AS ratingCount
ORDER BY ratingCount DESC
LIMIT 20;

// 1b. Жанрові вузли — це ще більші супервузли (за HAS_GENRE)
MATCH (g:Genre)
RETURN g.name AS genre,
       COUNT { (g)<-[:HAS_GENRE]-() }            AS movieCount,
       COUNT { (g)<-[:HAS_GENRE]-(:Movie)<-[:RATED]-() } AS ratingReach
ORDER BY ratingReach DESC;

// 1c. Розподіл ступенів — щоб «аномально велике» було видно числами
MATCH (m:Movie)
WITH COUNT { (m)<-[:RATED]-() } AS deg
RETURN min(deg)   AS minDeg,
       percentileCont(deg, 0.5)  AS medianDeg,
       percentileCont(deg, 0.95) AS p95Deg,
       max(deg)   AS maxDeg,
       avg(deg)   AS avgDeg;
