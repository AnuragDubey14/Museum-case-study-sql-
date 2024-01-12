create database MuseumCaseStudy;

SELECT TABLE_SCHEMA, TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE';


-- FETCH ALL THE TABLES DATA 

select * from artist;
select * from canvas_size;
select * from museum;
select * from museum_hours;
select * from product_size;
select * from subject;
select * from work;

-- 1. Fetch all the paintings which are not displayed on any museums?select * from workwhere museum_id is Null;-- 2. Are there museums without any paintings?select * from museum where museum_id not in (select museum_id from work);-- How many paintings have an asking price of more than their regular price?select count(work_id) as 'number of paintings'from product_size where sale_price>regular_price;-- 4. Identify the paintings whose asking price is less than 50% of its regular priceselect * from product_size where sale_price<regular_price*0.5;-- 5. Which canva size costs the most?with sale_price_rank as (SELECT size_id,sale_price, DENSE_RANK() over(order by sale_price desc) AS sale_price_rnk
    FROM product_size)SELECT cs.*,spr.sale_price
FROM canvas_size cs
INNER JOIN (select size_id,sale_price from sale_price_rank where sale_price_rnk=1
    ) spr ON cs.size_id = spr.size_id;


-- 6. Delete duplicate records from work, product_size and  subject tables
WITH CTE AS (
    SELECT work_id,
           ROW_NUMBER() OVER (PARTITION BY work_id ORDER BY work_id) AS RowNum
    FROM work
)
DELETE FROM CTE WHERE RowNum > 1;

WITH CTE AS (
    SELECT size_id,
           ROW_NUMBER() OVER (PARTITION BY work_id,size_id ORDER BY size_id) AS RowNum
    FROM product_size
)
DELETE FROM CTE WHERE RowNum > 1;


WITH CTE AS (
    SELECT work_id,
           ROW_NUMBER() OVER (PARTITION BY work_id,subject ORDER BY work_id) AS RowNum
    FROM subject
)
DELETE FROM CTE WHERE RowNum > 1;


-- 7. Identify the museums with invalid city information in the given dataset

select * from museum 
	where city like '[0-9]%'

-- 8. Museum_Hours table has 1 invalid entry. Identify it and remove it.
WITH CTE AS (
    SELECT museum_id,
           ROW_NUMBER() OVER (PARTITION BY museum_id,day ORDER BY museum_id) AS RowNum
    FROM museum_hours
)
DELETE FROM CTE WHERE RowNum > 1;

 -- 9. Fetch the top 10 most famous painting subjectselect * 
	from (
select s.subject,count(*) as 'number of paintings'
,rank() over(order by count(*) desc) as ranking
from work w
join subject s on s.work_id=w.work_id
group by s.subject ) famous_painting
	where ranking <= 10;


-- 10. Identify the museums which are open on both Sunday and Monday. Display museum name, city.

SELECT mh.museum_id, m.name, m.city
FROM museum_hours AS mh
INNER JOIN museum AS m ON m.museum_id = mh.museum_id
WHERE day = 'Sunday'
   AND mh.museum_id IN (
       SELECT museum_id
       FROM museum_hours
       WHERE day = 'Monday'
   );


-- 11. How many museums are open every single day?

select count(*) as 'Number of museums open everyday' from (
SELECT museum_id, COUNT(DISTINCT museum_id) AS museums_open_every_day
FROM museum_hours
WHERE day IN ('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday')
GROUP BY museum_id
HAVING COUNT(DISTINCT day) = 7) museums_that_open_everyday;



-- 12. Which are the top 5 most popular museum? (Popularity is defined based on most no of paintings in a museum)

select m.museum_id,m.name,m.city,m.state,m.country,mw.number_of_paintings from museum m  inner join 
(select top 5 museum_id, count(work_id) as number_of_paintings from work
where museum_id is not null
group by museum_id
order by 2 desc) mw on m.museum_id=mw.museum_id


-- 13. Who are the top 5 most popular artist? (Popularity is defined based on most no of paintings done by an artist)
select a.artist_id,a.full_name,a.nationality,a.style,aw.Number_of_paintings from artist a inner join
(select top 5 artist_id,count(work_id) as 'Number_of_paintings' from work
group by artist_id
order by 2 desc) aw on a.artist_id=aw.artist_id

-- 14. Display the 3 least popular canva sizes

select label,ranking,no_of_paintings
	from (
		select cs.size_id,cs.label,count(*) as no_of_paintings
		, dense_rank() over(order by count(*) ) as ranking
		from work w
		join product_size ps on ps.work_id=w.work_id
		join canvas_size cs on cs.size_id = ps.size_id
		group by cs.size_id,cs.label) rank_canva_size
	where rank_canva_size.ranking<=3;

