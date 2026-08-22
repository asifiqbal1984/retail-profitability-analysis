
USE retail_inventory_db;
SELECT * FROM retail_inventory_db.retail_data;

--------------1-
SELECT
    Subcategory,
    ROUND(SUM(Price * (1 - Discount / 100) * Units_Sold), 2) AS Total_Revenue,
    ROUND(SUM((Price * (1 - Discount / 100) - Cost) * Units_Sold), 2) AS Total_Profit,
    ROUND(
        SUM((Price * (1 - Discount / 100) - Cost) * Units_Sold)
        / NULLIF(SUM(Price * (1 - Discount / 100) * Units_Sold), 0) * 100
    , 2) AS Profit_Percent
FROM retail_data
GROUP BY Subcategory
ORDER BY Total_Profit DESC;

-------------------------2-
WITH product_metrics AS (
    SELECT
        Product_ID,
        MAX(Category)    AS Category,
        MAX(Subcategory) AS Subcategory,
        ROUND(SUM(Price * (1 - Discount / 100) * Units_Sold), 2) AS Total_Revenue,
        ROUND(SUM((Price * (1 - Discount / 100) - Cost) * Units_Sold), 2) AS Total_Profit,
        ROUND(
            SUM((Price * (1 - Discount / 100) - Cost) * Units_Sold)
            / NULLIF(SUM(Price * (1 - Discount / 100) * Units_Sold), 0) * 100
        , 2) AS Profit_Percent
    FROM retail_data
    GROUP BY Product_ID
),
ranked AS (
    SELECT
        *,
        RANK() OVER (ORDER BY Total_Revenue DESC)  AS Revenue_Rank,
        RANK() OVER (ORDER BY Profit_Percent ASC)  AS Margin_Rank
    FROM product_metrics
)
SELECT
    Product_ID,
    Category,
    Subcategory,
    Total_Revenue,
    Total_Profit,
    Profit_Percent,
    Revenue_Rank,
    Margin_Rank
FROM ranked
WHERE Revenue_Rank <= 10
  AND Margin_Rank <= 10
ORDER BY Revenue_Rank;

---------------
SELECT
COUNT(DISTINCT(Subcategory))
FROM retail_data;

----------------------3-
 SELECT
    Product_ID,
    ROUND(AVG((Price - Cost) / Price) * 100, 2) AS Avg_Breakeven_Discount_Percent,
    ROUND(MIN((Price - Cost) / Price) * 100, 2) AS Most_Fragile_Product_Breakeven_Percent
FROM retail_data
GROUP BY Product_ID
ORDER BY Avg_Breakeven_Discount_Percent;

---------------------4-
SELECT
    Category,
    CASE
        WHEN Discount = 0                      THEN '0% (No Discount)'
        WHEN Discount BETWEEN 0.01 AND 10       THEN '1-10%'
        WHEN Discount BETWEEN 10.01 AND 20      THEN '11-20%'
        WHEN Discount BETWEEN 20.01 AND 30      THEN '21-30%'
        WHEN Discount BETWEEN 30.01 AND 40      THEN '31-40%'
        WHEN Discount BETWEEN 40.01 AND 50      THEN '41-50%'
        ELSE '50%+'
    END AS Discount_Band,
    COUNT(*) AS Transaction_Count,
    ROUND(SUM(Price * (1 - Discount / 100) * Units_Sold), 2) AS Total_Revenue,
    ROUND(SUM((Price * (1 - Discount / 100) - Cost) * Units_Sold), 2) AS Total_Profit,
    ROUND(
        SUM((Price * (1 - Discount / 100) - Cost) * Units_Sold)
        / NULLIF(SUM(Price * (1 - Discount / 100) * Units_Sold), 0) * 100
    , 2) AS Profit_Margin_Percent
FROM retail_data
GROUP BY Category, Discount_Band
ORDER BY Category,
    CASE Discount_Band
        WHEN '0% (No Discount)' THEN 0
        WHEN '1-10%'            THEN 1
        WHEN '11-20%'           THEN 2
        WHEN '21-30%'           THEN 3
        WHEN '31-40%'           THEN 4
        WHEN '41-50%'           THEN 5
        ELSE 6
    END;

