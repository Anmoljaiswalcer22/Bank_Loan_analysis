-- =====================================================================
-- BANK LOAN & CREDIT RISK ANALYSIS (MySQL)
-- Dataset: "Bank Loan Data" / "Financial Loan Data" from Kaggle (~38,000 rows)
-- Run the sections in order. After importing the CSV, check that your
-- column names match the table below and edit the queries if they differ.
-- =====================================================================


-- ---------------------------------------------------------------------
-- STEP 0: Create database and table
-- ---------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS loan_analysis;
USE loan_analysis;

CREATE TABLE bank_loan (
    id                    INT PRIMARY KEY,
    address_state         VARCHAR(5),
    application_type      VARCHAR(20),
    emp_length            VARCHAR(20),
    emp_title             VARCHAR(100),
    grade                 CHAR(1),
    home_ownership        VARCHAR(20),
    issue_date            VARCHAR(12),     -- stored as text like 11-02-2021, converted below
    last_credit_pull_date VARCHAR(12),
    last_payment_date     VARCHAR(12),
    loan_status           VARCHAR(20),     -- Fully Paid / Current / Charged Off
    next_payment_date     VARCHAR(12),
    member_id             INT,
    purpose               VARCHAR(50),
    sub_grade             VARCHAR(5),
    term                  VARCHAR(15),
    verification_status   VARCHAR(30),
    annual_income         DECIMAL(12,2),
    dti                   DECIMAL(6,4),    -- debt-to-income ratio
    installment           DECIMAL(10,2),
    int_rate              DECIMAL(6,4),    -- 0.1227 means 12.27%
    loan_amount           INT,             -- the funded amount
    total_acc             INT,
    total_payment         INT              -- amount received back from the borrower
);

-- Import the CSV now:
-- MySQL Workbench -> right-click the table bank_loan -> Table Data Import Wizard


-- ---------------------------------------------------------------------
-- STEP 1: Clean the data and sanity-check the import
-- ---------------------------------------------------------------------
-- Convert the text date into a real DATE column
ALTER TABLE bank_loan ADD COLUMN issue_dt DATE;

UPDATE bank_loan
SET issue_dt = STR_TO_DATE(issue_date, '%d-%m-%Y')
WHERE id IS NOT NULL;

-- Row count and the loan_status values present
SELECT COUNT(*) AS total_rows FROM bank_loan;

SELECT loan_status, COUNT(*) AS loans
FROM bank_loan
GROUP BY loan_status;

-- Date range covered by the data
SELECT MIN(issue_dt) AS first_loan, MAX(issue_dt) AS last_loan FROM bank_loan;


-- =====================================================================
-- BULLET 1: Conditional aggregation (CASE WHEN) to segment borrowers
--           by income, grade and loan purpose
-- =====================================================================

-- 1A. Segment borrowers by income band
SELECT
    CASE
        WHEN annual_income <  40000 THEN '1. Under 40K'
        WHEN annual_income <  80000 THEN '2. 40K - 80K'
        WHEN annual_income < 120000 THEN '3. 80K - 120K'
        ELSE                             '4. Above 120K'
    END                                                   AS income_band,
    COUNT(id)                                             AS applications,
    SUM(loan_amount)                                      AS total_funded,
    ROUND(AVG(int_rate) * 100, 2)                         AS avg_int_rate_pct,
    SUM(CASE WHEN loan_status = 'Charged Off' THEN 1 ELSE 0 END)                    AS defaulted_loans,
    ROUND(SUM(CASE WHEN loan_status = 'Charged Off' THEN 1 ELSE 0 END) * 100.0
          / COUNT(id), 2)                                 AS default_rate_pct
FROM bank_loan
GROUP BY income_band
ORDER BY income_band;

-- 1B. Segment by loan grade (A = safest, G = riskiest)
SELECT
    grade,
    COUNT(id)                                             AS applications,
    SUM(loan_amount)                                      AS total_funded,
    SUM(CASE WHEN loan_status = 'Fully Paid'  THEN 1 ELSE 0 END) AS fully_paid,
    SUM(CASE WHEN loan_status = 'Current'     THEN 1 ELSE 0 END) AS current_loans,
    SUM(CASE WHEN loan_status = 'Charged Off' THEN 1 ELSE 0 END) AS charged_off
