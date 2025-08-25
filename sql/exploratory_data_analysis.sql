-- # UNIVARIATE ANALYSIS


-- PROFILE TABLE 


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

-- Mean Age
SELECT AVG(age) avg_age
FROM profile_cleaned;       -- Mean age is 54 

-- Mode Age
SELECT TOP 1
    age, COUNT(*) cnt
FROM profile_cleaned p 
GROUP BY age
ORDER BY cnt DESC;      -- Mode age is 54

-- Median Age
SELECT TOP 1
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY age) OVER() median_age
FROM profile_cleaned;          -- Median age is 54

-- Customer Distribution by age Group
WITH age_cat AS (
    SELECT 
        id,
        gender,
        CASE 
            WHEN age < 30 THEN 'Under 30'
            WHEN age BETWEEN 30 AND 45 THEN '30-45'
            WHEN age BETWEEN 46 AND 60 THEN '46-60'
            WHEN age BETWEEN 61 AND 75 THEN '61-75'
            ELSE '76+'
        END AS age_group
    FROM profile_cleaned
)
SELECT 
    age_group,
    COUNT(*) cust_cnt
FROM age_cat
GROUP BY age_group
ORDER BY cust_cnt;

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

-- Mean of Income
SELECT AVG(income) avg_income
FROM profile_cleaned;       -- 65,744.5

-- Median of Income 
SELECT TOP 1
    PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY income) OVER() median_income
FROM profile_cleaned;       -- 63,000

-- Mode of Income
SELECT TOP 1
    income, COUNT(*) cnt
FROM profile_cleaned
WHERE income IS NOT NULL
GROUP BY income
ORDER BY cnt DESC;          -- 63,000

-- Customer Distribution by Income Group
WITH income_cat AS (
    SELECT 
    income,
    CASE 
        WHEN income < 51000 THEN 'Low Income'                   -- Below Q1
        WHEN income >= 51000 AND income < 63000 THEN 'Lower-Middle Income'  -- Q1 to Median
        WHEN income >= 63000 AND income < 76000 THEN 'Upper-Middle Income'  -- Median to Q3
        WHEN income >= 76000 THEN 'High Income'                 -- Above Q3
    END AS income_groups
    FROM profile_cleaned 
)
SELECT 
    income_groups,
    COUNT(*) cust_cnt
FROM income_cat
GROUP BY income_groups
ORDER BY cust_cnt;

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


SELECT * FROM profile_cleaned;




-- PORTFOLIO TABLE


-- 1. Total Offers
SELECT COUNT(DISTINCT id) total_offers
FROM portfolio_cleaned; -- 10

-- 2. Number of distinct offer send through each channel
SELECT 
    1.0* SUM(web)/ (SELECT COUNT(DISTINCT id) FROM portfolio_cleaned) web_as_offer_channel,
    1.0* SUM(email)/ (SELECT COUNT(DISTINCT id) FROM portfolio_cleaned) email_as_offer_channel,
    1.0* SUM(mobile)/(SELECT COUNT(DISTINCT id) FROM portfolio_cleaned) mobile_as_offer_channel,
    1.0* SUM(social)/(SELECT COUNT(DISTINCT id) FROM portfolio_cleaned) social_as_offer_channel
FROM portfolio_cleaned;

-- 3. Number of offers for each offer type
SELECT offer_type, 1.0 * COUNT(*) / (SELECT COUNT(DISTINCT id) FROM portfolio_cleaned) offer_distribution
FROM portfolio_cleaned
GROUP BY offer_type
ORDER BY offer_distribution DESC;      

-- 4. Number of offer for each reward
SELECT 
    reward,
    COUNT(*) offer_cnt
FROM portfolio_cleaned
GROUP BY reward
ORDER BY offer_cnt DESC;  

-- 5. Number of offer for each difficulty
SELECT 
    difficulty,
    COUNT(*) offer_cnt
FROM portfolio_cleaned
GROUP BY difficulty
ORDER BY offer_cnt DESC;  

-- 6. Number of offer for each duration
SELECT 
    duration,
    COUNT(*) offer_cnt
