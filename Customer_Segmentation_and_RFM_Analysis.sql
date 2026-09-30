create database retail_db;
use retail_db;

create table online_retail (Invoice varchar(100), Stock_Code varchar(200), Description varchar(200), Quantity int, Invoice_Date datetime,Price float,Customer_Id int,Country varchar(100));

load data infile "C:\\ProgramData\\MySQL\\MySQL Server 8.0\\Uploads\\online_retail_II.csv" into table online_retail fields terminated by ',' enclosed by '"' lines terminated by '\n' ignore 1 rows
(
    Invoice,
    Stock_Code,
    Description,
    Quantity,
    Invoice_Date,
    Price,
    @Customer_Id,
    Country
)
SET Customer_Id = NULLIF(@Customer_Id, '');

select * from online_retail;

## 1.-------------------------------How are customers distributed across the different RFM segments,-----------------------------------------

CREATE VIEW RFM_Segment AS(
with rfm_cte as
(
select Customer_ID,
DATEDIFF(DATE_ADD(
                  (SELECT MAX(Invoice_Date) 
                   from online_retail 
                   where Invoice not like "C%" 
                   and Customer_Id IS NOT NULL
                   and Quantity > 0 and Price > 0), INTERVAL 1 DAY), MAX(Invoice_Date)) as Recency,
COUNT(DISTINCT Invoice) as Frequency,
ROUND(SUM(Quantity * Price),2) as Monetary
from online_retail
where Invoice not like "C%" 
and Customer_Id IS NOT NULL
and Quantity > 0 and Price > 0
group by Customer_ID
)
,rfm_score as
(
select Customer_Id,
Recency,
Frequency,
Monetary,
NTILE(5) OVER(ORDER BY Recency DESC) AS Recency_Score,
NTILE(5) OVER(ORDER BY Frequency ) AS Frequency_Score,
NTILE(5) OVER(ORDER BY Monetary ) AS Monetary_Score
from rfm_cte
)
,rfm_Segment as
(
select Customer_Id,
Recency,
Frequency,
Monetary,
Recency_Score,
Frequency_Score,
Monetary_Score,
CASE 
    WHEN Recency_Score >=4 and Frequency_Score >=4 and Monetary_Score >= 4 THEN "Champions"
    WHEN Recency_Score >=3 and Frequency_Score >=4 THEN "Loyal Customers"
    WHEN Recency_Score >=4 and Frequency_Score <=2 THEN "New Customers"
    WHEN Recency_Score <= 2 and Frequency_Score >=3 THEN "At-Risk Customers"
    WHEN Recency_Score <=2 and Frequency_Score <=2 and Monetary_Score <=2 THEN "Inactive Customers"
    ELSE "Potential Customers"
    END AS Customer_Segment
from rfm_Score
)
select * from rfm_Segment
);

