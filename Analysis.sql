-- Apple Retails 1 Millions+ Rows Sales Schemas


-- DROP TABLE command
DROP TABLE IF EXISTS warranty;
DROP TABLE IF EXISTS sales;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS category; 
DROP TABLE IF EXISTS stores; 

-- CREATE TABLE commands

CREATE TABLE stores(
store_id VARCHAR(5) PRIMARY KEY,
store_name	VARCHAR(30),
city	VARCHAR(25),
country VARCHAR(25)
);

DROP TABLE IF EXISTS category;
CREATE TABLE category
(category_id VARCHAR(10) PRIMARY KEY,
category_name VARCHAR(20)
);

CREATE TABLE products
(
product_id	VARCHAR(10) PRIMARY KEY,
product_name	VARCHAR(35),
category_id	VARCHAR(10),
launch_date	date,
price FLOAT,
CONSTRAINT fk_category FOREIGN KEY (category_id) REFERENCES category(category_id)
);

CREATE TABLE sales
(
sale_id	VARCHAR(15) PRIMARY KEY,
sale_date	DATE,
store_id	VARCHAR(10), -- this fk
product_id	VARCHAR(10), -- this fk
quantity INT,
CONSTRAINT fk_store FOREIGN KEY (store_id) REFERENCES stores(store_id),
CONSTRAINT fk_product FOREIGN KEY (product_id) REFERENCES products(product_id)
);

CREATE TABLE warranty
(
claim_id VARCHAR(10) PRIMARY KEY,	
claim_date	date,
sale_id	VARCHAR(15),
repair_status VARCHAR(15),
CONSTRAINT fk_orders FOREIGN KEY (sale_id) REFERENCES sales(sale_id)
);

-- Success Message
SELECT 'Schema created successful' as Success_Message;

/*
-- Import data set to created tables one after the other:
1. Import first to Category TABLE -- parent table
2. Import to Product Table
3. Import to Stores Table -- parent table
4. Import to Sales TABLE
5. Import to Warranty Table
*/

 -- CHECK TABLES

 SELECT * FROM category
 SELECT * FROM products
 SELECT * FROM stores
 SELECT * FROM sales
 SELECT * FROM warranty
 
  -- EDA
-- #category
SELECT distinct(category_id) from category
-- 10 category of products

-- #products
SELECT distinct(product_name) from products
-- 63 different products

-- #stores
SELECT distinct(store_id) from stores
--73 stores total
SELECT distinct(country) from stores
-- worldwide
SELECT count(distinct(country)) from stores
-- 35 countries
SELECT count(distinct(city)) from stores
-- 68 countries

-- #sales
SELECT distinct(Extract (year from sale_date) ) from sales
SELECT distinct(Extract (month from sale_date) ) from sales
 -- sales data spread across 2019 - 2024

-- #warranty
SELECT distinct(repair_status) from warranty
 -- 3 different status

-- Improving query performance

-- et = 74 ms
-- pt = 0.078 ms
-- after index 
-- et = 5 ms
-- pt = 0.103 ms
 EXPLAIN ANALYSE
 SELECT * FROM sales WHERE product_id = 'P-44'

 CREATE INDEX sales_product_id ON sales(product_id)

-- et = 111 ms
-- pt = 0.114 ms
-- after index 
-- et = 2 ms
-- pt = 2.366 ms

EXPLAIN ANALYSE
SELECT * FROM sales WHERE store_id = 'ST-33'

CREATE INDEX sales_store_id ON sales(store_id)

-- et = 179 ms
-- pt = 0.923 ms
-- after index 
-- et = 3.36 ms
-- pt = 0.908 ms

EXPLAIN ANALYSE
SELECT * FROM sales WHERE sale_date = '2022=01-06'

CREATE INDEX sales_sale_date ON sales(sale_date)

-- Analyse Business Problems

-- 1. Find the number of stores in each country

SELECT 
	country, 
	count(*) as total_stores 