-------------------5-
WITH monthly_metrics AS (
    SELECT
        DATE_FORMAT(
            COALESCE(
                STR_TO_DATE(Sales_Date, '%m/%d/%Y'),
                STR_TO_DATE(Sales_Date, '%Y-%m-%d'),
                STR_TO_DATE(Sales_Date, '%d-%m-%Y'),
                STR_TO_DATE(Sales_Date, '%d/%m/%Y')
            ),
            '%Y-%m-01'
        ) AS Sales_Month,
        ROUND(SUM(Price * (1 - Discount / 100) * Units_Sold), 2) AS Total_Revenue,
        ROUND(SUM((Price * (1 - Discount / 100) - Cost) * Units_Sold), 2) AS Total_Profit
    FROM retail_data
    GROUP BY Sales_Month
),
monthly_margin AS (
    SELECT
        Sales_Month,
        Total_Revenue,
        Total_Profit,
        ROUND(Total_Profit / NULLIF(Total_Revenue, 0) * 100, 2) AS Profit_Margin_Percent
    FROM monthly_metrics
)
SELECT
    Sales_Month,
    Total_Revenue,
    Total_Profit,
    Profit_Margin_Percent,
    ROUND(Profit_Margin_Percent - LAG(Profit_Margin_Percent) OVER (ORDER BY Sales_Month), 2) AS MoM_Margin_Change_pp,
    CASE
        WHEN LAG(Profit_Margin_Percent) OVER (ORDER BY Sales_Month) IS NULL THEN 'Baseline (first month)'
        WHEN Profit_Margin_Percent - LAG(Profit_Margin_Percent) OVER (ORDER BY Sales_Month) > 0.5  THEN 'Improving'
        WHEN Profit_Margin_Percent - LAG(Profit_Margin_Percent) OVER (ORDER BY Sales_Month) < -0.5 THEN 'Eroding'
        ELSE 'Flat'
    END AS Trend_Flag
FROM monthly_margin
WHERE Sales_Month IS NOT NULL
ORDER BY Sales_Month;



-----------------------6-
WITH supplier_metrics AS (
    SELECT
        Supplier_ID,
        COUNT(DISTINCT Product_ID) AS Product_Count,
        SUM(Units_Sold) AS Total_Units_Sold,
        ROUND(SUM(Price * (1 - Discount / 100) * Units_Sold), 2) AS Total_Revenue,
        ROUND(SUM((Price * (1 - Discount / 100) - Cost) * Units_Sold), 2) AS Total_Profit
    FROM retail_data
    GROUP BY Supplier_ID
),
supplier_margin AS (
    SELECT
        *,
        ROUND(Total_Profit / NULLIF(Total_Revenue, 0) * 100, 2) AS Profit_Margin_Percent
    FROM supplier_metrics
),
company_avg AS (
    SELECT ROUND(AVG(Profit_Margin_Percent), 2) AS Avg_Margin_Percent
    FROM supplier_margin
)
SELECT
    sm.Supplier_ID,
    sm.Product_Count,
    sm.Total_Units_Sold,
    sm.Total_Revenue,
    sm.Total_Profit,
    sm.Profit_Margin_Percent,
    ca.Avg_Margin_Percent AS Company_Avg_Margin_Percent,
    ROUND(sm.Profit_Margin_Percent - ca.Avg_Margin_Percent, 2) AS Margin_vs_Avg_pp,
    ROUND((ca.Avg_Margin_Percent - sm.Profit_Margin_Percent) / 100 * sm.Total_Revenue, 2) AS Potential_Profit_Uplift,
    RANK() OVER (ORDER BY sm.Profit_Margin_Percent DESC) AS Margin_Rank,
    CASE
        WHEN sm.Profit_Margin_Percent < ca.Avg_Margin_Percent
             AND PERCENT_RANK() OVER (ORDER BY sm.Total_Revenue DESC) <= 0.5
            THEN 'High-Priority Renegotiation'
        WHEN sm.Profit_Margin_Percent < ca.Avg_Margin_Percent
            THEN 'Renegotiation Candidate'
        ELSE 'Healthy Margin'
    END AS Supplier_Flag
FROM supplier_margin sm
CROSS JOIN company_avg ca
ORDER BY sm.Profit_Margin_Percent DESC;
