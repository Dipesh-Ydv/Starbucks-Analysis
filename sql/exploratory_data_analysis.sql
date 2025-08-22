-- PROFILE TABLE 

-- UNIVARIATE ANALYSIS
-- 1. Age Distribution
SELECT 
    DISTINCT
    PERCENTILE_CONT(0.0) WITHIN GROUP (ORDER BY age) OVER() AS min_age,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY age) OVER() AS q1,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY age) OVER() AS median_age,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY age) OVER() AS q3,
    PERCENTILE_CONT(1.0) WITHIN GROUP (ORDER BY age) OVER() AS max_age
FROM profile_cleaned;

-- Checking for outliers
WITH box_stats AS (
    SELECT
        DISTINCT
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY age) OVER() q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY age) OVER() q3
    FROM profile_cleaned
), outlier_cal AS (
    SELECT 
        p.id,
        p.age,
        CASE 
            WHEN p.age < (b.q1 - 1.5 * (b.q3 - b.q1)) THEN 'Low Outlier'
            WHEN p.age > (b.q3 + 1.5 * (b.q3 - b.q1)) THEN 'High Outlier'
            ELSE 'Normal'
        END AS outlier_category
    FROM profile_cleaned p
    CROSS JOIN box_stats b
) 
SELECT *
FROM outlier_cal
WHERE outlier_category IN ('High Outlier', 'Low Outlier');              -- There 48 person with age in High Outlier Category 

-- 2. Income Distribution
SELECT 
    DISTINCT 
    PERCENTILE_CONT(0.0) WITHIN GROUP (ORDER BY income) OVER() AS min_income,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY income) OVER() AS q1,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY income) OVER() AS median_income,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY income) OVER() AS q3,
    PERCENTILE_CONT(1.0) WITHIN GROUP (ORDER BY income) OVER() AS max_income
FROM profile_cleaned;

-- Checking for outliers
WITH box_stats AS (
    SELECT
        DISTINCT 
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY income) OVER() q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY income) OVER() q3
    FROM profile_cleaned
), outlier_cal AS (
    SELECT 
        P.id,
        p.income,
        CASE 
            WHEN p.income < (b.q1 - 1.5 * (b.q3 - b.q1)) THEN 'Low Outlier'
            WHEN p.income > (b.q3 + 1.5 * (b.q3 - b.q1)) THEN 'High Outlier'
            ELSE 'Normal'
        END AS outlier_category
    FROM profile_cleaned p
    CROSS JOIN box_stats b
) 
SELECT *
FROM outlier_cal
WHERE outlier_category IN ('High Outlier', 'Low Outlier');             -- There 306 persons whose income is in High Outlier Category 

-- 3. Gender Distribution
SELECT 
    gender,
    COUNT(*) cnt,
    100.0 * COUNT(*) / SUM(COUNT(*)) OVER() perc_cntr
FROM profile_cleaned
GROUP BY gender;                            -- M= 57.27% , F= 41.19% ,& O= 1.54% 

-- 4. Customer acqusition trend (became_member_on variable)
-- Yearly Customer acquired
SELECT 
    YEAR(became_member_on) Year_, 
    COUNT(*) cust_cnt
FROM profile_cleaned
GROUP BY YEAR(became_member_on)
ORDER BY Year_;

-- Monthly Customer acquired
SELECT 
    YEAR(became_member_on) Year_,
    MONTH(became_member_on) Month_,
    COUNT(*) cust_cnt
FROM profile_cleaned
GROUP BY YEAR(became_member_on), MONTH(became_member_on)
ORDER BY Year_, Month_;

-- Monthly Customer acquired across year
SELECT 
    FORMAT(became_member_on, 'MMMM') Month_,
    COUNT(*) cust_cnt
FROM profile_cleaned
GROUP BY FORMAT(became_member_on, 'MMMM')
ORDER BY cust_cnt DESC;


-- MULTIVARIATE ANALYSIS


SELECT * FROM profile_cleaned;
SELECT * FROM portfolio_offers;

