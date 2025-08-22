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


SELECT * FROM profile_cleaned;



-- PORTFOLIO TABLE


-- UNIVARIATE ANALYSIS

-- 1. Total Offers
SELECT COUNT(DISTINCT id) total_offers
FROM portfolio_cleaned; -- 10

-- 2. Number of distinct offer send through each channel
SELECT 
    SUM(web) offers_as_channel_web,
    SUM(email) offers_as_channel_email,
    SUM(mobile) offers_as_channel_mobile,
    SUM(social) offers_as_channel_social
FROM portfolio_cleaned;

-- 3. Number of offers for each offer type
SELECT offer_type, COUNT(*) offer_cnt
FROM portfolio_cleaned
GROUP BY offer_type
ORDER BY offer_cnt DESC;      

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


-- UNIVARIATE ANALYSIS

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


SELECT * 
FROM transcript_cleaned;