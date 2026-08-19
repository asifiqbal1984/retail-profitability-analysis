WITH baseline AS (
    SELECT
        Category,
        ROUND(AVG(Units_Sold), 2) AS Baseline_Avg_Units
    FROM retail_data
    WHERE Promotion_Type = 'None'
    GROUP BY Category
),
promo_stats AS (
    SELECT
        Category,
        Promotion_Type,
        COUNT(*) AS Transaction_Count,
        ROUND(AVG(Units_Sold), 2) AS Avg_Units_Sold,
        ROUND(SUM(Price * (Discount / 100) * Units_Sold), 2) AS Total_Discount_Dollars
    FROM retail_data
    WHERE Promotion_Type <> 'None'
    GROUP BY Category, Promotion_Type
)
SELECT
    ps.Category,
    ps.Promotion_Type,
    ps.Transaction_Count,
    b.Baseline_Avg_Units,
    ps.Avg_Units_Sold,
    ROUND(ps.Avg_Units_Sold - b.Baseline_Avg_Units, 2) AS Avg_Unit_Lift,
    ps.Total_Discount_Dollars,
    ROUND(
        (ps.Avg_Units_Sold - b.Baseline_Avg_Units) * ps.Transaction_Count
        / NULLIF(ps.Total_Discount_Dollars, 0)
    , 4) AS Lift_Units_Per_Discount_Dollar
FROM promo_stats ps
JOIN baseline b ON ps.Category = b.Category
ORDER BY Lift_Units_Per_Discount_Dollar DESC;



---------
WITH product_promo AS (
    SELECT
        Product_ID,
        MAX(Category)    AS Category,
        MAX(Subcategory) AS Subcategory,
        SUM(CASE WHEN Promotion_Type <> 'None' THEN 1 ELSE 0 END) AS Promo_Count,
        SUM(CASE WHEN Promotion_Type = 'None'  THEN 1 ELSE 0 END) AS Baseline_Count,
        ROUND(AVG(CASE WHEN Promotion_Type <> 'None' THEN Units_Sold END), 2) AS Avg_Units_Sold_Promo,
        ROUND(AVG(CASE WHEN Promotion_Type = 'None'  THEN Units_Sold END), 2) AS Avg_Units_Sold_Baseline,
        ROUND(SUM(CASE WHEN Promotion_Type <> 'None' THEN Price * (Discount / 100) * Units_Sold ELSE 0 END), 2) AS Total_Discount_Dollars_Spent
    FROM retail_data
    GROUP BY Product_ID
)
SELECT
    Product_ID,
    Category,
    Subcategory,
    Promo_Count,
    Baseline_Count,
    Avg_Units_Sold_Promo,
    Avg_Units_Sold_Baseline,
    ROUND(Avg_Units_Sold_Promo - Avg_Units_Sold_Baseline, 2) AS Sales_Lift,
    Total_Discount_Dollars_Spent,
    CASE
        WHEN Baseline_Count = 0 THEN 'No Baseline Data - Cannot Assess'
        WHEN Avg_Units_Sold_Promo - Avg_Units_Sold_Baseline <= 0 THEN 'Wasted Budget - No Lift'
        WHEN Avg_Units_Sold_Promo - Avg_Units_Sold_Baseline < 0.1 * Avg_Units_Sold_Baseline THEN 'Wasted Budget - Minimal Lift'
        ELSE 'Responsive to Promotion'
    END AS Promo_Effectiveness_Flag
FROM product_promo
WHERE Promo_Count >= 5
ORDER BY Promo_Count DESC, Sales_Lift ASC;




--------
WITH product_avg_daily_revenue AS (
    SELECT
        Product_ID,
        ROUND(AVG(Price * (1 - Discount / 100) * Units_Sold), 2) AS Avg_Daily_Revenue
    FROM retail_data
    GROUP BY Product_ID
),
latest_snapshot AS (
    SELECT
        Product_ID,
        Category,
        Subcategory,
        Sale_Date,
        Stock_Level,
        Reorder_Point,
        Lead_Time_Days
    FROM (
        SELECT
            Product_ID,
            Category,
            Subcategory,
            STR_TO_DATE(Sales_Date, '%m/%d/%Y') AS Sale_Date,
            Stock_Level,
            Reorder_Point,
            Lead_Time_Days,
            ROW_NUMBER() OVER (PARTITION BY Product_ID ORDER BY STR_TO_DATE(Sales_Date, '%m/%d/%Y') DESC) AS rn
        FROM retail_data
    ) t
    WHERE rn = 1
)
SELECT
    ls.Product_ID,
    ls.Category,
    ls.Subcategory,
    ls.Sale_Date AS As_Of_Date,
    ls.Stock_Level,
    ls.Reorder_Point,
    ls.Lead_Time_Days,
    ROUND(ls.Stock_Level / NULLIF(ls.Reorder_Point, 0), 2) AS Stock_To_Reorder_Ratio,
    padr.Avg_Daily_Revenue,
    ROUND(padr.Avg_Daily_Revenue * ls.Lead_Time_Days, 2) AS Revenue_At_Risk,
    CASE
        WHEN ls.Stock_Level <= ls.Reorder_Point        THEN 'Critical - At/Below Reorder Point'
        WHEN ls.Stock_Level <= ls.Reorder_Point * 1.2  THEN 'High Risk - Near Reorder Point'
        ELSE 'Healthy'
    END AS Stockout_Risk_Level
