-- 1. Average Duration of Offers
SELECT 
    AVG(duration*1.0) avg_duration
FROM portfolio_cleaned;                 -- 6.5

-- 2. Average Difficulty of Offers
SELECT 
    AVG(difficulty*1.0) avg_duration
FROM portfolio_cleaned;                 -- 7.7 

-- 3. Average Reward of Offers
SELECT 
    AVG(reward*1.0) avg_duration
FROM portfolio_cleaned;                 -- 4.2

-- 4. Average Transaction Value of Each Customer
SELECT 
    SUM(amount)/ COUNT(DISTINCT person) avg_order_value 
FROM transaction_done;          -- 107.10

-- 5. Average Number of Transactions per Customer
SELECT 
    1.0 * COUNT(*)/ COUNT(DISTINCT person) avg_trans_per_cust
FROM transaction_done;          -- 8.38

-- 6. Repeat Transaction Rate (% of persons making multiple transactions)
WITH repeat_cust AS (
    SELECT 
        person,
        COUNT(*) trans_cnt
    FROM transaction_done
    GROUP BY person
    HAVING COUNT(*) > 1
)
SELECT
    1.0 * (SELECT COUNT(*) FROM repeat_cust) / COUNT(DISTINCT person) repeat_cust_rate
FROM transaction_done;          -- 97.58 %

-- 7. Inactive Customers (i.e. receiving offers but not responsing)
SELECT 
    DISTINCT r.person
FROM offer_received r
LEFT JOIN offer_completed c 
    ON r.person = c.person
WHERE c.person IS NULL;             -- 4,220

-- 8. Customers never viewed offer
SELECT 
    DISTINCT r.person
FROM offer_received r
LEFT JOIN offer_viewed v
    ON r.person = v.person
WHERE v.person IS NULL;             -- 160 persons

-- 9. Total Customers Done Transactions 
SELECT COUNT(DISTINCT person) FROM transaction_done;            -- 16,578

-- 10. Offer View Rate
SELECT 
    1.0 * SUM(CASE WHEN event = 'offer viewed' THEN 1 ELSE 0 END) / SUM(CASE WHEN event = 'offer received' THEN 1 ELSE 0 END) view_rate,
    1.0 * SUM(CASE WHEN event = 'offer completed' THEN 1 ELSE 0 END) / SUM(CASE WHEN event = 'offer received' THEN 1 ELSE 0 END) completion_rate
FROM transcript_cleaned;        -- view = 77.6 %    & complete = 44.6%

-- 11. Average Time for Offer completion
WITH matched_offers AS (
    SELECT 
        r.person,
        r.offer_id,
        r.[time] received_time,
        c.[time] completed_time,
        ROW_NUMBER() OVER (
            PARTITION BY r.person, r.offer_id, c.time
            ORDER BY r.time DESC
        ) AS rn
    FROM offer_received r 
    JOIN offer_completed c 
        ON r.person = c.person
        AND r.offer_id = c.offer_id
        AND c.[time] >= r.[time]
), response AS (
    SELECT 
        person,
        offer_id,
        received_time,
        completed_time
    FROM matched_offers
    WHERE rn = 1
)
SELECT 
    AVG(1.0 * completed_time - received_time) average_response_time
FROM response;              -- 61.27 hrs

-- 12. Average Time to View Offer
WITH matched_offers AS (
    SELECT 
        r.person,
        r.offer_id,
        r.[time] received_time,
        v.[time] viewed_time,
        ROW_NUMBER() OVER (
            PARTITION BY r.person, r.offer_id, v.time
            ORDER BY r.time DESC
        ) AS rn
    FROM offer_received r 
    JOIN offer_viewed v 
        ON r.person = v.person
        AND r.offer_id = v.offer_id
        AND v.[time] >= r.[time]
), viewed AS (
    SELECT 
        person,
        offer_id,
        received_time,
        viewed_time
    FROM matched_offers
    WHERE rn = 1
)
SELECT 
    AVG(1.0 * viewed_time - received_time) average_time_to_view_offer
FROM viewed;              -- 27.65 hrs

