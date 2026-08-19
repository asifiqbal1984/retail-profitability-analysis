# Retail Profitability & Risk Analysis

A retail business with 54,800+ transactions across 3 years (2023–2025) had no clear view of *where* its margin was actually being won or lost — only that overall numbers looked "fine." I set out to answer that with SQL first, then Tableau, to separate rigorous analysis from communication.

**The approach:** 14 business questions, answered first in MySQL using CTEs and window functions (RANK, LAG, PERCENT_RANK) to keep the logic transparent and auditable — then the highest-impact findings were rebuilt as an interactive Tableau dashboard so a non-technical stakeholder could explore them without reading a query.

**What the data showed:**

Four Electronics products — smartwatches and cameras — were quietly the weakest earners in the entire catalog despite being top-10 revenue drivers, each running margins around 33% while the company average sits near 34%. High volume was masking thin returns.

One supplier, S004, was both the company's largest revenue partner and its lowest-margin one — a single renegotiation target worth an estimated $273K in recoverable profit, with two more suppliers (S015, S014) adding another $224K combined.

Discounting past 30% is where the real risk lives: Beauty, Clothing, Home, and Sports categories flip to loss-making at the 31–40% discount band, while Electronics, Grocery, and Toys hold profitable until 41–50%. Below 30%, every category stays solidly profitable.

Margin isn't eroding — it's seasonal. Profit margin has been flat for three years (28%–36% range) with a predictable dip every November and June that rebounds the following month.

Two popular assumptions didn't hold up: weather has virtually no measurable relationship with sales in any category, and longer supplier lead times do not predict more stockouts — the opposite pattern showed up in the data.

**The result:** a reusable Tableau dashboard surfacing $180K+ in recoverable profit and the exact discount thresholds where categories turn unprofitable, backed by a fully auditable SQL layer showing how every number was derived.

**Tools:** MySQL (CTEs, window functions, manual statistical calculation) · Tableau (LOD expressions, parameters, calculated fields, dashboard design)

**[View the interactive dashboard + data story on Tableau Public →]()**  ·  **SQL files: `PORTFOLIO_DATABASE.sql`, `portfolio11.sql`** (in this repo)

---

## SQL Analysis — 14 Business Questions

MySQL analysis of 54,800+ retail transactions (Jan 2023–Sep 2025 · 7 categories · 29 subcategories · 16 suppliers) answering 14 real business questions, plus one bonus supplier-scoring model. Each query uses CTEs and window functions (`RANK()`, `LAG()`, `PERCENT_RANK()`, `ROW_NUMBER()`) rather than app-side post-processing — the analysis is done entirely in SQL.

### 1. Which subcategories are most/least profitable?
**Insight:** Smartwatches, Smartphones, Accessories, Shoes, and Cameras are the top 5 most profitable subcategories.
*(Query 1 in `PORTFOLIO_DATABASE.sql`)*

### 2. Which products are top-10 by revenue but bottom-10 by margin?
**Insight:** Only 4 products — P0002, P0004, P0006, P0007 (all Electronics) — land in both lists. They drive high volume but return comparatively thin margins (~33%).
*(Query 2 in `PORTFOLIO_DATABASE.sql`)*

### 3. How much discount can each product absorb before it loses money?
**Insight:** Discount room is fairly uniform catalog-wide (34.2%–35.9% avg), but every product has hit a shared ~15% margin floor at least once — P0024 is the most fragile on record at 14.98%.
*(Query 3 in `PORTFOLIO_DATABASE.sql`)*

### 4. At what discount level does each category start losing money?
**Insight:** Beauty, Clothing, Home, and Sports flip to loss-making at 31–40% discount; Electronics, Grocery, and Toys hold profitable through 31–40% and only turn negative at 41–50%.
*(Query 4 in `PORTFOLIO_DATABASE.sql`)*