-- 15. Which museum is open for the longest during a day. Dispay museum name, state and hours open and which day?
WITH OpenDuration AS (
    SELECT
        mh.museum_id,
        m.name AS museum_name,
        m.state,
        mh.day,
        mh.[open],
        mh.[close],
        DATEDIFF(HOUR, mh.[open], mh.[close]) AS duration_hour,
        RANK() OVER (ORDER BY DATEDIFF(HOUR, mh.[open], mh.[close]) DESC) AS rnK
    FROM
        museum_hours mh
    JOIN
        museum m ON mh.museum_id = m.museum_id
)
SELECT
    museum_id,
    museum_name,
    state,
    day,
    [open] AS opening_time,
    [close] AS closing_time,
    duration_hour
FROM
    OpenDuration
WHERE
    rnK = 1;


	
-- 16. Which museum has the most no of most popular painting style?
WITH PopularStyles AS (
    SELECT style,
     RANK() OVER (ORDER BY COUNT(work_id) DESC) AS style_rank
    FROM work
    WHERE style IS NOT NULL
    GROUP BY style
)
SELECT m.*, mw.most_popular_style
FROM museum m
INNER JOIN (
    SELECT museum_id, style AS most_popular_style,
        COUNT(work_id) AS style_count
    FROM work
    WHERE style IN (SELECT style FROM PopularStyles WHERE style_rank = 1)
    AND museum_id IS NOT NULL
    GROUP BY museum_id, style
) mw ON m.museum_id = mw.museum_id
ORDER BY mw.style_count DESC;



-- 17. Identify the artists whose paintings are displayed in multiple countries
SELECT a.full_name, m.country
FROM artist a
INNER JOIN work w ON a.artist_id = w.artist_id
INNER JOIN museum m ON w.museum_id = m.museum_id
GROUP BY a.full_name, m.country
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC, a.full_name ASC;


-- 18. Display the country and the city with most no of museums. Output 2 seperate 
-- columns to mention the city and country. If there are multiple value, seperate them with comma.

WITH cte_country AS (
    SELECT
        country, COUNT(*) AS country_count,
        RANK() OVER (ORDER BY COUNT(*) DESC) AS rnk
    FROM museum
    GROUP BY country
),
cte_city AS (
    SELECT
        city, COUNT(*) AS city_count,
        RANK() OVER (ORDER BY COUNT(*) DESC) AS rnk
    FROM museum
    GROUP BY city
)
SELECT
    (SELECT STRING_AGG(country, ', ') FROM cte_country WHERE rnk = 1) AS most_museums_country,
    (SELECT STRING_AGG(city, ', ') FROM cte_city WHERE rnk = 1) AS most_museums_city;



-- 19. Identify the artist and the museum where the most expensive and least expensive
-- painting is placed. Display the artist name, sale_price, painting name, museum name, museum city and canvas label


WITH RankedWorks AS (
    SELECT
        work_id,
        sale_price,
        Rank() OVER (ORDER BY sale_price ASC) AS ascending_rank,
        Rank() OVER (ORDER BY sale_price DESC) AS descending_rank
    FROM product_size
    WHERE sale_price IS NOT NULL
)

select a.full_name,ps.sale_price,w.name,m.name,m.city,cs.label from product_size ps inner join work as w on w.work_id=ps.work_id
inner join artist as a on a.artist_id=w.artist_id
inner join museum as m on m.museum_id=w.museum_id
inner join canvas_size as cs on cs.size_id=ps.size_id
 where ps.work_id in (SELECT
    work_id
FROM RankedWorks
WHERE
    ascending_rank = 1 OR descending_rank = 1
);


-- 20. Which country has the 5th highest no of paintings?
with painting_rank_table as(
select country,count(work_id) as Number_of_paintings,
dense_rank() over(order by count(work_id) desc) as painting_rank
from work as w inner join museum as m on w.museum_id=m.museum_id
group by country)

select country,  Number_of_paintings from painting_rank_table
where painting_rank=5;


-- 21. Which are the 3 most popular and 3 least popular painting styles?with most_least_popular_style as (select style,
dense_rank() over(order by count(work_id) desc) as desc_rank,
dense_rank() over(order by count(work_id)) as asc_rank 
from work
group by style)

select style from most_least_popular_style
where desc_rank<=3 or asc_rank<=3;



-- 22. Which artist has the most no of Portraits paintings outside USA?. Display artist
-- name, no of paintings and the artist nationality

select top 1 a.full_name,count(work_id) as 'Number_of_paintings',a.nationality from work w inner join artist a
on w.artist_id=a.artist_id
inner join museum m on m.museum_id=w.museum_id
where m.country<>'USA'
group by w.artist_id,a.full_name,a.nationality
order by 2 desc;