FROM portfolio_cleaned
GROUP BY duration
ORDER BY offer_cnt DESC;  


SELECT * FROM portfolio_cleaned;




-- TRANSCRIPT TABLE


-- 1. Number of records with each event (Event Distribution)
SELECT 
    [event],
    FORMAT(COUNT(*), 'N0') cnt
FROM transcript_cleaned
GROUP BY [event]
ORDER BY cnt DESC;

-- 2. Number of transaction done by each customer/person
SELECT 
    person,
    COUNT(*) cnt
FROM transaction_done
GROUP BY person
ORDER BY cnt DESC;          -- Number of Customer done transaction = 16,578

-- 3. Transaction Amount Distribution
SELECT 
    DISTINCT
    PERCENTILE_CONT(0.0) WITHIN GROUP (ORDER BY amount) OVER() AS min_amount,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY amount) OVER() AS q1,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY amount) OVER() AS median_amount,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY amount) OVER() AS q3,
    PERCENTILE_CONT(1.0) WITHIN GROUP (ORDER BY amount) OVER() AS max_amount
FROM transaction_done;

-- Checking for outliers
WITH box_stats AS (
    SELECT
        DISTINCT 
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY amount) OVER() q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY amount) OVER() q3
    FROM transaction_done
), outlier_cal AS (
    SELECT 
        t.amount,
        CASE 
            WHEN t.amount < (b.q1 - 1.5 * (b.q3 - b.q1)) THEN 'Low Outlier'
            WHEN t.amount > (b.q3 + 1.5 * (b.q3 - b.q1)) THEN 'High Outlier'
            ELSE 'Normal'
        END AS outlier_category
    FROM transaction_done t
    CROSS JOIN box_stats b
) 
SELECT *
FROM outlier_cal
WHERE outlier_category IN ('High Outlier', 'Low Outlier');          -- 1,236 records in High Outlier category

-- 4. Number of records of each offer_id sent 
SELECT 
    offer_id,
    COUNT(*) cnt
FROM offer_received
GROUP BY offer_id
ORDER BY cnt DESC;

-- 5. Number of records of each offer_id viewed
SELECT 
    offer_id,
    COUNT(*) cnt
FROM offer_viewed
GROUP BY offer_id
ORDER BY cnt DESC;

-- 6. Number of records of each offer_id completed
SELECT 
    offer_id,
    COUNT(*) cnt
FROM offer_completed
GROUP BY offer_id
ORDER BY cnt DESC;          -- 8 offers has completed records because 2 are informational offers 

-- Combined offer_id count per event
SELECT 
    offer_id,
    SUM(CASE WHEN event = 'offer received' THEN 1 ELSE 0 END) offer_received,
    SUM(CASE WHEN event = 'offer viewed' THEN 1 ELSE 0 END) offer_viewed,
    SUM(CASE WHEN event = 'offer completed' THEN 1 ELSE 0 END) offer_completed
FROM transcript_cleaned
WHERE offer_id IS NOT NULL
GROUP BY offer_id; 


SELECT * FROM transcript_cleaned;




-- # BIVARIATE ANALYSIS


-- 1. Offer completion by Gender
SELECT 
    p.gender,
    1.0 * SUM(CASE WHEN t.event = 'offer viewed' THEN 1 ELSE 0 END) / SUM(CASE WHEN t.event = 'offer received' THEN 1 ELSE 0 END) view_rate,
    1.0 * SUM(CASE WHEN t.event = 'offer completed' THEN 1 ELSE 0 END)/ SUM(CASE WHEN t.event = 'offer received' THEN 1 ELSE 0 END) completion_rate
FROM transcript_cleaned t 
JOIN profile_cleaned p ON t.person = p.id
JOIN portfolio_cleaned o ON t.offer_id = o.id
WHERE o.offer_type != 'informational'
GROUP BY p.gender;

