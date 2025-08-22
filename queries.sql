-- ============================================================
-- Foodie-Fi Case Study Queries
-- ============================================================

-- 1. How many customers has Foodie-Fi ever had?

SELECT COUNT(DISTINCT customer_id) AS total_customers
FROM subscriptions;

---------------------------------------------------------------

-- 2. Monthly distribution of trial plan (plan_id = 0)

SELECT DATE_TRUNC('month', start_date) AS month_start,
       COUNT(*) AS trial_count
FROM subscriptions
WHERE plan_id = 0
GROUP BY month_start
ORDER BY month_start;

---------------------------------------------------------------

-- 3. What plan start_date values occur after the year 2020 ?

select p.plan_name, count(*) as start_count
from subscriptions s
left join plans p on s.plan_id=p.plan_id
where s.start_date>'2020-12-31'
group by p.plan_name
order by start_count desc;

---------------------------------------------------------------

-- 4. Customer count & % who churned (plan_id = 4)

with churned_count as(
  select count(distinct(customer_id)) as churned_customer_count
  from subscriptions s
  left join plans p on s.plan_id=p.plan_id
  where p.plan_name = 'churn'
),
total_customers as (
  select count(distinct(customer_id)) as total_count from subscriptions
)

select c.churned_customer_count,
       ROUND(100.0 * c.churned_customer_count / t.total_count, 1) AS churn_percentage
from churned_count c
cross join total_customers t

---------------------------------------------------------------

-- 5. How many customers have churned straight after their initial free trial - what percentage is this rounded to the nearest whole number?

with rank_table as (
  select s.customer_id,
    p.plan_name, 
    s.start_date, 
    row_number() over (partition by s.customer_id order by s.start_date) as plan_order 
  from subscriptions s
  left join plans p on s.plan_id=p.plan_id
   
)
select 
  count(customer_id) as churned_customers_count,
  round(100 * count(customer_id)/(select count(distinct(customer_id)) from subscriptions)) as churned_customers_percentage
from
(
  select * 
  from rank_table
  where plan_order = '2' and plan_name = 'churn'
)
;

---------------------------------------------------------------

-- 6. What is the number and percentage of customer plans after their initial free trial?

with rank_table as (
  select s.customer_id,
    p.plan_name, 
	p.plan_id,
    s.start_date, 
    row_number() over (partition by s.customer_id order by s.start_date) as plan_order 
  from subscriptions s
  left join plans p on s.plan_id=p.plan_id
   
)
select 
  plan_id,
  plan_name,
  count(distinct(customer_id)) as customers_count,
  round(100.00 * count(customer_id)/(select count(distinct(customer_id)) from subscriptions)) as customers_percentage
from
(
  select * 
  from rank_table
  where plan_order = '2'
)
group by plan_name,plan_id
order by customers_percentage desc
;

---------------------------------------------------------------

-- 7. What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?

WITH latest_plans AS (
    SELECT
        customer_id,
        plan_id,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY start_date DESC
        ) AS rn
    FROM subscriptions
    WHERE start_date <= '2020-12-31'
)
SELECT
    pl.plan_name,
    COUNT(*) AS customer_count,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(DISTINCT customer_id) FROM subscriptions), 0) AS percentage
FROM latest_plans lp
JOIN plans pl
    ON lp.plan_id = pl.plan_id
WHERE lp.rn = 1
GROUP BY pl.plan_id, pl.plan_name
ORDER BY pl.plan_id;

---------------------------------------------------------------

-- 8. How many customers have upgraded to an annual plan in 2020?

select 
  count(distinct(customer_id)) as annual_upgrade_count
from
(
select * 
from subscriptions s
left join plans p on s.plan_id=p.plan_id
where start_date between '2019-12-31' and '2020-12-31'
order by start_date asc
)
where plan_name = 'pro annual'
;

---------------------------------------------------------------

-- 9. How many days on average does it take for a customer to an annual plan from the day they join Foodie-Fi?

WITH join_dates AS (
  SELECT customer_id,
         MIN(start_date) AS join_date
  FROM subscriptions
  GROUP BY customer_id
),
annual_dates AS (
  SELECT customer_id, start_date AS annual_date
  FROM subscriptions
  WHERE plan_id = 3
)
SELECT ROUND(AVG(a.annual_date - j.join_date), 1) AS avg_days_to_annual
FROM join_dates j
JOIN annual_dates a
  ON j.customer_id = a.customer_id;
---------------------------------------------------------------

-- 10. Breakdown avg days into 30-day buckets

WITH join_dates AS (
  SELECT customer_id,
         MIN(start_date) AS join_date
  FROM subscriptions
  GROUP BY customer_id
),
annual_dates AS (
  SELECT customer_id, start_date AS annual_date
  FROM subscriptions
  WHERE plan_id = 3
),
diffs AS (
  SELECT j.customer_id,
         a.annual_date - j.join_date AS days_to_annual
  FROM join_dates j
  JOIN annual_dates a
    ON j.customer_id = a.customer_id
)
SELECT CASE
         WHEN days_to_annual BETWEEN 0 AND 30 THEN '0-30 days'
         WHEN days_to_annual BETWEEN 31 AND 60 THEN '31-60 days'
         WHEN days_to_annual BETWEEN 61 AND 90 THEN '61-90 days'
         WHEN days_to_annual BETWEEN 91 AND 120 THEN '91-120 days'
         ELSE '120+ days'
       END AS bucket,
       COUNT(*) AS customer_count
FROM diffs
GROUP BY bucket
ORDER BY MIN(days_to_annual);

---------------------------------------------------------------

-- 11. Customers downgraded from Pro Monthly (2) → Basic Monthly (1) in 2020

WITH next_ AS (
    SELECT
        customer_id,
        plan_name,
        start_date,
        LEAD(plan_name, 1) OVER (
            PARTITION BY customer_id ORDER BY start_date
        ) AS next_plan,
        LEAD(start_date, 1) OVER (
            PARTITION BY customer_id ORDER BY start_date
        ) AS next_start_date
    FROM subscriptions s
    LEFT JOIN plans p 
      ON s.plan_id = p.plan_id
)
SELECT 
    COUNT(DISTINCT customer_id) AS customers_count
FROM next_
WHERE plan_name = 'pro monthly'
  AND next_plan = 'basic monthly'
  AND EXTRACT(YEAR FROM next_start_date) = 2020;
