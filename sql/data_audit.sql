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

SELECT * FROM portfolio_cleaned;    -- 10 records , 9 attributes

SELECT DISTINCT id FROM portfolio_cleaned;    -- 10

SELECT DISTINCT offer_type FROM portfolio_cleaned;      -- bogo, discount, informational

SELECT DISTINCT reward FROM portfolio_cleaned;      -- 0, 2, 3, 5, 7

SELECT DISTINCT difficulty FROM portfolio_cleaned;      -- 0, 5, 7, 10, 20

SELECT DISTINCT duration FROM portfolio_cleaned;      -- 3, 4, 5, 7, 10

SELECT 
FORMAT(MIN(reward), 'C0', 'HI') min_reward,
FORMAT(MAX(reward), 'C0', 'HI') max_reward,
FORMAT(MIN(difficulty), 'C0', 'HI') min_difficulty,
FORMAT(MAX(difficulty), 'C0', 'HI') max_difficulty,
MIN(duration) min_duration,
MAX(duration) maximum_duration
FROM Starbucks.dbo.portfolio_cleaned;




-- PROFILE TABLE


SELECT * FROM [profile];

SELECT COUNT(DISTINCT id) FROM [profile];
SELECT COUNT(DISTINCT id) FROM [profile] WHERE gender IS NULL;  -- 2175
SELECT COUNT(DISTINCT id) FROM [profile] WHERE income IS NULL;  -- 2175
SELECT DISTINCT gender FROM [profile];

SELECT gender, COUNT(*) gender_count
FROM profile
GROUP BY gender
ORDER BY gender_count DESC;             -- M, F, O & NULL

-- Changing the datatype of became_member_on column from int to date
ALTER TABLE profile
ALTER column became_member_on DATE;

SELECT 
SUM(CASE WHEN gender IS NULL THEN 1 END) missing_gender,
SUM(CASE WHEN age IS NULL THEN 1 END) missing_age,
SUM(CASE WHEN id IS NULL THEN 1 END) missing_id,
SUM(CASE WHEN became_member_on IS NULL THEN 1 END) missing_date,
SUM(CASE WHEN income IS NULL THEN 1 END) missing_income,
MIN(age) min_age,
MAX(age) max_age,
FORMAT(MIN(income), 'C0', 'HI') min_income,
FORMAT(MAX(income), 'C0', 'HI') max_income,
MIN(became_member_on) min_joining_date,
MAX(became_member_on) max_joining_date
FROM Starbucks.dbo.profile;


-- Dividing the salary in 10,000 groups e.g. salary = 33,000 will be come in 30,000 group
SELECT 
FORMAT(FLOOR(income/10000) * 10000, 'C0', 'HI') salary_range, 
COUNT(*) frequency
FROM profile
GROUP BY FLOOR(income/10000) * 10000
ORDER BY frequency DESC;




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

SELECT * FROM transcript_cleaned;   -- 306,534 records

SELECT DISTINCT person, event, offer_id, [time]  FROM transcript_cleaned;   -- 306,137 records; 397 duplicate records

SELECT DISTINCT event
FROM transcript_cleaned;    -- offer received, offer viewed, transaction ,& offer completed

SELECT DISTINCT person
FROM transcript_cleaned;    -- 17,000

SELECT DISTINCT offer_id
FROM transcript_cleaned;    -- 10 and 1 is null

-- Changing the datatype of reward column from nvarchar to float
ALTER TABLE transcript_cleaned 
ALTER COLUMN reward FLOAT;

-- Changing the datatype of amount column from nvarchar to float
ALTER TABLE transcript_cleaned 
ALTER COLUMN amount FLOAT;

SELECT 
SUM(CASE WHEN person IS NULL THEN 1 END) missing_person,
SUM(CASE WHEN [event] IS NULL THEN 1 END) missing_event,
SUM(CASE WHEN offer_id IS NULL THEN 1 END) missing_offer_id,
SUM(CASE WHEN [time] IS NULL THEN 1 END) missing_time,
SUM(CASE WHEN amount IS NULL THEN 1 END) missing_amount,
SUM(CASE WHEN reward IS NULL THEN 1 END) missing_reward,
MIN([time]) min_time,
MAX([time]) max_time,
FORMAT(MIN(amount), 'C2', 'HI') min_amount,
FORMAT(MAX(amount), 'C2', 'HI') max_amount,
FORMAT(MIN(reward), 'C2', 'HI') min_reward,
FORMAT(MAX(reward), 'C2', 'HI') max_reward
FROM Starbucks.dbo.transcript_cleaned;

SELECT * 
FROM transcript_cleaned
WHERE event IN ('offer received', 'offer viewed');  -- Here offer_id is present

SELECT * 
FROM transcript_cleaned
WHERE event = 'transaction';    -- Here transaction amount is present

SELECT * 
FROM transcript_cleaned
WHERE event = 'offer completed';  -- Here reward & offer_id is present

SELECT reward, count(*)
from transcript_cleaned
group by reward;

-- Checking the table schema
SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'transcript_cleaned';

EXEC sp_help 'transcript_cleaned';

-- Creating different view for each event
/*
  CREATE VIEW offer_received AS 
  SELECT person, offer_id, event, [time]
  FROM transcript_cleaned WHERE event = 'offer received';

  CREATE VIEW offer_viewed AS 
  SELECT person, offer_id, event, [time]
  FROM transcript_cleaned WHERE event = 'offer viewed';

  CREATE VIEW transaction_done AS 
  SELECT person, event, amount, [time]
  FROM transcript_cleaned WHERE event = 'transaction';

  CREATE VIEW offer_completed AS 
  SELECT person, offer_id, event, reward, [time]
  FROM transcript_cleaned WHERE event = 'offer completed';
*/

SELECT * FROM offer_received;
SELECT * FROM offer_viewed;
SELECT * FROM transaction_done;
SELECT * FROM offer_completed;