-- 2. Offer completion by Age group
WITH age_cat AS (
    SELECT 
        id,
        gender,
        CASE 
            WHEN age < 30 THEN 'Under 30'
            WHEN age BETWEEN 30 AND 45 THEN '30-45'
            WHEN age BETWEEN 46 AND 60 THEN '46-60'
            WHEN age BETWEEN 61 AND 75 THEN '61-75'
            ELSE '76+'
        END AS age_group
    FROM profile_cleaned
) 
SELECT 
    a.age_group,
    1.0 * SUM(CASE WHEN t.event = 'offer viewed' THEN 1 ELSE 0 END) / SUM(CASE WHEN t.event = 'offer received' THEN 1 ELSE 0 END) view_rate,
    1.0 * SUM(CASE WHEN t.event = 'offer completed' THEN 1 ELSE 0 END)/ SUM(CASE WHEN t.event = 'offer received' THEN 1 ELSE 0 END) completion_rate
FROM transcript_cleaned t 
JOIN age_cat a ON t.person = a.id
JOIN portfolio_cleaned o ON t.offer_id = o.id
WHERE o.offer_type != 'informational'
GROUP BY a.age_group;

-- 3. Offer completion by Income group
WITH income_cat AS (
    SELECT 
    id,
    income,
    CASE 
        WHEN income < 51000 THEN 'Low Income'                   -- Below Q1
        WHEN income >= 51000 AND income < 63000 THEN 'Lower-Middle Income'  -- Q1 to Median
        WHEN income >= 63000 AND income < 76000 THEN 'Upper-Middle Income'  -- Median to Q3
        WHEN income >= 76000 THEN 'High Income'                 -- Above Q3
    END AS income_groups
    FROM profile_cleaned
)
SELECT 
    i.income_groups,
    1.0 * SUM(CASE WHEN t.event = 'offer viewed' THEN 1 ELSE 0 END) / SUM(CASE WHEN t.event = 'offer received' THEN 1 ELSE 0 END) view_rate,
    1.0 * SUM(CASE WHEN t.event = 'offer completed' THEN 1 ELSE 0 END)/ SUM(CASE WHEN t.event = 'offer received' THEN 1 ELSE 0 END) completion_rate
FROM transcript_cleaned t 
JOIN income_cat i ON t.person = i.id
JOIN portfolio_cleaned o ON t.offer_id = o.id
WHERE o.offer_type != 'informational'
GROUP BY i.income_groups;

-- 4. Duration Vs Completion Rate
SELECT 
    p.duration,
    1.0 * SUM(CASE WHEN t.event = 'offer viewed' THEN 1 ELSE 0 END) / SUM(CASE WHEN t.event = 'offer received' THEN 1 ELSE 0 END) view_rate,
    1.0 * SUM(CASE WHEN t.event = 'offer completed' THEN 1 ELSE 0 END)/ SUM(CASE WHEN t.event = 'offer received' THEN 1 ELSE 0 END) completion_rate
FROM transcript_cleaned t 
JOIN portfolio_cleaned p ON t.offer_id = p.id
-- WHERE P.offer_type != 'informational'       -- Because informaitonal offers can't be completed
GROUP BY p.duration;

-- 5. Difficulty Vs Completion Rate
SELECT 
    p.difficulty,
    1.0 * SUM(CASE WHEN t.event = 'offer viewed' THEN 1 ELSE 0 END) / SUM(CASE WHEN t.event = 'offer received' THEN 1 ELSE 0 END) view_rate,
    1.0 * SUM(CASE WHEN t.event = 'offer completed' THEN 1 ELSE 0 END)/ SUM(CASE WHEN t.event = 'offer received' THEN 1 ELSE 0 END) completion_rate
FROM transcript_cleaned t 
JOIN portfolio_cleaned p ON t.offer_id = p.id
WHERE P.offer_type != 'informational'           -- Because informaitonal offers can't be completed
GROUP BY p.difficulty;

-- 6. Reward Vs Completion Rate
SELECT 
    p.reward,
    1.0 * SUM(CASE WHEN t.event = 'offer viewed' THEN 1 ELSE 0 END) / SUM(CASE WHEN t.event = 'offer received' THEN 1 ELSE 0 END) view_rate,
    1.0 * SUM(CASE WHEN t.event = 'offer completed' THEN 1 ELSE 0 END)/ SUM(CASE WHEN t.event = 'offer received' THEN 1 ELSE 0 END) completion_rate