FROM stores 
Group by 1
Order by  2 DESC

-- 2. Calcuate the total number of unit sold by each store

( SELECT 
	s.store_id, 
	st.store_name,
	sum(s.quantity) as total_units
FROM sales s 
JOIN 
stores st
ON st.store_id = s.store_id
GROUP BY 1, 2
ORDER By 3 DESC)

-- 3. Identify how much sales occurred in December 2023

SELECT sum(quantity) from sales where extract(year from sale_date) = 2023 AND extract(month from sale_date) = 12

-- OR

SELECT sum(quantity) FROM sales WHERE to_char(sale_date, 'YYYY-MM') = '2023-12'

-- 4. Determine how many stores have never had a warranty claim filed?

SELECt * FROM warranty
SELECT * FROM stores
SELECT * FROM sales

-- Step 1: All the sales where we ahve had a warranty

SELECT * 
FROM sales s
RIGHT JOIN warranty w
ON s.sale_id = w.sale_id

-- step 2: finding unique stores which have had these claims

SELECT distinct(store_id) 
FROM sales s
RIGHT JOIN warranty w
ON s.sale_id = w.sale_id

-- Step 3: Get all the stores which are different from these

SELECT store_id, store_name from stores where store_id NOT In (
SELECT distinct(store_id) 
FROM sales s
RIGHT JOIN warranty w
ON s.sale_id = w.sale_id)

-- Check: over all 73 different stores, of which 15 had warranty claims, remaining are 73 - 15 = 58

-- 5. Calcualte the % of warranty claim marked as "warranty_void"

SELECT repair_status, count(*) from warranty group by repair_status 

SELECT round
	       (count(*)/ 
					(SELECT count(*) FROM  warranty):: numeric
				* 100
		,2)
FROM warranty 
Where repair_status = 'Warranty Void'

-- 6.  Identify which stores had the highest total units sold in the last year

SELECT * from sales

-- STEP 1: Find all sales in last 1 year

SELECT * FROM sales where sale_date >= (CURRENT_DATE - interval '1 year')

-- STEP 2: group by store_id and find sum of sales at each store, order by total sales in descending, limit 1

SELECT 
	store_id, 
	sum(quantity) as total_unit_sold 
FROM 
	sales 
WHERE sale_date >= (CURRENT_DATE - interval '1 year')
Group by 1
ORDER by  2 DESC
LIMIT 1

-- 7. Count the number of unique product sold in the last year

SELECT * from products
SELECT * from sales

STEP 1: Table used product, plus sales,
Find all the unique product_id with sale_date in last 1 year interval, the put count

SELECT 
count(distinct(product_id))
FROM 
	sales 
WHERE sale_date >= (Current_date - interval '1 year')

-- 8. Find the average price of products in each category

SELECT * from products
SELECT * from category

SELECT category_name, avg(price)
from 
products p 
join category c 
ON p.category_id = c.category_id
Group By 1
Order by 2

-- Check

SELECT sum(price)/count(*)
from 
products p 
join category c 
ON p.category_id = c.category_id
WHERE category_name = 'Tablet'

-- 9. How many warranty claims were filed in 2020

SELECT count(distinct(claim_id)) from warranty WHERE Extract(Year from claim_date) = '2020'

-- 10. For each store find the best-selling day (dates) based on the highest quantity sold

SELECT * from sales
SELECT * from stores

We need all the stores names with date on sale_date and quantity sold in one table. We dont need the dat of the stores where a sale didnot take place as it cant be the highest selling store anyways.

SO a inner join is ok

STEP 1: Join store and sales data

SELECT * FROM 
(
SELECT 
 st.store_name, 
 st.store_id, 
 s.sale_date, 
 sum(s.quantity) as unit_sold, 
 Rank() over(partition by st.store_id ORDER BY  sum(s.quantity) DESC ) AS Rank
FROM 
	sales s 
Join 
	stores st 
ON 
	st.store_id = s.store_id
GROUP BY 
	st.store_name, st.store_id, s.sale_date
ORDER BY st.store_id
) AS t1

