create database bank_analysis;

 USE bank_analysis;
 
 CREATE TABLE users (
    id INT PRIMARY KEY,
    current_age INT,
    retirement_age INT,
    birth_year INT,
    birth_month INT,
    gender VARCHAR(10),
    address VARCHAR(255),
    latitude DECIMAL(9,6),
    longitude DECIMAL(9,6),
    per_capita_income DECIMAL(15,2),
    yearly_income DECIMAL(15,2),
    total_debt DECIMAL(15,2),
    credit_score INT,
    num_credit_cards INT
);

CREATE TABLE transactions (
    id BIGINT PRIMARY KEY,
    date DATETIME,
    client_id INT,
    card_id INT,
    amount DECIMAL(10,2),
    use_chip VARCHAR(50),
    merchant_id BIGINT,
    merchant_city VARCHAR(100),
    merchant_state VARCHAR(50),
    zip VARCHAR(20),
    mcc INT,
    errors VARCHAR(255),
    FOREIGN KEY (client_id) REFERENCES users(id)
);

CREATE TABLE fraud_labels (
    transaction_id BIGINT PRIMARY KEY,
    is_fraud VARCHAR(3),
    FOREIGN KEY (transaction_id) REFERENCES transactions(id)
);

select * from fraud_labels limit 10;

select * from transactions limit 10;

select * from users limit 10;

-- Check NULL values in key columns
SELECT 
    SUM(CASE WHEN client_id IS NULL THEN 1 ELSE 0 END) AS null_client_id,
    SUM(CASE WHEN amount IS NULL THEN 1 ELSE 0 END) AS null_amount,
    SUM(CASE WHEN date IS NULL THEN 1 ELSE 0 END) AS null_date,
    SUM(CASE WHEN use_chip IS NULL THEN 1 ELSE 0 END) AS null_use_chip
FROM transactions;

-- Check for duplicate transaction IDs
SELECT id, COUNT(*) AS count
FROM transactions
GROUP BY id
HAVING COUNT(*) > 1;

-- Check if all client_ids in transactions exist in users table
SELECT COUNT(*) AS orphan_transactions
FROM transactions t
LEFT JOIN users u ON t.client_id = u.id
WHERE u.id IS NULL;

-- check transaction types
SELECT DISTINCT use_chip, COUNT(*) AS count
FROM transactions
GROUP BY use_chip;

SELECT 
    use_chip AS transaction_type,
    COUNT(*) AS total_transactions,
    ROUND(SUM(amount), 2) AS total_amount,
    ROUND(AVG(amount), 2) AS avg_amount
FROM transactions
GROUP BY use_chip
ORDER BY total_transactions DESC;

-- check for errors
SELECT errors, COUNT(*) AS count
FROM transactions
GROUP BY errors
ORDER BY count DESC;

-- Which users have the highest transaction volume?
SELECT 
    u.id AS user_id,
    u.gender,
    u.current_age,
    u.yearly_income,
    COUNT(t.id) AS total_transactions,
    ROUND(SUM(t.amount), 2) AS total_spent
FROM users u
JOIN transactions t ON u.id = t.client_id
GROUP BY u.id, u.gender, u.current_age, u.yearly_income
ORDER BY total_spent DESC;
-- INSIGHT: Client 96 is the top spender at $215,775 with 3,360 transactions.

-- Which age group spends the most?
SELECT 
    CASE 
        WHEN current_age BETWEEN 18 AND 30 THEN '18-30'
        WHEN current_age BETWEEN 31 AND 45 THEN '31-45'
        WHEN current_age BETWEEN 46 AND 60 THEN '46-60'
        ELSE '60+'
    END AS age_group,
    COUNT(DISTINCT u.id) AS total_users,
    COUNT(t.id) AS total_transactions,
    ROUND(SUM(t.amount), 2) AS total_spent,
    ROUND(AVG(t.amount), 2) AS avg_transaction_value
FROM users u
JOIN transactions t ON u.id = t.client_id
GROUP BY age_group
ORDER BY total_spent DESC;
-- INSIGHT: 46-60 age group dominates with $17.3M total spend across 408 users.

-- Revenue and transaction trend by year
SELECT 
    YEAR(date) AS year,
    COUNT(*) AS total_transactions,
    ROUND(SUM(amount), 2) AS total_revenue,
    ROUND(AVG(amount), 2) AS avg_transaction_value,
    COUNT(DISTINCT client_id) AS active_users
FROM transactions
GROUP BY YEAR(date)
ORDER BY year;
-- INSIGHT: Revenue peaked in 2002 at $1.63M then gradually declined to $1.47M by 2010, active users remained stable at ~1,124.

