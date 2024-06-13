USE DE36_the_rocket;
SELECT * from account, card, client, disp, district, loan, [order], trans;
SELECT * FROM [order]
SELECT * FROM card
SELECT * FROM trans
SELECT * FROM loan

--- TRANSACTION ACTIVITY -- look into transaction type, operation, ammount and balance 
----to find patterns of financial behaviour, regular income source and spending habits
SELECT *
FROM client AS c
LEFT JOIN disp AS d ON c.client_id = d.client_id 
LEFT JOIN account AS a ON d.account_id = a.account_id
LEFT JOIN trans AS t ON d.account_id = t.account_id 
LEFT JOIN [order] AS o ON a.account_id = o.account_id

-- match account_id to client_id
SELECT c.client_id, a.account_id
FROM client AS c
LEFT JOIN disp AS d ON c.client_id = d.client_id 
LEFT JOIN account AS a ON d.account_id = a.account_id
LEFT JOIN trans AS t ON d.account_id = t.account_id 
LEFT JOIN [order] AS o ON a.account_id = o.account_id
GROUP BY c.client_id, a.account_id;
GO

--calculate number of transactions per account. This identifies inactive accounts that may need to be closed.
WITH MYCTE AS
(SELECT 
 account_id
,COUNT(trans_id) as num_transactions
FROM trans
GROUP BY account_id
)
SELECT * from mycte 
WHERE num_transactions < 10
GO

--transactions per account per year
WITH MYCTE AS
(SELECT 
 account_id
,COUNT(trans_id) as num_transactions
FROM trans
GROUP BY account_id
)
SELECT from mycte 
WHERE num_transactions < 10
GO
--(need to finish above if have time)


CREATE OR ALTER PROCEDURE transaction_calculator
    @threshold INT
AS
BEGIN
DECLARE @threshold INT;
IF EXISTS 
(
    SELECT 1
    FROM trans
    GROUP BY account_id
    HAVING COUNT(trans_id) < @threshold
 )
BEGIN
WITH MYCTE AS 
(
    SELECT 
    account_id,
    COUNT(trans_id) AS num_transactions
    FROM trans
    GROUP BY account_id
)
    SELECT * FROM MYCTE WHERE num_transactions < @threshold;
    END
    ELSE
    PRINT 'No accounts with fewer than ' + CAST(@threshold AS VARCHAR(10)) + ' transactions.';
END;

EXECUTE transaction_calculator @threshold = 5

--calculating large transactions for bank security purposes

SELECT c.client_id, a.account_id, t.trans_id, t.date, t.amount
,CASE WHEN t.amount > 5000 THEN 'The quantity is greater than 5000'
 ELSE 'The quantity is less than 5000'
END AS flag_transaction
FROM client AS c
LEFT JOIN disp AS d ON c.client_id = d.client_id 
LEFT JOIN account AS a ON d.account_id = a.account_id
LEFT JOIN trans AS t ON d.account_id = t.account_id 
LEFT JOIN [order] AS o ON a.account_id = o.account_id
WHERE t.amount > 5000; -- Filter transactions with amount greater than 5000
GO

--FLAGGED TRANSACTIONS CALCULATOR

CREATE OR ALTER PROC flagged_transactions
@transactionthreshold INT
AS
BEGIN
SELECT c.client_id, a.account_id, t.trans_id, t.date, t.amount
,CASE WHEN t.amount > @transactionthreshold THEN 'Alert large transaction'
 ELSE 'No large transaction alert'
END AS flag_transaction
FROM client AS c
LEFT JOIN disp AS d ON c.client_id = d.client_id 
LEFT JOIN account AS a ON d.account_id = a.account_id
LEFT JOIN trans AS t ON d.account_id = t.account_id 
LEFT JOIN [order] AS o ON a.account_id = o.account_id
WHERE t.amount > @transactionthreshold
GROUP BY c.client_id, a.account_id, t.trans_id, t.date, t.amount
END;

EXECUTE flagged_transactions @transactionthreshold = 5000

--identify clients who have made a transaction amount > account balance with account balance calculated as the balance after the previous transaction WHEN transaction is outgoing

WITH MYCTE AS
(
SELECT c.client_id, a.account_id, t.trans_id, t.date, t.amount, t.type
, LAG(t.balance) OVER (PARTITION BY a.account_id ORDER BY t.date) as balance_at_transaction
FROM client AS c
LEFT JOIN disp AS d ON c.client_id = d.client_id 
LEFT JOIN account AS a ON d.account_id = a.account_id
LEFT JOIN trans AS t ON d.account_id = t.account_id 
LEFT JOIN [order] AS o ON a.account_id = o.account_id
GROUP BY c.client_id, a.account_id, t.trans_id, t.date, t.amount, t.balance, t.type
)
SELECT *
FROM MYCTE
WHERE amount > balance_at_transaction AND (type = 'VYDAJ' OR type = 'VYBER');
GO

