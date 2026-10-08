# Bank Loan & Credit Risk Analysis (SQL)

SQL analysis of ~38,000 bank loans to segment borrowers, find high-risk loan categories, compare good vs. bad loans, and build KPI views for credit-risk assessment and lending strategy.

**Open [`loan_analysis.ipynb`](loan_analysis.ipynb)** to see every query together with its result table.

## What's inside

| Part | Techniques |
|---|---|
| 1. Borrower segmentation by income, grade, purpose | conditional aggregation (`CASE WHEN`) |
| 2. High-risk loan categories | default / interest-rate trends, `HAVING`, subqueries |
| 3. Good vs. bad loans, month-by-month performance | CTEs, `LAG`, `RANK` window functions |
| 4. KPI summary views | `CREATE VIEW` for dashboard-ready metrics |

## Run it yourself

```bash
git clone <your-repo-url>
cd <your-repo-folder>
python -m venv .venv && source .venv/bin/activate    # Windows: .venv\Scripts\activate
pip install -r requirements.txt
jupyter notebook loan_analysis.ipynb
```

Then choose **Kernel → Restart & Run All**. The notebook downloads the dataset from Kaggle automatically (via `kagglehub`), builds a local SQLite database and runs every query.

To refresh the saved outputs from the command line:

```bash
jupyter nbconvert --to notebook --execute --inplace loan_analysis.ipynb
```

## Data

Kaggle: [Financial Loan Dataset](https://www.kaggle.com/datasets/datawitharyan/financial-loan-dataset) (38,576 loans).
If the automatic download doesn't work, download the file from that page and place it in `data/`. The notebook picks it up from there. The data files are git-ignored.

## MySQL version

The original queries were written for MySQL and are kept in [`sql/loan_analysis_mysql.sql`](sql/loan_analysis_mysql.sql). The notebook runs the same logic on SQLite so no database server is needed; the handful of syntax differences are listed in the notebook.

## Project structure

```
├── loan_analysis.ipynb          # the analysis (queries + result tables)
├── sql/loan_analysis_mysql.sql  # original MySQL script
├── data/                        # dataset goes here (git-ignored)
├── requirements.txt
└── README.md
```