## ----------------------and what are the average Recency, Frequency, and Monetary values for each segment?--------------------------------
with rfm_cte as
(
select Customer_ID,
DATEDIFF(DATE_ADD(
                  (SELECT MAX(Invoice_Date) 
                   from online_retail 
                   where Invoice not like "C%" 
                   and Customer_Id IS NOT NULL
                   and Quantity > 0 and Price > 0), INTERVAL 1 DAY), MAX(Invoice_Date)) as Recency,
COUNT(DISTINCT Invoice) as Frequency,
ROUND(SUM(Quantity * Price),2) as Monetary
from online_retail
where Invoice not like "C%" 
and Customer_Id IS NOT NULL
and Quantity > 0 and Price > 0
group by Customer_ID
)
,rfm_score as
(
select Customer_Id,
Recency,
Frequency,
Monetary,
NTILE(5) OVER(ORDER BY Recency DESC) AS Recency_Score,
NTILE(5) OVER(ORDER BY Frequency ) AS Frequency_Score,
NTILE(5) OVER(ORDER BY Monetary ) AS Monetary_Score
from rfm_cte
)
,rfm_Segment as
(
select Customer_Id,
Recency,
Frequency,
Monetary,
Recency_Score,
Frequency_Score,
Monetary_Score,
CASE 
    WHEN Recency_Score >=4 and Frequency_Score >=4 and Monetary_Score >= 4 THEN "Champions"
    WHEN Recency_Score >=3 and Frequency_Score >=4 THEN "Loyal Customers"
    WHEN Recency_Score >=4 and Frequency_Score <=2 THEN "New Customers"
    WHEN Recency_Score <= 2 and Frequency_Score >=3 THEN "At-Risk Customers"
    WHEN Recency_Score <=2 and Frequency_Score <=2 and Monetary_Score <=2 THEN "Inactive Customers"
    ELSE "Potential Customers"
    END AS Customer_Segment
from rfm_Score
)
select Customer_Segment,
COUNT(*) AS Total_Customers,
ROUND(AVG(Recency),2) as Avg_Recency,
ROUND(AVG(Frequency),2) as AVG_Frequency,
ROUND(AVG(Monetary),2) as AVG_Monetary,
ROUND(SUM(Monetary),2) as Total_Monetary
from rfm_Segment
GROUP BY Customer_Segment;

## 2.--------------------------------How much revenue does each RFM segment contribute to the overall revenue?--------------------------------------

with rfm_cte as
(
select Customer_ID,
DATEDIFF(DATE_ADD(
                  (SELECT MAX(Invoice_Date) 
                   from online_retail 
                   where Invoice not like "C%" 
                   and Customer_Id IS NOT NULL ), INTERVAL 1 DAY), MAX(Invoice_Date)) as Recency,
COUNT(DISTINCT Invoice) as Frequency,
ROUND(SUM(Quantity * Price),2) as Monetary
from online_retail
where Invoice not like "C%" 
and Customer_Id IS NOT NULL
and Quantity > 0 and Price > 0
group by Customer_ID
)
,rfm_score as
(
select Customer_Id,
Recency,
Frequency,
Monetary,
NTILE(5) OVER(ORDER BY Recency DESC) AS Recency_Score,
NTILE(5) OVER(ORDER BY Frequency ) AS Frequency_Score,
NTILE(5) OVER(ORDER BY Monetary ) AS Monetary_Score
from rfm_cte
)
,rfm_Segment as
(
select Customer_Id,
Recency,
Frequency,
Monetary,
Recency_Score,
Frequency_Score,
Monetary_Score,
CASE 
    WHEN Recency_Score >=4 and Frequency_Score >=4 and Monetary_Score >= 4 THEN "Champions"
    WHEN Recency_Score >=3 and Frequency_Score >=4 THEN "Loyal Customers"
    WHEN Recency_Score >=4 and Frequency_Score <=2 THEN "New Customers"
    WHEN Recency_Score <= 2 and Frequency_Score >=3 THEN "At-Risk Customers"
    WHEN Recency_Score <=2 and Frequency_Score <=2 and Monetary_Score <=2 THEN "Inactive Customers"
    ELSE "Potential Customers"
    END AS Customer_Segment
from rfm_Score
)
select Customer_Segment,
CONCAT(ROUND(SUM(Monetary)/(SELECT SUM(Monetary) from rfm_Segment) * 100,2), "%") as Revenue_Contribution
from rfm_Segment
GROUP BY Customer_Segment
ORDER BY Revenue_Contribution;

## 3.---------------------------What percentage of the total customers belongs to each RFM segment?----------------------------