FROM bank_loan
GROUP BY grade
ORDER BY grade;

-- 1C. Segment by loan purpose
SELECT
    purpose,
    COUNT(id)                                             AS applications,
    SUM(loan_amount)                                      AS total_funded,
    ROUND(AVG(dti) * 100, 2)                              AS avg_dti_pct,
    ROUND(SUM(CASE WHEN loan_status = 'Charged Off' THEN 1 ELSE 0 END) * 100.0
          / COUNT(id), 2)                                 AS default_rate_pct
FROM bank_loan
GROUP BY purpose
ORDER BY total_funded DESC;


-- =====================================================================
-- BULLET 2: Default rate, funded amount and interest rate trends to
--           identify high-risk loan categories
-- =====================================================================

-- 2A. Default rate and interest rate by grade and term
SELECT
    grade,
    term,
    COUNT(id)                                             AS applications,
    SUM(loan_amount)                                      AS funded_amount,
    ROUND(AVG(int_rate) * 100, 2)                         AS avg_int_rate_pct,
    ROUND(SUM(loan_status = 'Charged Off') * 100.0 / COUNT(id), 2) AS default_rate_pct
FROM bank_loan
GROUP BY grade, term
ORDER BY default_rate_pct DESC;

-- 2B. High-risk categories: purposes whose default rate is ABOVE the
--     overall portfolio default rate (uses a subquery)
SELECT
    purpose,
    COUNT(id)                                             AS applications,
    ROUND(SUM(loan_status = 'Charged Off') * 100.0 / COUNT(id), 2) AS default_rate_pct
FROM bank_loan
GROUP BY purpose
HAVING SUM(loan_status = 'Charged Off') * 100.0 / COUNT(id) >
       (SELECT SUM(loan_status = 'Charged Off') * 100.0 / COUNT(*) FROM bank_loan)
ORDER BY default_rate_pct DESC;

-- 2C. Default rate by home ownership and verification status
SELECT
    home_ownership,
    verification_status,
    COUNT(id)                                             AS applications,
    ROUND(SUM(loan_status = 'Charged Off') * 100.0 / COUNT(id), 2) AS default_rate_pct
FROM bank_loan
GROUP BY home_ownership, verification_status
HAVING COUNT(id) > 100
ORDER BY default_rate_pct DESC;

-- 2D. Top 5 states by funded amount, with their default rate
SELECT
    address_state,
    SUM(loan_amount)                                      AS funded_amount,
    ROUND(SUM(loan_status = 'Charged Off') * 100.0 / COUNT(id), 2) AS default_rate_pct
FROM bank_loan
GROUP BY address_state
ORDER BY funded_amount DESC
LIMIT 5;


-- =====================================================================
-- BULLET 3: Subqueries and CTEs to compare good loans vs. bad loans and
--           measure portfolio performance month by month
-- =====================================================================

-- 3A. Good loans vs bad loans (CTE)
--     Good = Fully Paid or Current,  Bad = Charged Off
WITH loan_class AS (
    SELECT
        *,
        CASE
            WHEN loan_status IN ('Fully Paid', 'Current') THEN 'Good Loan'
            ELSE 'Bad Loan'
        END AS loan_type
    FROM bank_loan
)
SELECT
    loan_type,
    COUNT(id)                                             AS applications,
    ROUND(COUNT(id) * 100.0 / (SELECT COUNT(*) FROM bank_loan), 2) AS pct_of_portfolio,
    SUM(loan_amount)                                      AS funded_amount,
    SUM(total_payment)                                    AS amount_received,
    ROUND(AVG(int_rate) * 100, 2)                         AS avg_int_rate_pct,
    ROUND(AVG(dti) * 100, 2)                              AS avg_dti_pct
FROM loan_class
GROUP BY loan_type;

