USE de36_the_rocket
--TRANSACTION CREDIT SCORE PROCEDURE
GO

CREATE OR ALTER PROCEDURE flagged_transactions_score
    @transactionthreshold INT = 10000,
    @p_client_id INT,
    @flagged_transactions_score INT OUTPUT  -- OUTPUT for the output parameter
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM client AS c
        LEFT JOIN disp AS d ON c.client_id = d.client_id 
        LEFT JOIN account AS a ON d.account_id = a.account_id
        LEFT JOIN trans AS t ON d.account_id = t.account_id 
        LEFT JOIN [order] AS o ON a.account_id = o.account_id
        WHERE t.amount > @transactionthreshold
        AND c.client_id = @p_client_id
    )
    BEGIN
        SET @flagged_transactions_score = 100;  -- output parameter value (score if client has flagged transactions)
    END
    ELSE
    BEGIN
        SET @flagged_transactions_score = 250;  -- output parameter value (score if no flagged transactions)
    END;
END;

DECLARE @flagged_transactions_score INT;

EXEC flagged_transactions_score 
    @transactionthreshold = 10000,
    @p_client_id = 1,
    @flagged_transactions_score = @flagged_transactions_score OUTPUT;

SELECT @flagged_transactions_score AS 'Flagged Transactions Score';


GO


--overdraft_calculator_score procedure

CREATE OR ALTER PROCEDURE overdraft_calculator_score
    @p_client_id INT,
    @overdraft_calculator_score INT OUTPUT
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM (
            SELECT 
                c.client_id, 
                a.account_id, 
                t.trans_id, 
                t.date, 
                t.amount,
                LAG(t.balance) OVER (PARTITION BY a.account_id ORDER BY t.date) as balance_at_transaction
            FROM 
                client AS c
                LEFT JOIN disp AS d ON c.client_id = d.client_id 
                LEFT JOIN account AS a ON d.account_id = a.account_id
                LEFT JOIN trans AS t ON d.account_id = t.account_id 
                LEFT JOIN [order] AS o ON a.account_id = o.account_id
        ) AS subquery
        WHERE 
            subquery.amount > subquery.balance_at_transaction
            AND subquery.client_id = @p_client_id
    )
    BEGIN
        SET @overdraft_calculator_score = 200
    END;
    ELSE
    BEGIN
        SET @overdraft_calculator_score = 500
    END;
END;

DECLARE @overdraft_calculator_score INT;

EXECUTE overdraft_calculator_score
@p_client_id = 1,
@overdraft_calculator_score = @overdraft_calculator_score OUTPUT;

SELECT @overdraft_calculator_score AS overdraft_calculator_score;



GO
-- high_fund_clients_calculator_score procedure


CREATE OR ALTER PROCEDURE high_fund_client_score
    @p_client_id INT,
    @high_fund_client_score INT OUTPUT
AS 
BEGIN
    IF EXISTS (
        SELECT 1
        FROM (
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
                END AS operation_type,
                SUM(CASE WHEN t.operation IN ('VYBER KARTOU', 'VYBER') THEN 1 ELSE 0 END) AS num_withdraw_funds,
                SUM(CASE WHEN t.operation = 'VKLAD' THEN 1 ELSE 0 END) AS num_adding_funds
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
        ) AS subquery
        WHERE 
            subquery.operation_type IN ('Withdraw funds', 'Adding funds')
            AND subquery.client_id = @p_client_id
            AND subquery.num_withdraw_funds < subquery.num_adding_funds
    )
    BEGIN
        SET @high_fund_client_score = 250;
    END
    ELSE
    BEGIN
        SET @high_fund_client_score = 100;
    END;
END;

DECLARE @high_fund_client_score INT;

EXECUTE high_fund_client_score
    @p_client_id = 1,
    @high_fund_client_score = @high_fund_client_score OUTPUT;

SELECT @high_fund_client_score AS high_fund_clients_score;



go
--procedure for total transaction score

CREATE OR ALTER PROCEDURE total_transaction_score 
@p_client_id2 INT
@total_transaction_score INT OUTPUT
@overdraft_calculator_score INT
@flagged_transaction_score INT
@high_fund_client_score
AS
BEGIN
DECLARE @flagged_transactions_score INT;

EXEC flagged_transactions_score 
    @transactionthreshold = 10000,
    @p_client_id = 1,
    @flagged_transactions_score = @flagged_transactions_score OUTPUT;