-- 13. Offer expired percentage
WITH offer_window AS (
    SELECT 
        r.person,
        r.offer_id,
        r.[time] received_time,
        r.[time] + (p.duration*24) expiry_time
    FROM offer_received r 
    JOIN portfolio_cleaned p 
        ON r.offer_id = p.id
), offer_status AS (
    SELECT 
        w.person,
        w.offer_id,
        w.received_time,
        w.expiry_time,
        MIN(c.[time]) completed_time
    FROM offer_window w
    LEFT JOIN offer_completed c 
        ON w.person = c.person
        AND w.offer_id = c.offer_id
        AND c.[time] BETWEEN w.received_time AND w.expiry_time
    GROUP BY w.person, w.offer_id, w.received_time, w.expiry_time
) 
SELECT 
    COUNT(CASE WHEN completed_time IS NULL THEN 1 END) * 1.0 / COUNT(*) expired_pct,
    COUNT(CASE WHEN completed_time IS NOT NULL THEN 1 END) * 1.0 / COUNT(*) completed_pct
FROM offer_status;

-- Another easy approach for the same 
SELECT 
    1 - (1.0 * COUNT(*)/ (SELECT COUNT(*) FROM offer_received)) expired_pct,
    1.0 * COUNT(*)/ (SELECT COUNT(*) FROM offer_received) completed_pct
FROM offer_completed;

-- 14. Income group Vs Avg Transaction Spend
WITH income_cat AS (
    SELECT 
    id,
    CASE 
        WHEN income < 51000 THEN 'Low Income'                   -- Below Q1
        WHEN income >= 51000 AND income < 63000 THEN 'Lower-Middle Income'  -- Q1 to Median
        WHEN income >= 63000 AND income < 76000 THEN 'Upper-Middle Income'  -- Median to Q3
        WHEN income >= 76000 THEN 'High Income'                 -- Above Q3
    END AS income_group
    FROM profile_cleaned
)
SELECT 
    i.income_group,
    SUM(t.amount)/COUNT(DISTINCT t.person) average_spend
FROM transaction_done t 
JOIN income_cat i ON t.person = i.id
GROUP BY i.income_group
ORDER BY average_spend;

-- 15. Age group Vs Avg Transaction Spend
WITH age_cat AS (
    SELECT 
        id,
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
    SUM(t.amount)/COUNT(DISTINCT t.person) average_spend
FROM transaction_done t 
JOIN age_cat a ON t.person = a.id
GROUP BY a.age_group
ORDER BY average_spend;

-- 16. Gender Vs Average Spend
SELECT 
    p.gender,
    SUM(t.amount)/COUNT(DISTINCT t.person) average_spend
FROM transaction_done t 
JOIN profile_cleaned p ON t.person = p.id
GROUP BY p.gender
ORDER BY average_spend;

-- 17. Completion rate by viewer type
WITH events AS (
    SELECT
        r.person,
        r.offer_id,
        r.time AS received_time,
        MIN(v.time) AS view_time,
        MIN(c.time) AS completed_time
    FROM offer_received r
    LEFT JOIN offer_viewed v
           ON r.person = v.person
          AND r.offer_id = v.offer_id
          AND v.time >= r.time
    LEFT JOIN offer_completed c
           ON r.person = c.person
          AND r.offer_id = c.offer_id
          AND c.time >= r.time
    GROUP BY r.person, r.offer_id, r.time
),
diffs AS (
    SELECT
        person,
        offer_id,
        view_time - received_time AS time_to_view,
        completed_time - received_time AS time_to_complete,
        CASE WHEN completed_time IS NOT NULL THEN 1 ELSE 0 END AS completed_flag
    FROM events
)
SELECT 
    CASE 
        WHEN time_to_view <= 24 THEN 'Quick Viewer (<=1 day)'
        WHEN time_to_view <= 72 THEN 'Moderate Viewer (1–3 days)'
        ELSE 'Late Viewer (>3 days)'
    END AS view_group,
    COUNT(*) AS total,          -- viewed records
    SUM(completed_flag) AS completed,
    1.0 * SUM(completed_flag) / COUNT(*) AS completion_rate
FROM diffs
WHERE time_to_view IS NOT NULL
GROUP BY 
    CASE 
        WHEN time_to_view <= 24 THEN 'Quick Viewer (<=1 day)'
        WHEN time_to_view <= 72 THEN 'Moderate Viewer (1–3 days)'
        ELSE 'Late Viewer (>3 days)'
    END;

-- 18. Customers completed multiple offers
SELECT 
    person,
    COUNT(offer_id) offers_completed 
FROM offer_completed
GROUP BY person
HAVING COUNT(DISTINCT offer_id) > 1;        -- 9,111




select * from offer_completed;
select * from offer_received;
