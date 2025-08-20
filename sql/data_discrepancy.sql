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
  AND completed_time > expiry_time;

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
WITH MatchedOffers AS (
    SELECT 
        c.person,
        c.offer_id,
        MAX(r.[time]) AS received_time,   -- latest receive before completion
        c.[time] AS completed_time
    FROM offer_completed c
    JOIN offer_received r
      ON r.person = c.person
     AND r.offer_id = c.offer_id
     AND r.[time] <= c.[time]
    GROUP BY c.person, c.offer_id, c.[time]
),
TxnSum AS (
    SELECT 
        m.person,
        m.offer_id,
        m.received_time,
        m.completed_time,
        p.difficulty,
        COALESCE(SUM(t.amount), 0) AS total_spent
    FROM MatchedOffers m
    JOIN portfolio_cleaned p
       ON m.offer_id = p.id
    LEFT JOIN transaction_done t
      ON t.person = m.person
      AND t.time BETWEEN m.received_time AND m.completed_time
    GROUP BY m.person, m.offer_id, m.received_time, m.completed_time, p.difficulty
)
SELECT *
FROM TxnSum
WHERE total_spent < difficulty;


SELECT TOP 5 * FROM [profile];
SELECT TOP 5 * FROM portfolio_cleaned;
SELECT TOP 5 * FROM transcript_cleaned;
SELECT TOP 5 * FROM offer_received;
SELECT TOP 5 * FROM offer_viewed;
SELECT TOP 5 * FROM transaction_done;
SELECT TOP 5 * FROM offer_completed;