-- 3B. Month-by-month portfolio performance with month-over-month growth
WITH monthly AS (
    SELECT
        DATE_FORMAT(issue_dt, '%Y-%m')                    AS ym,
        COUNT(id)                                         AS applications,
        SUM(loan_amount)                                  AS funded_amount,
        SUM(total_payment)                                AS amount_received,
        SUM(loan_status = 'Charged Off')                  AS bad_loans
    FROM bank_loan
    GROUP BY DATE_FORMAT(issue_dt, '%Y-%m')
)
SELECT
    ym,
    applications,
    funded_amount,
    amount_received,
    ROUND(bad_loans * 100.0 / applications, 2)            AS default_rate_pct,
    ROUND((funded_amount - LAG(funded_amount) OVER (ORDER BY ym)) * 100.0
          / LAG(funded_amount) OVER (ORDER BY ym), 2)     AS mom_funded_growth_pct
FROM monthly
ORDER BY ym;

-- 3C. Good vs bad loans by month (conditional aggregation inside a CTE)
WITH monthly_split AS (
    SELECT
        DATE_FORMAT(issue_dt, '%Y-%m')                    AS ym,
        SUM(CASE WHEN loan_status IN ('Fully Paid','Current') THEN loan_amount ELSE 0 END) AS good_funded,
        SUM(CASE WHEN loan_status = 'Charged Off'             THEN loan_amount ELSE 0 END) AS bad_funded
    FROM bank_loan
    GROUP BY DATE_FORMAT(issue_dt, '%Y-%m')
)
SELECT
    ym,
    good_funded,
    bad_funded,
    ROUND(bad_funded * 100.0 / (good_funded + bad_funded), 2) AS bad_share_pct
FROM monthly_split
ORDER BY ym;

-- 3D. Rank purposes by funded amount within each grade (window function)
SELECT *
FROM (
    SELECT
        grade,
        purpose,
        SUM(loan_amount) AS funded_amount,
        RANK() OVER (PARTITION BY grade ORDER BY SUM(loan_amount) DESC) AS rank_in_grade
    FROM bank_loan
    GROUP BY grade, purpose
) ranked
WHERE rank_in_grade <= 3
ORDER BY grade, rank_in_grade;


-- =====================================================================
-- BULLET 4: Summary views of KPIs for credit risk assessment and
--           lending strategy
-- =====================================================================

-- 4A. Overall KPI view
CREATE OR REPLACE VIEW vw_kpi_summary AS
SELECT
    COUNT(id)                                             AS total_applications,
    SUM(loan_amount)                                      AS total_funded_amount,
    SUM(total_payment)                                    AS total_amount_received,
    ROUND(AVG(int_rate) * 100, 2)                         AS avg_int_rate_pct,
    ROUND(AVG(dti) * 100, 2)                              AS avg_dti_pct,
    ROUND(SUM(loan_status = 'Charged Off') * 100.0 / COUNT(id), 2)               AS default_rate_pct,
    ROUND(SUM(CASE WHEN loan_status IN ('Fully Paid','Current') THEN 1 ELSE 0 END)
          * 100.0 / COUNT(id), 2)                         AS good_loan_pct
FROM bank_loan;

-- 4B. Risk view by grade
CREATE OR REPLACE VIEW vw_risk_by_grade AS
SELECT
    grade,
    COUNT(id)                                             AS applications,
    SUM(loan_amount)                                      AS funded_amount,
    ROUND(AVG(int_rate) * 100, 2)                         AS avg_int_rate_pct,
    ROUND(SUM(loan_status = 'Charged Off') * 100.0 / COUNT(id), 2) AS default_rate_pct
FROM bank_loan
GROUP BY grade;

-- 4C. Monthly trend view (for a dashboard)
CREATE OR REPLACE VIEW vw_monthly_trend AS
SELECT
    DATE_FORMAT(issue_dt, '%Y-%m')                        AS ym,
    COUNT(id)                                             AS applications,
    SUM(loan_amount)                                      AS funded_amount,
    SUM(total_payment)                                    AS amount_received,
    ROUND(SUM(loan_status = 'Charged Off') * 100.0 / COUNT(id), 2) AS default_rate_pct
FROM bank_loan
GROUP BY DATE_FORMAT(issue_dt, '%Y-%m');

-- Use the views like normal tables:
SELECT * FROM vw_kpi_summary;
SELECT * FROM vw_risk_by_grade ORDER BY default_rate_pct DESC;
SELECT * FROM vw_monthly_trend ORDER BY ym;