SELECT @flagged_transactions_score AS 'Flagged Transactions Score'
END;
BEGIN
EXECUTE overdraft_calculator_score
@p_client_id = 1,
@overdraft_calculator_score = @overdraft_calculator_score OUTPUT;

SELECT @overdraft_calculator_score AS overdraft_calculator_score
END;
BEGIN
DECLARE @high_fund_client_score INT;

EXECUTE high_fund_client_score
    @p_client_id = 1,
    @high_fund_client_score = @high_fund_client_score OUTPUT;

SELECT @high_fund_client_score AS high_fund_clients_score
END;
BEGIN
SET @total_transaction_score = (@flagged_transaction_score+@overdraft_calculator_score+@high_fund_clients_score)
END;
GO

CREATE OR ALTER PROCEDURE total_transaction_score 
    @p_client_id2 INT,
    @total_transaction_score INT OUTPUT,
    @flagged_transaction_score INT
AS
BEGIN
    DECLARE @flagged_transactions_score INT
 
    -- Execute flagged_transactions_score procedure
    EXEC flagged_transactions_score 
        @transactionthreshold = 10000,
        @p_client_id = @p_client_id2, -- Use the input parameter instead of hardcoding
        @flagged_transactions_score = @flagged_transactions_score OUTPUT;

    -- Output flagged_transactions_score
    SELECT @flagged_transactions_score AS flagged_transactions_score;

    -- Execute overdraft_calculator_score procedure
    DECLARE @overdraft_calculator_score INT;
    
    EXEC overdraft_calculator_score
        @p_client_id = @p_client_id2, -- Use the input parameter instead of hardcoding
        @overdraft_calculator_score = @overdraft_calculator_score OUTPUT;

    -- Output overdraft_calculator_score
    SELECT @overdraft_calculator_score AS overdraft_calculator_score;

    -- Execute high_fund_clients_score procedure
    DECLARE @high_fund_client_score INT;

    EXEC high_fund_client_score
        @p_client_id = @p_client_id2, -- Use the input parameter instead of hardcoding
        @high_fund_client_score = @high_fund_client_score OUTPUT;

    -- Output high_fund_client_score
    SELECT @high_fund_client_score AS high_fund_client_score;

    -- Calculate total transaction score
    SET @total_transaction_score = @flagged_transaction_score + @overdraft_calculator_score + @high_fund_client_score;
END;
go

EXEC total_transaction_score @p_client_id2 = 1

DECLARE @p_client_id2 INT = 1; -- Set the client ID parameter
DECLARE @total_transaction_score_output INT; -- Declare the variable to store the output

EXEC total_transaction_score 
    @p_client_id2 = @p_client_id2, -- Pass the client ID parameter
    @total_transaction_score = @total_transaction_score_output OUTPUT; -- Capture the output

-- Output the total transaction score
SELECT @total_transaction_score_output AS total_transaction_score;



DECLARE @t int;
EXECUTE total_transaction_score @p_client_id2 = 19, @total_transaction_score = @t OUTPUT;
PRINT @t; 
go

CREATE OR ALTER PROCEDURE total_transaction_score 
    @p_client_id2 INT,
    @total_transaction_score INT OUTPUT
AS
BEGIN
    DECLARE @flagged_transaction_score INT;

    EXEC flagged_transactions_score 
        @transactionthreshold = 10000,
        @p_client_id = @p_client_id2,
        @flagged_transactions_score = @flagged_transaction_score OUTPUT;

    --SELECT @flagged_transaction_score AS flagged_transaction_score;
DECLARE @overdraft_calculator_score INT;

    EXEC overdraft_calculator_score
        @p_client_id = @p_client_id2,
        @overdraft_calculator_score = @overdraft_calculator_score OUTPUT;

    -- SELECT @overdraft_calculator_score AS overdraft_calculator_score;

    DECLARE @high_fund_client_score INT;

    EXEC high_fund_client_score
        @p_client_id = @p_client_id2,
        @high_fund_client_score = @high_fund_client_score OUTPUT;

    --SELECT @high_fund_client_score AS high_fund_clients_score;

    SET @total_transaction_score = (@flagged_transaction_score + @overdraft_calculator_score + @high_fund_client_score);
END;

DECLARE @t INT 
EXEC total_transaction_score @p_client_id2 = 4, @t

DECLARE @t INT 
EXEC total_transaction_score @p_client_id2 = 4, @total_transaction_score = @t OUTPUT
PRINT @t