FROM transcript_cleaned t 
JOIN portfolio_cleaned p ON t.offer_id = p.id
WHERE P.offer_type != 'informational'           -- Because informaitonal offers can't be completed
GROUP BY p.reward;

-- 7. Offer type Vs Completion Rate
SELECT 
    p.offer_type,
    1.0 * SUM(CASE WHEN t.event = 'offer viewed' THEN 1 ELSE 0 END) / SUM(CASE WHEN t.event = 'offer received' THEN 1 ELSE 0 END) view_rate,
    1.0 * SUM(CASE WHEN t.event = 'offer completed' THEN 1 ELSE 0 END)/ SUM(CASE WHEN t.event = 'offer received' THEN 1 ELSE 0 END) completion_rate
FROM transcript_cleaned t 
JOIN portfolio_cleaned p ON t.offer_id = p.id
WHERE p.offer_type != 'informational'
GROUP BY p.offer_type;




-- # MULTIVARIATE ANALYSIS


/* 1. Age Vs Income Completion Rate */
WITH cte AS (
    SELECT 
        t.*,
        CASE 
            WHEN age < 30 THEN 'Under 30'
            WHEN age BETWEEN 30 AND 45 THEN '30-45'
            WHEN age BETWEEN 46 AND 60 THEN '46-60'
            WHEN age BETWEEN 61 AND 75 THEN '61-75'
            ELSE '76+'
        END AS age_group,
        CASE 
            WHEN income < 51000 THEN 'Low Income'                   -- Below Q1
            WHEN income >= 51000 AND income < 63000 THEN 'Lower-Middle Income'  -- Q1 to Median
            WHEN income >= 63000 AND income < 76000 THEN 'Upper-Middle Income'  -- Median to Q3
            WHEN income >= 76000 THEN 'High Income'                 -- Above Q3
        END AS income_group
    FROM profile_cleaned p 
    JOIN transcript_cleaned t ON p.id = t.person
    JOIN portfolio_cleaned o ON o.id = t.offer_id
    WHERE o.offer_type != 'informational'
)
SELECT 
    age_group,
    income_group,
    1.0 * SUM(CASE WHEN event = 'offer viewed' THEN 1 ELSE 0 END) / SUM(CASE WHEN event = 'offer received' THEN 1 ELSE 0 END) view_rate,
    1.0 * SUM(CASE WHEN event = 'offer completed' THEN 1 ELSE 0 END) / SUM(CASE WHEN event = 'offer received' THEN 1 ELSE 0 END) completion_rate
FROM cte
GROUP BY age_group, income_group;

-- 2. Gender Vs Offer Type Vs Completion Rate
SELECT 
    p.gender,
    o.offer_type,
    1.0 * SUM(CASE WHEN t.event = 'offer viewed' THEN 1 ELSE 0 END) / SUM(CASE WHEN t.event = 'offer received' THEN 1 ELSE 0 END) view_rate,
    1.0 * SUM(CASE WHEN t.event = 'offer completed' THEN 1 ELSE 0 END) / SUM(CASE WHEN t.event = 'offer received' THEN 1 ELSE 0 END) completion_rate
FROM transcript_cleaned t 
JOIN portfolio_cleaned o ON t.offer_id = o.id
JOIN profile_cleaned p ON t.person = p.id
WHERE o.offer_type != 'informational'
GROUP BY p.gender, o.offer_type;

-- Co-relation between age and income
SELECT 
    (COUNT(*) * SUM(CAST(age AS FLOAT) * CAST(income AS FLOAT)) 
        - SUM(CAST(age AS FLOAT)) * SUM(CAST(income AS FLOAT))) /
    (SQRT(COUNT(*) * SUM(POWER(CAST(age AS FLOAT), 2)) 
        - POWER(SUM(CAST(age AS FLOAT)), 2)) *
     SQRT(COUNT(*) * SUM(POWER(CAST(income AS FLOAT), 2)) 
        - POWER(SUM(CAST(income AS FLOAT)), 2))) 
     AS correlation
FROM profile_cleaned;