FROM latest_snapshot ls
JOIN product_avg_daily_revenue padr ON ls.Product_ID = padr.Product_ID
WHERE ls.Stock_Level <= ls.Reorder_Point * 1.2
ORDER BY Revenue_At_Risk DESC;


----------
SELECT
    Supplier_ID,
    COUNT(DISTINCT Product_ID) AS Product_Count,
    COUNT(*) AS Total_Records,
    ROUND(AVG(Lead_Time_Days), 2) AS Avg_Lead_Time_Days,
    SUM(CASE WHEN CAST(Backorder_Flag AS UNSIGNED) = 1 THEN 1 ELSE 0 END) AS Backorder_Count,
    ROUND(SUM(CASE WHEN CAST(Backorder_Flag AS UNSIGNED) = 1 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS Backorder_Rate_Percent,
    SUM(CASE WHEN CAST(Stockout_Alert AS UNSIGNED) = 1 THEN 1 ELSE 0 END) AS Stockout_Count,
    ROUND(SUM(CASE WHEN CAST(Stockout_Alert AS UNSIGNED) = 1 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS Stockout_Rate_Percent,
    RANK() OVER (ORDER BY AVG(Lead_Time_Days) DESC) AS Lead_Time_Rank,
    RANK() OVER (ORDER BY SUM(CASE WHEN CAST(Backorder_Flag AS UNSIGNED) = 1 THEN 1 ELSE 0 END) / COUNT(*) DESC) AS Backorder_Rank
FROM retail_data
GROUP BY Supplier_ID
ORDER BY Avg_Lead_Time_Days DESC;






------------------
SELECT
    Category,
    ROUND(AVG(CASE WHEN CAST(Is_Holiday AS UNSIGNED) = 1 THEN Units_Sold END), 2) AS Avg_Units_Holiday,
    ROUND(AVG(CASE WHEN CAST(Is_Holiday AS UNSIGNED) = 0 THEN Units_Sold END), 2) AS Avg_Units_Non_Holiday,
    ROUND(
        (AVG(CASE WHEN CAST(Is_Holiday AS UNSIGNED) = 1 THEN Units_Sold END)
        - AVG(CASE WHEN CAST(Is_Holiday AS UNSIGNED) = 0 THEN Units_Sold END))
        / NULLIF(AVG(CASE WHEN CAST(Is_Holiday AS UNSIGNED) = 0 THEN Units_Sold END), 0) * 100
    , 2) AS Holiday_Lift_Percent,
    ROUND(SUM(CASE WHEN CAST(Is_Holiday AS UNSIGNED) = 1 THEN Price * (1 - Discount / 100) * Units_Sold ELSE 0 END), 2) AS Total_Holiday_Revenue
FROM retail_data
GROUP BY Category
ORDER BY Holiday_Lift_Percent DESC;



----------

WITH weather_corr AS (
    SELECT
        Category,
        COUNT(*) AS Transaction_Count,
        (COUNT(*) * SUM(Weather_Index * Units_Sold) - SUM(Weather_Index) * SUM(Units_Sold))
        /
        (SQRT(COUNT(*) * SUM(POW(Weather_Index, 2)) - POW(SUM(Weather_Index), 2))
         * SQRT(COUNT(*) * SUM(POW(Units_Sold, 2)) - POW(SUM(Units_Sold), 2))) AS Raw_Correlation
    FROM retail_data
    GROUP BY Category
)
SELECT
    Category,
    Transaction_Count,
    ROUND(Raw_Correlation, 4) AS Correlation_Weather_vs_UnitsSold
FROM weather_corr
ORDER BY ABS(Raw_Correlation) DESC;



--------------------------
SELECT
    Category,
    CASE
        WHEN Weather_Index < 20 THEN '0-19'
        WHEN Weather_Index < 40 THEN '20-39'
        WHEN Weather_Index < 60 THEN '40-59'
        WHEN Weather_Index < 80 THEN '60-79'
        ELSE '80-100'
    END AS Weather_Index_Band,
    COUNT(*) AS Transaction_Count,
    ROUND(AVG(Units_Sold), 2) AS Avg_Units_Sold
FROM retail_data
GROUP BY Category, Weather_Index_Band
ORDER BY Category,
    CASE
        WHEN Weather_Index_Band = '0-19'  THEN 0
        WHEN Weather_Index_Band = '20-39' THEN 1
        WHEN Weather_Index_Band = '40-59' THEN 2
        WHEN Weather_Index_Band = '60-79' THEN 3
        ELSE 4
    END;


    ------------------
    SELECT
    Category,
    SUM(Units_Sold) AS Total_Units_Sold,
    SUM(Return_Units) AS Total_Return_Units,
    ROUND(SUM(Return_Units) / NULLIF(SUM(Units_Sold), 0) * 100, 2) AS Return_Rate_Percent
FROM retail_data
GROUP BY Category
ORDER BY Return_Rate_Percent DESC;


------------
-- Best Value Suppliers (Weighted Score) nnnn
WITH supplier_value AS (
    SELECT
        Supplier_ID,
        COUNT(DISTINCT Product_ID) AS product_count,
        AVG(Cost) AS avg_cost,
        AVG(Price) AS avg_price,
        AVG(Price - Cost) AS avg_margin,
        SUM(Return_Units) AS total_returns,
        SUM(Units_Sold) AS total_sold,
        ROUND(SUM(Return_Units) / NULLIF(SUM(Units_Sold), 0) * 100, 2) AS return_rate,
        AVG(Lead_Time_Days) AS avg_lead_time,
        SUM(Units_Ordered) AS total_ordered,
        SUM(Units_Received) AS total_received,
        ROUND(SUM(Units_Received) / NULLIF(SUM(Units_Ordered), 0) * 100, 2) AS fulfillment_rate,
        COUNT(CASE WHEN Backorder_Flag = '1' OR Backorder_Flag = 'TRUE' THEN 1 END) AS backorder_events
    FROM retail_data
    GROUP BY Supplier_ID
),
value_score AS (
    SELECT
        *,
        -- Normalize metrics (0-100 scale)
        (100 - (avg_cost - MIN(avg_cost) OVER()) / NULLIF((MAX(avg_cost) OVER() - MIN(avg_cost) OVER()), 0) * 100) AS cost_score,
        (100 - (return_rate - MIN(return_rate) OVER()) / NULLIF((MAX(return_rate) OVER() - MIN(return_rate) OVER()), 0) * 100) AS quality_score,
        (100 - (avg_lead_time - MIN(avg_lead_time) OVER()) / NULLIF((MAX(avg_lead_time) OVER() - MIN(avg_lead_time) OVER()), 0) * 100) AS delivery_score,
        (fulfillment_rate - MIN(fulfillment_rate) OVER()) / NULLIF((MAX(fulfillment_rate) OVER() - MIN(fulfillment_rate) OVER()), 0) * 100 AS reliability_score,
        -- Weighted overall score (weights: cost 30%, quality 30%, delivery 40%)
        ((100 - (avg_cost - MIN(avg_cost) OVER()) / NULLIF((MAX(avg_cost) OVER() - MIN(avg_cost) OVER()), 0) * 100) * 0.3) +
        ((100 - (return_rate - MIN(return_rate) OVER()) / NULLIF((MAX(return_rate) OVER() - MIN(return_rate) OVER()), 0) * 100) * 0.3) +
        ((100 - (avg_lead_time - MIN(avg_lead_time) OVER()) / NULLIF((MAX(avg_lead_time) OVER() - MIN(avg_lead_time) OVER()), 0) * 100) * 0.4) AS value_score
    FROM supplier_value
)
SELECT
    Supplier_ID,
    product_count,
    ROUND(avg_cost, 2) AS avg_product_cost,
    ROUND(avg_price, 2) AS avg_selling_price,
    ROUND(avg_margin, 2) AS avg_profit_margin,
    ROUND(return_rate, 2) AS return_rate_pct,
    ROUND(avg_lead_time, 1) AS avg_lead_time_days,
    ROUND(fulfillment_rate, 2) AS fulfillment_rate_pct,
    backorder_events,
    ROUND(cost_score, 2) AS cost_score,
    ROUND(quality_score, 2) AS quality_score,
    ROUND(delivery_score, 2) AS delivery_score,
    ROUND(value_score, 2) AS overall_value_score,
    CASE
        WHEN value_score >= 80 THEN 'Excellent Value Supplier'
        WHEN value_score >= 60 THEN 'Good Value Supplier'
        WHEN value_score >= 40 THEN 'Average Value Supplier'
        ELSE 'Poor Value Supplier - Consider Replacement'
    END AS supplier_category
FROM value_score
ORDER BY value_score DESC;


--------------------

SELECT
    Product_ID,
    MAX(Category)    AS Category,
    MAX(Subcategory) AS Subcategory,
    SUM(Units_Sold) AS Total_Units_Sold,
    SUM(Return_Units) AS Total_Return_Units,
    ROUND(SUM(Return_Units) / NULLIF(SUM(Units_Sold), 0) * 100, 2) AS Return_Rate_Percent
FROM retail_data
GROUP BY Product_ID
HAVING Total_Units_Sold >= 50
ORDER BY Return_Rate_Percent DESC
LIMIT 10;


----------