-- Monthly transaction trend
SELECT 
    YEAR(date) AS year,
    MONTH(date) AS month,
    COUNT(*) AS total_transactions,
    ROUND(SUM(amount), 2) AS total_revenue
FROM transactions
GROUP BY YEAR(date), MONTH(date)
ORDER BY year, month;
-- INSIGHT: Revenue fluctuates monthly showing seasonal patterns with no consistent growth.

-- Fraud analysis: fraud rate by transaction type
SELECT 
    t.use_chip AS transaction_type,
    COUNT(t.id) AS total_transactions,
    SUM(CASE WHEN f.is_fraud = 'Yes' THEN 1 ELSE 0 END) AS fraud_count,
    ROUND(SUM(CASE WHEN f.is_fraud = 'Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(t.id), 2) AS fraud_rate_pct
FROM transactions t
LEFT JOIN fraud_labels f ON t.id = f.transaction_id
GROUP BY t.use_chip
ORDER BY fraud_rate_pct DESC;
-- INSIGHT: Online transactions have 1.77% fraud rate, 88x higher than swipe at 0.02%.

-- Ranking customers by total spending
SELECT 
    client_id,
    ROUND(SUM(amount), 2) AS total_spent,
    RANK() OVER (ORDER BY SUM(amount) DESC) AS spending_rank
FROM transactions
GROUP BY client_id
ORDER BY spending_rank;
-- INSIGHT: Client 96 ranked #1 with $215,775 total spend.

-- Find high value customers who are also frequent transactors
WITH customer_summary AS (
    SELECT 
        client_id,
        COUNT(id) AS total_transactions,
        ROUND(SUM(amount), 2) AS total_spent,
        ROUND(AVG(amount), 2) AS avg_transaction
    FROM transactions
    GROUP BY client_id
)
SELECT 
    client_id,
    total_transactions,
    total_spent,
    avg_transaction,
    CASE 
        WHEN total_spent > 100000 THEN 'High Value'
        WHEN total_spent BETWEEN 50000 AND 100000 THEN 'Mid Value'
        ELSE 'Low Value'
    END AS customer_segment
FROM customer_summary
ORDER BY customer_segment, total_spent DESC;
-- INSIGHT: Customers classified into High Value (>$100K), Mid Value ($50K-$100K) and Low Value (<$50K)Segments.

-- Fraud rate by customer age group
SELECT 
    CASE 
        WHEN u.current_age BETWEEN 18 AND 30 THEN '18-30'
        WHEN u.current_age BETWEEN 31 AND 45 THEN '31-45'
        WHEN u.current_age BETWEEN 46 AND 60 THEN '46-60'
        ELSE '60+'
    END AS age_group,
    COUNT(t.id) AS total_transactions,
    SUM(CASE WHEN f.is_fraud = 'Yes' THEN 1 ELSE 0 END) AS fraud_count,
    ROUND(SUM(CASE WHEN f.is_fraud = 'Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(t.id), 2) AS fraud_rate_pct
FROM users u
JOIN transactions t ON u.id = t.client_id
LEFT JOIN fraud_labels f ON t.id = f.transaction_id
GROUP BY age_group
ORDER BY fraud_rate_pct DESC;
-- INSIGHT: 18-30 age group has highest fraud rate at 0.24% despite being the smallest segment.

-- Running total revenue by year
SELECT 
    YEAR(date) AS year,
    ROUND(SUM(amount), 2) AS yearly_revenue,
    ROUND(SUM(SUM(amount)) OVER (ORDER BY YEAR(date)), 2) AS running_total
FROM transactions
GROUP BY YEAR(date)
ORDER BY year;
-- INSIGHT: Business accumulated $15.6M cumulative revenue by 2010, flat yearly contributions of ~$1.5M.

-- High value customers with poor credit score (business risk)
WITH customer_stats AS (
    SELECT 
        u.id AS client_id,
        u.credit_score,
        u.yearly_income,
        u.total_debt,
        COUNT(t.id) AS total_transactions,
        ROUND(SUM(t.amount), 2) AS total_spent
    FROM users u
    JOIN transactions t ON u.id = t.client_id
    GROUP BY u.id, u.credit_score, u.yearly_income, u.total_debt
)
SELECT 
    client_id,
    credit_score,
    yearly_income,
    total_debt,
    total_spent,
    RANK() OVER (ORDER BY total_spent DESC) AS spending_rank
FROM customer_stats
WHERE credit_score < 600
ORDER BY total_spent DESC; 
-- INSIGHT: Among all 2,000 customers, 60 high risk customers were identified with credit scores below 600 who are also high spenders. 