WHERE Rank = 1

 Rank() over(partition by Extract(Year FROM sale_date) ORDER By avg(total_sale) DESC ) AS rank

-- 11. For each store find the best-selling days (weekdays) based on the highest quantity sold

-- Step 1: Add day_name to the sales table, and then group by stores and day name to get total sales per store per 

SELECT
		st.store_id, st.store_name,t1.Day_name, t1.total_sales
FROM
	(
	SELECT 
		store_id,
		to_char(sale_date, 'Day') AS Day_name, 
		sum(quantity) AS total_sales,
		Rank() over(partition by store_id ORDER BY  sum(quantity) DESC ) AS Rank
	FROM
		sales
	GROUP BY 
		store_id, day_name 
	) AS t1 
JOIN 
	stores st
ON 
	t1.store_id = st.store_id
WHERE RANK = 1

-- 12. Identify the least selling product in each country for each year based on total units sold

SELECT * from sales
SELECT * from stores
SELECT * from products

SELECT 
country, product_name, total_units_sold

FROM 
	(
		SELECT 
		st.country,
		p.product_name, 
		sum(s.quantity) as total_units_sold,
		rank() OVER( PARTITION BY country order by sum(s.quantity) ASC) AS Rank
		FROM sales s
		JOIN products p
		On s.product_id = p.product_id
		JOIN stores st
		ON s.store_id = st.store_id  
		Group by 1, 2
	)
WHERE Rank = 1

--12. Calculate how many warranty claims were filed within 180 days of product sale

SELECT * from sales
SELECT * from warranty

-- Steps: For all the warranty claims, map it to respective sale_date from sales table, find the date_diff, count where diff <=180

SELECT
COUNT(*)
FROM
	(SELECT
	*,
	w.claim_date - s.sale_date AS date_diff
	FROM warranty w
	JOIN sales s
	ON w.sale_id = s.sale_id
	)AS t1
WHERE date_diff <= 180

-- OR

SELECT
	count(*)
	FROM warranty w
	JOIN sales s
	ON w.sale_id = s.sale_id
WHERE w.claim_date - s.sale_date <=180

-- 13. Determine how many warranty claims were filed for each products that were launched in last two years

SELECT p.product_name,
count(w.claim_id),
count(s.sale_id)
from warranty w
RIGHT Join sales s
ON 
w.sale_id = s.sale_id
JOIN products p
ON s.product_id = p.product_id
where p.launch_date >= CURRENT_DATE - interval '2 year'
GROUP BY p.product_name 
Having count(w.claim_id) > 0

-- 14. List the months in the last three years where sales exceed 5000 units in USA


SELECT * from stores

SELECT 
to_char(sale_date, 'YYYY') AS sale_year,
to_char(sale_date, 'Month') AS sale_month,
to_char(sale_date, 'MM') AS sale_month_num,
sum(s.quantity) AS total_units_sold
from 
	sales s JOIN stores st
ON 
	s.store_id = st.store_id
WHERE sale_date >= CURRENT_Date - interval '3 year'
AND st.country = 'USA'
GROUP BY
1, 2, 3
HAVING sum(s.quantity) > 5000
ORDER BY 1, 3, 4

-- 15. Identify the product category with the most warranty claim in the last two years

SELECT c.category_name, count(claim_id) AS total_warranty_claims
from products p
LEFT JOIN category c
ON c.category_id = p.category_id 
JOIN sales s
ON p.product_id = s.product_id
JOIN warranty w
ON s.sale_id = w.sale_id
WHERE w.claim_date >= CURRENT_Date - interval '2 year'
GROUP BY 1
ORDER By 2 DESC
LIMIT 1

-- 16. Determine the % chance of receiving warranty claims after each purchase for each country

-- Logic: country - total claims / total sales

SELECT 
	country,
	Total_sales,
	Total_warranty_claims,
	coalesce(Total_warranty_claims:: numeric/Total_sales:: numeric * 100, 0 ) as risk
