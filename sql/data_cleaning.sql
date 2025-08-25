-- PROFILE TABLE 

-- Creating new table for cleaning purpose
SELECT * INTO profile_cleaned
FROM [profile];

-- Changing the datatype of became_member_on column from int to date
ALTER TABLE profile_cleaned
ALTER column became_member_on DATE;

-- Handling Outlier in age column (i.e. age =118)
SELECT * 
FROM profile_cleaned 
WHERE age IS NULL;          -- 0 records

SELECT * 
FROM profile_cleaned 
WHERE age < 18;         -- 0 records

SELECT * 
FROM profile_cleaned 
WHERE age = 118;         -- 2175 records; These are same having gender and income as null

-- Ignoring age = 118 because it is an invalid entry
-- Mean Age
SELECT AVG(age) avg_age
FROM profile_cleaned
WHERE age != 118;       -- Mean age is 54 

-- Mode Age
SELECT TOP 1
    age, COUNT(*) cnt
FROM profile_cleaned
WHERE age != 118
GROUP BY age
ORDER BY cnt DESC;      -- Mode age is 58 

-- Median Age
SELECT TOP 1
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY age) OVER() median_age
FROM profile_cleaned
WHERE age != 118;          -- Median age is 55

SELECT age, COUNT(*) cnt
FROM profile_cleaned
WHERE age != 118
GROUP BY age
ORDER BY age DESC; 

-- Imputing the age with mean value as mean and median very close to each other (differ by 1 year only)
UPDATE profile_cleaned 
SET age = (SELECT AVG(age) FROM profile_cleaned WHERE age != 118) 
WHERE age = 118;


-- Handling the missing gender

-- Checking all records where gender is missing
SELECT * 
FROM profile_cleaned
WHERE gender IS NULL;   -- 2,175 records

-- Gender distribution
SELECT 
    gender, 
    COUNT(*) cnt,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM profile_cleaned WHERE gender IS NOT NULL), 2) percent_contri,
    ROUND(1.0 * COUNT(*)/ SUM(COUNT(*)) OVER(), 2) percent_contri_window
FROM profile_cleaned 
WHERE gender IS NOT NULL
GROUP BY gender
ORDER BY cnt DESC;          -- M= 0.57, F= 0.41, & O= 0.01 percent

-- Imputing gender according to the gender distribution present in the original data
UPDATE profile_cleaned
SET gender = CASE 
                WHEN rnd <= 0.41 THEN 'F'
                WHEN rnd <= 0.98 THEN 'M'
                ELSE 'O'
            END 
FROM (
    SELECT *,
        CAST(CAST(ABS(CHECKSUM(NEWID())) % 10000 AS float) / 10000 AS float) rnd
    FROM profile_cleaned
    WHERE gender IS NULL
) AS t 
WHERE profile_cleaned.id = t.id;
/*
Explanation
	•	COUNT(*) → counts number of rows for each gender.
	•	SUM(COUNT(*)) OVER() → total number of rows (all genders).
	•	Multiply by 100.0 → percentage.
	•	ROUND(...,2) → keeps 2 decimal places.
*/


-- Handling the missing income 
SELECT * 
FROM profile_cleaned
WHERE income IS NULL;       -- 2,175

-- Mean of Income
SELECT AVG(income) avg_income
FROM profile_cleaned;       -- 65,404

-- Median of Income 
SELECT TOP 1
    PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY income) OVER() median_income
FROM profile_cleaned;       -- 64,000

-- Mode of Income
SELECT TOP 1
    income, COUNT(*) cnt
FROM profile_cleaned
WHERE income IS NOT NULL
GROUP BY income
ORDER BY cnt DESC;          -- 63,000

-- Imputing missing income by median income of the age group and gender
WITH base AS (
    SELECT 
        id,
        gender,
        CASE 
            WHEN age < 30 THEN 'Under 30'
            WHEN age BETWEEN 30 AND 45 THEN '30-45'
            WHEN age BETWEEN 46 AND 60 THEN '46-60'
            WHEN age BETWEEN 61 AND 75 THEN '61-75'
            ELSE '76+'
        END AS age_group,
        income
    FROM profile_cleaned
)
, median_income AS (
    SELECT DISTINCT
        gender,
        age_group,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY income) 
            OVER (PARTITION BY gender, age_group) AS median_income
    FROM base
    WHERE income IS NOT NULL
)
UPDATE c
SET c.income = m.median_income
FROM base c
JOIN median_income m
  ON c.gender = m.gender
 AND c.age_group = m.age_group