with rfm_cte as
(
select Customer_ID,
DATEDIFF(DATE_ADD(
                  (SELECT MAX(Invoice_Date) 
                   from online_retail 
                   where Invoice not like "C%" 
                   and Customer_Id IS NOT NULL
                   and Quantity > 0 and Price > 0), INTERVAL 1 DAY), MAX(Invoice_Date)) as Recency,
COUNT(DISTINCT Invoice) as Frequency,
ROUND(SUM(Quantity * Price),2) as Monetary
from online_retail
where Invoice not like "C%" 
and Customer_Id IS NOT NULL
and Quantity > 0 and Price > 0
group by Customer_ID
)
,rfm_score as
(
select Customer_Id,
Recency,
Frequency,
Monetary,
NTILE(5) OVER(ORDER BY Recency DESC) AS Recency_Score,
NTILE(5) OVER(ORDER BY Frequency ) AS Frequency_Score,
NTILE(5) OVER(ORDER BY Monetary ) AS Monetary_Score
from rfm_cte
)
,rfm_Segment as
(
select Customer_Id,
Recency,
Frequency,
Monetary,
Recency_Score,
Frequency_Score,
Monetary_Score,
CASE 
    WHEN Recency_Score >=4 and Frequency_Score >=4 and Monetary_Score >= 4 THEN "Champions"
    WHEN Recency_Score >=3 and Frequency_Score >=4 THEN "Loyal Customers"
    WHEN Recency_Score >=4 and Frequency_Score <=2 THEN "New Customers"
    WHEN Recency_Score <= 2 and Frequency_Score >=3 THEN "At-Risk Customers"
    WHEN Recency_Score <=2 and Frequency_Score <=2 and Monetary_Score <=2 THEN "Inactive Customers"
    ELSE "Potential Customers"
    END AS Customer_Segment
from rfm_Score
)
select Customer_Segment,
CONCAT(ROUND(COUNT(*)/(SELECT COUNT(*) from rfm_Segment) * 100,2), "%") as Customer_Contribution
from rfm_Segment
GROUP BY Customer_Segment
ORDER BY Customer_Contribution DESC;

## 4.--------------------------Top 10 highest-value customers based on their monetary value-------------------------------------

with rfm_cte as
(
select Customer_ID,
DATEDIFF(DATE_ADD(
                  (SELECT MAX(Invoice_Date) 
                   from online_retail 
                   where Invoice not like "C%" 
                   and Customer_Id IS NOT NULL
                   and Quantity > 0 and Price > 0), INTERVAL 1 DAY), MAX(Invoice_Date)) as Recency,
COUNT(DISTINCT Invoice) as Frequency,
ROUND(SUM(Quantity * Price),2) as Monetary
from online_retail
where Invoice not like "C%" 
and Customer_Id IS NOT NULL
and Quantity > 0 and Price > 0
group by Customer_ID
)
,rfm_score as
(
select Customer_Id,
Recency,
Frequency,
Monetary,
NTILE(5) OVER(ORDER BY Recency DESC) AS Recency_Score,
NTILE(5) OVER(ORDER BY Frequency ) AS Frequency_Score,
NTILE(5) OVER(ORDER BY Monetary ) AS Monetary_Score
from rfm_cte
)
,rfm_Segment as
(
select Customer_Id,
Recency,
Frequency,
Monetary,
Recency_Score,
Frequency_Score,
Monetary_Score,
CASE 
    WHEN Recency_Score >=4 and Frequency_Score >=4 and Monetary_Score >= 4 THEN "Champions"
    WHEN Recency_Score >=3 and Frequency_Score >=4 THEN "Loyal Customers"
    WHEN Recency_Score >=4 and Frequency_Score <=2 THEN "New Customers"
    WHEN Recency_Score <= 2 and Frequency_Score >=3 THEN "At-Risk Customers"
    WHEN Recency_Score <=2 and Frequency_Score <=2 and Monetary_Score <=2 THEN "Inactive Customers"
    ELSE "Potential Customers"
    END AS Customer_Segment
from rfm_Score
)
select Customer_Id,
SUM(Monetary) as Revenue
from rfm_Segment
GROUP BY Customer_Id
ORDER BY Revenue DESC LIMIT 10;