FROM
	( Select 
			st.country,
			sum(s.quantity) as Total_sales,
			count(w.claim_id) as Total_warranty_claims
	from 
		sales s
		Join 
			stores st
		ON 
			st.store_id = s.store_id
		LEFT 
			JOIN warranty w
		ON 
			s.sale_id = w.sale_id
	GROUP BY 1
	) as t1
	ORDER BY 4 DESC


-- 17. Analyse the year by year growth ratio for each store
-- STEPS: Get total sales of each store for each year 
-- use a lag funtion, calcuate the % change

WITH yearly_sales as
		( SELECT 
		st.store_id,
		st.store_name,
		To_char(sale_date, 'YYYY') as sale_year,
		sum(s.quantity * p.price) as total_sales
		from sales s
		JOIN
		stores st
		ON s.store_id = st.store_id
		JOIN products p
		ON s.product_id = p.product_id
		GROUP By 1, 2,3
		ORDER BY 1, 3 ASC),
growth_ratio
AS (
SELECT 
	store_name, 
	sale_year, 
	lag(total_sales, 1) OVER (PARTITION BY store_name order by sale_year) as last_year_sales,
	total_sales as current_year_sales
FROM yearly_sales
)
SELECT
	store_name, 
	sale_year, 
	((current_year_sales::numeric - last_year_sales::numeric )/ last_year_sales::numeric )* 100 as growth_rate_YOY
FROM growth_ratio
WHERE last_year_sales IS NOT NULL

-- 18. Calculate the correlation between product price and warranty claims for product sold in the last 5 years, segmented by price range

SELECT 
CASE
	WHEN p.Price < 500 THEN 'budget_products'
	WHEN p.Price Between 500 AND 1000 THEN 'mid_range'
	ELSE 'Premium_products'
END As price_segments,
count(w.claim_id)
from warranty w
JOIN sales s
ON w.sale_id = s.sale_id
JOIN products p
ON p.product_id = s.product_id
WHERE w.claim_date >= CURRENT_DATE - interval '5 year'
GROUP BY 1
-- negative correlation (claim reduces as price gets premium)

-- 19. Identify the store with the highest % of "paid repaired" claims relative to total claims filed
total claim per store which have repair status = "paid repaired" / Total claims per store 

WITH paid_repaired
AS (
	select 
		s.store_id, 
		count(w.claim_id) as total_paid_repairs
	from sales as s
	join warranty as w
	on w.sale_id = s.sale_id
	Where w.repair_status = 'Paid Repaired'
	Group by 1
)
,
total_repair
AS (
	select 
		s.store_id, 
		count(w.claim_id) as total_repairs
	from sales as s
	join warranty as w
	on w.sale_id = s.sale_id
	Group by 1
)
SELECT t1.store_id, st.store_name, t2.total_paid_repairs::numeric/ t1.total_repairs::numeric *100 as percentage_paid_repair_claims
FROM total_repair t1 JOIN  paid_repaired t2
on t1.store_id = t2.store_id
JOIN stores st
ON t1.store_id = st.store_id
ORDER By 3 DESC
LIMIT 1

-- 20. Write a query to caluclate the monthly running total of sales for each store over the past 4 years and compare trends during this period
WITH
monthly_sales 
AS
		(
		SELECT
		s.store_id,
		to_char(sale_date,'MM') AS sale_month,
		to_char(sale_date,'YYYY') AS sale_year,
		sum(s.quantity*p.price) as total_sales
		from sales s
		Join products p
		ON p.product_id = s.product_id
		WHERE s.sale_date > current_date - interval '4 year'
		GROUP By 1,2,3
		ORDER By 1
		)
SELECT
	 store_id,
	 sale_month,
	 sale_year,
	 total_sales,
	 sum(total_sales) OVER(PARTITION BY store_id ORDER By sale_year, sale_month)
FROM 
monthly_sales
ORDER By  store_id

 