### 5. Is profit margin improving, flat, or eroding over time?
**Insight:** Margin is flat over 3 years (oscillating 28%–36%), with a recurring seasonal squeeze every November and June that rebounds the following month.
*(Query 5 in `PORTFOLIO_DATABASE.sql`)*

### 6. Which suppliers have the healthiest margins, and who should we renegotiate with?
**Insight:** S002, S019, and S011 are healthiest (34.3%–34.8%, above the 33.93% company average). S004 is the top renegotiation target — a $273K potential profit uplift, followed by S015 ($164K) and S014 ($60K).
*(Query 6 in `PORTFOLIO_DATABASE.sql`)*

### 7. Which promotion type generates the best sales lift per discount dollar?
**Insight:** BuyXGetY in Grocery is the top performer (0.0693 units/discount $); Electronics lags across every promo type (≤0.0023).
*(Query 1 in `portfolio11.sql`)*

### 8. Are any products promoted repeatedly with little sales response?
**Insight:** No — every product flags "Responsive to Promotion." Even the weakest cases, P0011 and P0041, clear the meaningful-lift threshold.
*(Query 2 in `portfolio11.sql`)*

### 9. Which products are at the highest stockout risk, and what's the revenue at risk?
**Insight:** 4 products flagged at risk. P0042 (Sports/Outdoor) carries the highest exposure at $48,036 in revenue at risk.
*(Query 3 in `portfolio11.sql`)*

### 10. Do longer supplier lead times mean more backorders/stockouts?
**Insight:** No — the opposite pattern holds. S005 and S013 have the longest lead times (24–25 days) with zero backorders, while shorter-lead-time suppliers post the worst backorder/stockout rates.
*(Query 4 in `portfolio11.sql`)*

### 11. How much does holiday timing lift sales, and which categories benefit most?
**Insight:** Holiday timing lifts every category, from +37% (Sports) to +192% (Toys). Toys wins on % lift; Electronics wins on dollar impact ($3.19M).
*(Query 5 in `portfolio11.sql`)*

### 12. Is there a measurable relationship between weather and sales?
**Insight:** No — the relationship is negligible everywhere. Even the strongest correlation (Grocery, 0.0772) is far below the ~0.2 "weak relationship" threshold. Pearson's r calculated manually in raw SQL.
*(Query 6 in `portfolio11.sql`)*

### 13. Is the weather effect linear, or does it peak at a threshold?
**Insight:** Most categories stay flat across weather bands. Grocery and Sports only spike in the extreme 80–100 band — a threshold effect, not a gradual trend.
*(Query 7 in `portfolio11.sql`)*

### 14. Which products have the highest return rates?
**Insight:** Grocery products dominate the highest return rates — P0027 Snacks (0.51%), P0023 Canned (0.40%), and P0028/P0026 (0.36% each) top the list.
*(Query in `portfolio11.sql`)*

### Bonus: Best Value Supplier Scoring Model
Not one of the original 14 questions — built independently to turn supplier data into an actionable scorecard: a weighted 0–100 score (cost 30%, return-quality 30%, delivery speed 40%) using window-function min-max normalization, ranking all 16 suppliers into Excellent/Good/Average/Poor tiers.
*(Query in `portfolio11.sql`)*

---

## Techniques Used

`CTEs` `Window functions (RANK, LAG, PERCENT_RANK, ROW_NUMBER)` `CASE-based bucketing` `NULLIF divide-by-zero handling` `Manual Pearson correlation in raw SQL` `CROSS JOIN scalar broadcasting` `Min-max normalized weighted scoring` `Tableau LOD expressions` `Calculated fields` `Dashboard design`

## Data

54,827 transactions · Jan 2023–Sep 2025 · fields: Product_ID, Category, Subcategory, Supplier_ID, Price, Cost, Discount, Units_Sold, Promotion_Type, Stock_Level, Reorder_Point, Lead_Time_Days, Backorder_Flag, Stockout_Alert, Is_Holiday, Weather_Index, Return_Units.