WHERE c.income IS NULL;

SELECT * FROM profile_cleaned;



-- PORTFOLIO TABLE 


-- Converting the array of channels to one-hot encoding
WITH C AS (
SELECT
  id, offer_type, reward, difficulty, duration,  
  CASE WHEN channels LIKE '%email%' THEN 1 ELSE 0 END AS email,
  CASE WHEN channels LIKE '%mobile%' THEN 1 ELSE 0 END AS mobile,
  CASE WHEN channels LIKE '%social%' THEN 1 ELSE 0 END AS social,
  CASE WHEN channels LIKE '%web%' THEN 1 ELSE 0 END AS web
FROM portfolio)
SELECT * INTO portfolio_cleaned
FROM C;

SELECT * FROM portfolio_cleaned;




-- TRANSCRIPT TABLE


-- Converting the value(dict/json column) into seperate column for each key
WITH CTE AS (
    SELECT  
        person,
        event,
        time,
        JSON_VALUE(REPLACE(REPLACE(REPLACE(value, '''', '"'), '_', ''), ' ', ''), '$.offerid') AS offer_id,
        JSON_VALUE(REPLACE(value, '''', '"'), '$.amount') AS amount,
        JSON_VALUE(REPLACE(value, '''', '"'), '$.reward') AS reward
    FROM transcript
) 
SELECT * INTO transcript_cleaned
FROM CTE;

-- Changing the datatype of reward column from nvarchar to float
ALTER TABLE transcript_cleaned 
ALTER COLUMN reward FLOAT;

-- Changing the datatype of amount column from nvarchar to float
ALTER TABLE transcript_cleaned 
ALTER COLUMN amount FLOAT;

-- Checking for Duplicate Rows
SELECT DISTINCT person, offer_id, event, [time], amount, reward
FROM transcript_cleaned;

-- Deleting Duplicate Rows
WITH CTE AS (
  SELECT *, 
  ROW_NUMBER() OVER(PARTITION BY person, offer_id, event, [time], amount, reward ORDER BY (SELECT NULL)) rn 
  FROM transcript_cleaned
) 
DELETE FROM CTE 
WHERE rn > 1;


-- Deleting offer received records where same offer is received before expiration or before the completion of first one
-- Step 1: Mark the next receipt of the same offer
WITH receipt_pairs AS (
    SELECT
        r1.person,
        r1.offer_id,
        r1.time AS first_received,
        p.duration,
        COALESCE(MIN(c.time), ((p.duration*24) + r1.time)) AS valid_until,
        LEAD(r1.time) OVER (
            PARTITION BY r1.person, r1.offer_id
            ORDER BY r1.time
        ) AS next_received
    FROM offer_received r1
    JOIN portfolio_cleaned p
        ON r1.offer_id = p.id
    LEFT JOIN offer_completed c
        ON r1.person = c.person
       AND r1.offer_id = c.offer_id
       AND c.time >= r1.time
       AND c.time <= (p.duration*24) + r1.time  -- must be within expiry
    GROUP BY r1.person, r1.offer_id, r1.time, p.duration
)
-- Step 2: Identify bad first receipts
, bad_receipts AS (
    SELECT
        person,
        offer_id,
        first_received
    FROM receipt_pairs
    WHERE next_received IS NOT NULL
      AND next_received < valid_until
)
-- Step 3: Delete the bad first receipts
DELETE r
FROM offer_received r
JOIN bad_receipts b
  ON r.person = b.person
 AND r.offer_id = b.offer_id
 AND r.time = b.first_received;                 -- 1,889 records deleted

-- Deleting records where offer is completed without min spend 
WITH Portfolio AS (
    SELECT id AS offer_id, difficulty, duration
    FROM portfolio_cleaned
),
Received AS (
    SELECT
        r.person,
        r.offer_id,
        r.time AS received_time,
        (p.duration * 24) + r.time AS expiry_time,
        p.difficulty
    FROM offer_received r
    JOIN Portfolio p ON r.offer_id = p.offer_id
),
CompletedMatched AS (
    SELECT
        c.person,
        c.offer_id,
        c.time AS completed_time,
        r.received_time,
        r.expiry_time,
        r.difficulty,
        ROW_NUMBER() OVER (
            PARTITION BY c.person, c.offer_id, c.time
            ORDER BY r.received_time DESC
        ) AS rn
    FROM offer_completed c
    JOIN Received r
      ON c.person = r.person
     AND c.offer_id = r.offer_id
     AND c.time BETWEEN r.received_time AND r.expiry_time
),
SpendAgg AS (
    SELECT
        cm.person,
        cm.offer_id,
        cm.completed_time,
        cm.received_time,
        cm.expiry_time,
        cm.difficulty,
        SUM(t.amount) AS total_spend
    FROM CompletedMatched cm
    LEFT JOIN transaction_done t
      ON t.person = cm.person
     AND t.time BETWEEN cm.received_time AND cm.expiry_time
    WHERE cm.rn = 1   -- keep only the most recent valid receipt
    GROUP BY
        cm.person, cm.offer_id, cm.completed_time,
        cm.received_time, cm.expiry_time, cm.difficulty
)
DELETE oc
FROM offer_completed oc
JOIN SpendAgg s
  ON oc.person   = s.person
 AND oc.offer_id = s.offer_id
 AND oc.time     = s.completed_time
WHERE s.total_spend < s.difficulty
  AND s.completed_time <= s.expiry_time;



WITH received_completed AS (
    SELECT
        r.person,
        r.offer_id,
        r.[time] AS received_time,
        c.[time] AS completed_time,
        c.reward,
        ROW_NUMBER() OVER (
            PARTITION BY r.person, r.offer_id, c.[time]
            ORDER BY r.[time] DESC
        ) AS rn
    FROM offer_received r
    JOIN offer_completed c
        ON r.person = c.person
       AND r.offer_id = c.offer_id
       AND r.[time] <= c.[time]
),
matched_offers AS (
    -- Keep only the *latest* receipt before each completion
    SELECT
        person,
        offer_id,
        received_time,
        completed_time,
        reward
    FROM received_completed
    WHERE rn = 1
),
trans_sum AS (
    SELECT 
        m.person,
        m.offer_id,
        m.received_time,
        m.completed_time,
        p.difficulty,
        ROUND(SUM(t.amount), 0) AS total_spent
    FROM matched_offers m
    JOIN portfolio_cleaned p 
        ON m.offer_id = p.id
    LEFT JOIN transaction_done t 
        ON m.person = t.person 
       AND t.[time] BETWEEN m.received_time AND m.completed_time
    GROUP BY m.person, m.offer_id, m.received_time, m.completed_time, p.difficulty
), record_to_delete AS (
    SELECT *
    FROM trans_sum
    WHERE total_spent < difficulty
)
DELETE oc
FROM offer_completed oc 
JOIN record_to_delete rd
    ON oc.person = rd.person
    AND oc.offer_id = rd.offer_id 
    AND oc.[time] = rd.completed_time;


WITH matched_offers AS (
    SELECT 
        c.person,
        c.offer_id,
        c.time AS completed_time,
        c.reward,
        r.time AS received_time,
        p.difficulty
    FROM offer_completed c
    CROSS APPLY (
        SELECT TOP 1 r.time
        FROM offer_received r
        WHERE r.person = c.person
          AND r.offer_id = c.offer_id
          AND r.time <= c.time
        ORDER BY r.time DESC
    ) r
    JOIN portfolio_cleaned p
      ON c.offer_id = p.id
),
trans_sum AS (
    SELECT 
        m.person,
        m.offer_id,
        m.received_time,
        m.completed_time,
        m.difficulty,
        COALESCE(SUM(t.amount), 0) AS total_spent
    FROM matched_offers m
    LEFT JOIN transaction_done t
      ON t.person = m.person
     AND t.time BETWEEN m.received_time AND m.completed_time
    GROUP BY m.person, m.offer_id, m.received_time, m.completed_time, m.difficulty
)
DELETE oc
FROM offer_completed oc
JOIN trans_sum ts
  ON oc.person = ts.person
 AND oc.offer_id = ts.offer_id
 AND oc.time = ts.completed_time
WHERE ts.total_spent < ts.difficulty;
  




SELECT * FROM transcript_cleaned;