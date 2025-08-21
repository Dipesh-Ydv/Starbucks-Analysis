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

-- Checking of any outlier income
SELECT income, COUNT(*) cnt
FROM profile_cleaned
GROUP BY income
ORDER BY income DESC;       -- There is no such outliers in income

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

SELECT * FROM transcript_cleaned;