CREATE OR ALTER PROC overdraft_calculator
AS
BEGIN
WITH MYCTE AS
(
SELECT c.client_id, a.account_id, t.trans_id, t.date, t.amount
, LAG(t.balance) OVER (PARTITION BY a.account_id ORDER BY t.date) as balance_at_transaction
FROM client AS c
LEFT JOIN disp AS d ON c.client_id = d.client_id 
LEFT JOIN account AS a ON d.account_id = a.account_id
LEFT JOIN trans AS t ON d.account_id = t.account_id 
LEFT JOIN [order] AS o ON a.account_id = o.account_id
GROUP BY c.client_id, a.account_id, t.trans_id, t.date, t.amount, t.balance
)
SELECT *
FROM MYCTE
WHERE amount > balance_at_transaction
END;

EXEC overdraft_calculator

--Types of transaction

SELECT distinct type --identify what the types are
FROM trans

SELECT c.client_id, t.trans_id, t.account_id, t.date, t.type
,CASE WHEN t.type = 'PRIJEM' THEN 'Income'
      WHEN t.type = 'VYDAJ' THEN 'Expenditure (goods,services,financial obligations)'
      WHEN t.type = 'VYBER' THEN 'Withdrawal (cash withdrawal)' 
ELSE NULL
END AS transaction_type
FROM client as c
LEFT JOIN disp AS d ON c.client_id = d.client_id 
LEFT JOIN account AS a ON d.account_id = a.account_id
LEFT JOIN trans AS t ON d.account_id = t.account_id 
LEFT JOIN [order] AS o ON a.account_id = o.account_id
GROUP BY c.client_id, t.trans_id, t.account_id, t.date, t.type;


--types of transaction operation
SELECT distinct operation --identify what the types are
FROM trans

--identify clients and associated accounts where the number of withdrawal transactions is less than adding fund transactions = good clients;

WITH MYCTE AS (
    SELECT
        c.client_id,
        t.account_id,
        t.operation,
        t.date,
        CASE
            WHEN t.operation = 'VYBER KARTOU' THEN 'Withdraw funds'
            WHEN t.operation = 'PREVOD NA UCET' THEN 'Account transfer (received)'
            WHEN t.operation = 'VKLAD' THEN 'Adding funds' 
            WHEN t.operation = 'PREVOD Z UCTU' THEN 'Account transfer (sent)'
            WHEN t.operation = 'VYBER' THEN 'Withdraw funds'
            ELSE NULL
        END AS operation_type
    FROM
        client AS c
    LEFT JOIN
        disp AS d ON c.client_id = d.client_id 
    LEFT JOIN
        account AS a ON d.account_id = a.account_id
    LEFT JOIN
        trans AS t ON d.account_id = t.account_id 
    LEFT JOIN
        [order] AS o ON a.account_id = o.account_id
    GROUP BY
        c.client_id, t.account_id, t.operation, t.date
),
MYCTE2 AS (
    SELECT
        client_id,
        account_id,
        DATEPART(year, date) AS year,
        SUM(CASE WHEN operation_type = 'Withdraw funds' THEN 1 ELSE 0 END) AS num_withdraw_funds,
        SUM(CASE WHEN operation_type = 'Adding funds' THEN 1 ELSE 0 END) AS num_adding_funds
    FROM
        MYCTE
    WHERE
        operation_type IN ('Withdraw funds', 'Adding funds')
    GROUP BY
        client_id, account_id, DATEPART(year, date)
)
SELECT
    client_id,
    account_id,
    year
FROM
    MYCTE2
WHERE
    num_withdraw_funds < num_adding_funds AND year = 1996;
GO

    --procedure for calculating num_withdrawal_funds < num_adding_funds

CREATE PROC high_fund_clients
@year INT
AS 
BEGIN
WITH MYCTE AS (
    SELECT
        c.client_id,
        t.account_id,
        t.operation,
        t.date,
        CASE
            WHEN t.operation = 'VYBER KARTOU' THEN 'Withdraw funds'
            WHEN t.operation = 'PREVOD NA UCET' THEN 'Account transfer (received)'
            WHEN t.operation = 'VKLAD' THEN 'Adding funds' 
            WHEN t.operation = 'PREVOD Z UCTU' THEN 'Account transfer (sent)'
            WHEN t.operation = 'VYBER' THEN 'Withdraw funds'
            ELSE NULL
        END AS operation_type
    FROM
        client AS c
    LEFT JOIN
        disp AS d ON c.client_id = d.client_id 
    LEFT JOIN
        account AS a ON d.account_id = a.account_id
    LEFT JOIN
        trans AS t ON d.account_id = t.account_id 
    LEFT JOIN
        [order] AS o ON a.account_id = o.account_id
    GROUP BY
        c.client_id, t.account_id, t.operation, t.date
),
MYCTE2 AS (
    SELECT
        client_id,
        account_id,
        DATEPART(year, date) AS year,
        SUM(CASE WHEN operation_type = 'Withdraw funds' THEN 1 ELSE 0 END) AS num_withdraw_funds,
        SUM(CASE WHEN operation_type = 'Adding funds' THEN 1 ELSE 0 END) AS num_adding_funds
    FROM
        MYCTE
    WHERE
        operation_type IN ('Withdraw funds', 'Adding funds')
    GROUP BY
        client_id, account_id, DATEPART(year, date)
)
SELECT
    client_id,
    account_id,
    year
FROM
    MYCTE2
WHERE
    num_withdraw_funds < num_adding_funds AND year = @year;
    END;

EXEC high_fund_clients @year = 1996

--OVERALL CREDIT SCORE

