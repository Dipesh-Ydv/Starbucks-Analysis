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

-- Repeat Transaction Rate (% of persons making multiple transactions)
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