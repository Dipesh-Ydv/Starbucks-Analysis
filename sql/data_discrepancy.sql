-- CHECKING DATA DISCREPANCIES 

-- 1. Offer_id of an event is not persent in portfolio table
SELECT *
FROM transcript_cleaned T 
LEFT JOIN portfolio_cleaned O on T.offer_id = O.id
WHERE T.event != 'transaction' AND O.id IS NULL;            -- 0 records found

-- 2. person of an event is not persent in profile table
SELECT *
FROM transcript_cleaned T 
LEFT JOIN [profile] P on T.person = P.id
WHERE P.id IS NULL;            -- 0 records found

-- 3. Offer is completed/ reward is given even it is a informational offer
SELECT *
FROM offer_completed C 
LEFT JOIN portfolio_cleaned O on C.offer_id = O.id
WHERE O.offer_type = 'informational';           -- 0 records found

-- 4. Different reward for the same offer in both tables
SELECT *
FROM offer_completed C 
LEFT JOIN portfolio_cleaned O on C.offer_id = O.id
WHERE C.reward != O.reward;           -- 0 records found

-- 5. Checking whether an offer is completed before/ without receving 
SELECT 
  C.offer_id,
  C.person
FROM offer_completed C
JOIN portfolio_cleaned P on C.offer_id = P.id
AND NOT EXISTS (
  SELECT *
  FROM offer_received R
  WHERE R.person = C.person
    AND R.offer_id = C.offer_id
    AND R.[time] <= C.[time]
    AND C.time_in_days <= (R.time_in_days + P.duration)
);     -- 0 records found

-- 6. Checking for offers which completed even after the duration is over
WITH ReceivedOffers AS (
    SELECT 
        t.person,
        t.offer_id,
        t.time AS received_time,
        (p.duration * 24) + t.time AS expiry_time
    FROM offer_received t
    JOIN portfolio_cleaned p 
        ON t.offer_id = p.id
),
Matched AS (
    SELECT 
        c.person,
        c.offer_id,
        c.[time] completed_time,
        r.received_time,
        r.expiry_time,
        ROW_NUMBER() OVER (
            PARTITION BY c.person, c.offer_id, c.time
            ORDER BY r.received_time DESC
        ) AS rn
    FROM offer_completed c
    LEFT JOIN ReceivedOffers r
        ON c.person = r.person
       AND c.offer_id = r.offer_id
       AND r.received_time <= c.[time]
)
SELECT 
    person,
    offer_id,
    completed_time,
    received_time,
    expiry_time
FROM Matched
WHERE rn = 1            -- pick the latest received before completion
  AND completed_time > expiry_time;           -- 0 records found


-- 7. Records where order is completed without viewing it (This shows no influence of offer on transaction)
SELECT c.person,
       c.offer_id,
       r.[time] received_time,
       c.time AS completed_time
FROM offer_completed c
JOIN offer_received r 
ON c.offer_id = r.offer_id
  AND c.person = r.person
  AND r.[time] <= c.[time]
WHERE NOT EXISTS (
        SELECT 1
        FROM offer_viewed v
        WHERE v.person = c.person
          AND v.offer_id = c.offer_id
          AND v.time <= c.time
);

WITH Matched AS (
    SELECT c.person, c.offer_id, c.[time] completed_time,
           v.[time] viewed_time,
           ROW_NUMBER() OVER (
              PARTITION BY c.person, c.offer_id, c.time ORDER BY v.time DESC
           ) AS rn
    FROM offer_completed c
    LEFT JOIN offer_viewed v
      ON v.person = c.person
     AND v.offer_id = c.offer_id
     AND v.[time] <= c.[time]
)
SELECT person, offer_id, completed_time
FROM Matched
WHERE rn IS NULL;  -- means no view exists before completion

-- 8. Offer completed without min amount spent 
WITH matched_offers AS (
  SELECT 
    r.person,
    r.offer_id,
    MAX(r.[time]) received_time,
    c.[time] completed_time,
    c.reward
  FROM offer_received r 
  JOIN offer_completed c
    ON r.person = c.person
    AND r.offer_id = c.offer_id
    AND r.[time] <= c.[time]
  GROUP BY r.person, r.offer_id, c.[time], c.reward
), trans_sum AS (
  SELECT 
    m.person,
    m.offer_id,
    m.received_time,
    m.completed_time,
    p.difficulty,
    ROUND(SUM(t.amount), 2) total_spent
  FROM matched_offers m
  JOIN portfolio_cleaned p 
    ON m.offer_id = p.id
  LEFT JOIN transaction_done t 
    ON m.person = t.person 
    AND t.[time] BETWEEN m.received_time AND m.completed_time
  GROUP BY m.person, m.offer_id, m.received_time, m.completed_time, p.difficulty
) 
SELECT * 
FROM trans_sum 
WHERE total_spent < difficulty;               -- 134 records found

-- Window Function approach for the same
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
)
SELECT *
FROM trans_sum
WHERE total_spent < difficulty;       -- 134 records; Both are returning same number of records; 128 records when rounding to zero decimal place

-- 9. Checking for same offer received to a person before its expiration or before been completed
WITH offer_info AS (
    SELECT 
        t.person,
        t.offer_id,
        t.time AS received_time,
        p.duration
    FROM offer_received t
    JOIN portfolio p 
      ON t.offer_id = p.id
),
completed AS (
    SELECT 
        person,
        offer_id,
        time AS completed_time
    FROM offer_completed
),
offer_with_expiry AS (
    SELECT 
      r.person,
      r.offer_id,
      r.received_time,
      r.received_time + (r.duration * 24) expiry_time,
      MIN(c.completed_time) completed_time
    FROM offer_info r 
    LEFT JOIN completed c 
      ON r.person = c.person 
      AND r.offer_id = c.offer_id
      AND r.received_time <= c.completed_time
    GROUP BY r.person, r.offer_id, r.received_time, r.duration
)
SELECT 
    r1.person,
    r1.offer_id,
    r1.received_time AS first_received,
    r2.received_time AS second_received,
    r1.expiry_time,
    r1.completed_time
FROM offer_with_expiry r1
JOIN offer_with_expiry r2
  ON r1.person = r2.person
 AND r1.offer_id = r2.offer_id
 AND r2.received_time > r1.received_time
WHERE 
    -- check if 2nd receipt happens before expiry AND before completion
    (r2.received_time < r1.expiry_time)
 AND (r1.completed_time IS NOT NULL AND r2.received_time < r1.completed_time);        -- 674 records found




SELECT TOP 5 * FROM [profile];
SELECT TOP 5 * FROM portfolio_cleaned;
SELECT TOP 5 * FROM transcript_cleaned;
SELECT TOP 5 * FROM offer_received;
SELECT TOP 5 * FROM offer_viewed;
SELECT TOP 5 * FROM transaction_done;
SELECT TOP 5 * FROM offer_completed;

-- Deleting Duplicate Rows
WITH CTE AS (
  SELECT *, 
  ROW_NUMBER() OVER(PARTITION BY person, offer_id, event, [time], amount, reward, time_in_days ORDER BY (SELECT NULL)) rn 
  FROM transcript_cleaned
) 
DELETE FROM CTE 
WHERE rn > 1;

SELECT * FROM transcript_cleaned;