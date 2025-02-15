CREATE DATABASE Assignment2;
--created database

--creating the table name as customer
CREATE TABLE Customers (
    CustomerID SERIAL PRIMARY KEY,
    Name VARCHAR(100) NOT NULL,
    RegistrationDate DATE NOT NULL DEFAULT CURRENT_DATE
);

--creating the table name as Products
CREATE TABLE Products (
    ProductID SERIAL PRIMARY KEY,
    ProductName VARCHAR(100) NOT NULL,
    Category VARCHAR(50) NOT NULL,
    Price DECIMAL(10,2) NOT NULL,
    Stock INT NOT NULL CHECK (Stock >= 0)
);

----creating the table name as orders
CREATE TABLE Orders (
    OrderID SERIAL PRIMARY KEY,
    CustomerID INT NOT NULL,
    OrderDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    TotalAmount DECIMAL(10,2) NOT NULL CHECK (TotalAmount >= 0),
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID) ON DELETE CASCADE
);

--creating the table name as orderDetails
CREATE TABLE OrderDetails (
    OrderDetailID SERIAL PRIMARY KEY,
    OrderID INT NOT NULL,
    ProductID INT NOT NULL,
    Quantity INT NOT NULL CHECK (Quantity > 0),
    Subtotal DECIMAL(10,2) NOT NULL CHECK (Subtotal >= 0),
    FOREIGN KEY (OrderID) REFERENCES Orders(OrderID) ON DELETE CASCADE,
    FOREIGN KEY (ProductID) REFERENCES Products(ProductID) ON DELETE CASCADE
);
--Inserting the values in the customers table
INSERT INTO Customers (Name, RegistrationDate) VALUES
('Prashant sahu',CURRENT_DATE),
('Rohan me',CURRENT_DATE),
('karan me',CURRENT_DATE),
('Rohit sharma ',CURRENT_DATE),
('Virat kohli ',CURRENT_DATE),
('Rishabh pant',CURRENT_DATE);


--Inserting the values in the Products table

INSERT INTO Products (ProductName, Category, Price, Stock) VALUES
('Laptop', 'Electronics', 1299.99, 10),
('Smartphone', 'Electronics', 599.99, 20),
('Tablet', 'Electronics', 799.99, 12),
('Headphones', 'Accessories', 499.99, 15),
('Keyboard', 'Accessories', 350.00, 30),
('Mouse', 'Accessories', 650.00, 22),
('Gaming Console', 'Gaming', 849.75, 8),
('Gaming Headset', 'Gaming', 299.99, 25),
('Gaming Mouse', 'Gaming', 150.00, 18),
('Smartwatch', 'Wearables', 600.00, 25),
('Fitness Tracker', 'Wearables', 450.00, 20),
('VR Headset', 'Wearables', 799.99, 10);

SELECT * FROM Products;

--Inserting the values in the Orders table
INSERT INTO Orders (CustomerID, OrderDate, TotalAmount) VALUES
(1, '2024-03-10', 2500.00),
(2, '2024-04-05', 1800.00),
(3, '2024-05-15', 950.00),
(4, '2024-06-20', 1799.97),
(5, '2024-07-10', 599.99),
(6, '2024-08-25', 2499.99),
(1, '2024-09-05', 1599.50),
(3, '2024-10-12', 899.75),
(5, '2024-11-18', 2200.00),
(6, '2024-12-22', 1750.00),
(4, '2025-01-01', 2600.00),
(2, '2025-02-05', 1350.00);

SELECT * FROM Orders;

--Inserting the values in the OrderDetails table
INSERT INTO OrderDetails (OrderID, ProductID, Quantity, Subtotal) VALUES
(1, 1, 1, 1299.99),
(1, 3, 2, 1599.98),
(2, 2, 3, 1799.97),
(3, 5, 1, 499.99),
(4, 6, 2, 1300.00),
(5, 7, 1, 849.75),
(6, 8, 3, 899.97),
(7, 10, 4, 2600.00),
(8, 1, 2, 2599.98),
(9, 2, 1, 599.99),
(10, 4, 2, 1200.00),
(11, 7, 2, 1699.50),
(12, 12, 1, 799.99);


--retriving the data
SELECT * FROM OrderDetails;
--------------------------------------------------------------------------------------------------------------


--Task 1 
-- 1 Retrieve the top 3 customers with the highest total purchase amount.
SELECT c.Name,c.CustomerID, SUM(o.TotalAmount) AS TotalPurchase
FROM Customers c
JOIN Orders o ON c.CustomerID =o.CustomerID
GROUP BY c.Name,c.CustomerID
ORDER BY TotalPurchase DESC
LIMIT 3;



-------------------------------------------------------------------------------------------------------------
-- 2. Show monthly sales revenue for the last 6 months using PIVOT
--need to create the extensionto run the crosstab()
CREATE EXTENSION IF NOT EXISTS tablefunc;

--crosstab() it require the 2 arguments first that is our base query and second,columns that we want to create 

SELECT * FROM crosstab(
    $$ 
    SELECT 
        TO_CHAR(DATE_TRUNC('month', OrderDate), 'YYYY-MM') AS Month, 
        'Total Revenue' AS revenue_label, 
        COALESCE(SUM(TotalAmount), 0) AS TotalRevenue
    FROM Orders
    WHERE OrderDate >= DATE_TRUNC('month', NOW()) - INTERVAL '5 months'
    GROUP BY Month
    ORDER BY Month
    $$ 
) AS ct (month TEXT, "Total Revenue" NUMERIC); 

-----------------------------------------------------------------------------------------------------

--Find the second most expensive product in each category using window functions.
SELECT ProductName, Category, Price
FROM (
    SELECT ProductName, Category, Price, 
           DENSE_RANK() OVER (PARTITION BY Category ORDER BY Price DESC) AS price_rank --DENSE-RANK() FUNCTION USED 
    FROM Products
) ranked_products
WHERE price_rank = 2;

--SELECT DISTINCT Products.category FROM Products;
--SELECT * FROM Products;
---------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------
--Task2 : Stored Procedures and Functions


--1. Create a stored procedure to place an order, which:
	--Deducts stock from the Products table.
	--Inserts data into the Orders and OrderDetails tables.
	--Returns the new OrderId.

CREATE OR REPLACE PROCEDURE PlaceOrder(
    IN p_CustomerID INT,
    IN p_ProductID INT,
    IN p_Quantity INT,
    OUT p_NewOrderID INT
)
LANGUAGE plpgsql
AS $$
DECLARE
	--declaring the variables
    v_ProductPrice DECIMAL;
    v_TotalAmount DECIMAL;
    v_AvailableStock INT;
BEGIN
    -- Fetch product details
    SELECT Price, Stock INTO v_ProductPrice, v_AvailableStock
    FROM Products WHERE ProductID = p_ProductID
    FOR UPDATE;

    -- Check if product exists
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product does not exist!';
    END IF;

    -- Check stock
    IF v_AvailableStock < p_Quantity THEN
        RAISE EXCEPTION 'Not enough stock available!';
    END IF;

    -- Calculate total price
    v_TotalAmount := v_ProductPrice * p_Quantity;

    -- Insert into Orders
    INSERT INTO Orders (CustomerID, OrderDate, TotalAmount)
    VALUES (p_CustomerID, NOW(), v_TotalAmount)
    RETURNING OrderID INTO p_NewOrderID;

    -- Insert into OrderDetails
    INSERT INTO OrderDetails (OrderID, ProductID, Quantity, Subtotal)
    VALUES (p_NewOrderID, p_ProductID, p_Quantity, v_TotalAmount);

    -- Deduct stock
    UPDATE Products SET Stock = Stock - p_Quantity WHERE ProductID = p_ProductID;
END;
$$;

SELECT * FROM Products;
--for execute stored procedure
CALL PlaceOrder(1, 5, 1, NULL);
--customerid,product_id,quantity, output


--------------------------------------------------------------------------------------------------------
-- 2. Write a user-defined function that takes a CustomerID and returns the total amount spent by that customer.

CREATE OR REPLACE FUNCTION GetTotalSpent(p_CustomerID INT)
RETURNS DECIMAL AS $$
DECLARE
    v_TotalSpent DECIMAL := 0;
BEGIN
    -- Calculate the total amount spent by the customer
    SELECT COALESCE(SUM(TotalAmount), 0) 
    INTO v_TotalSpent
    FROM Orders
    WHERE CustomerID = p_CustomerID;

    -- Return the result
    RETURN v_TotalSpent;
END;
$$ LANGUAGE plpgsql;

--here calling the function getTotalSpent(1) where argument is a customer id
SELECT GetTotalSpent(1);

---------------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------------
--Task 3 :  Transactions and Concurrency Control

--1.Write a transaction to ensure an order is placed only if all products are in stock. If any product is out of stock, rollback the transaction.

BEGIN;  -- Start the transaction

-- Step 1: Check if all products in the order have sufficient stock
DO $$ 
DECLARE	
    insufficient_stock BOOLEAN := FALSE;
    product RECORD;
BEGIN
    -- Loop through each product in the order and check stock
    FOR product IN
        SELECT p.ProductID, p.Stock, od.Quantity
        FROM OrderDetails od
        JOIN Products p ON od.ProductID = p.ProductID
        WHERE od.OrderID = 1  -- Replace with your actual OrderID
    LOOP
        IF product.Stock < product.Quantity THEN
            -- Set flag to true if stock is insufficient
            insufficient_stock := TRUE;
            EXIT;  -- Exit the loop if any product is out of stock
        END IF;
    END LOOP;

    -- If there's insufficient stock, rollback the transaction
    IF insufficient_stock THEN
        RAISE EXCEPTION 'Insufficient stock for one or more products. Rolling back the transaction.';
    END IF;
END $$;

-- Step 2: If all products are in stock, update stock levels
UPDATE Products
SET Stock = Stock - od.Quantity
FROM OrderDetails od
WHERE Products.ProductID = od.ProductID
AND od.OrderID = 1;  -- Replace with your actual OrderID

-- Step 3: Insert new order into the Orders table
INSERT INTO Orders (CustomerID, OrderDate, TotalAmount)
SELECT CustomerID, CURRENT_DATE, SUM(od.Subtotal)
FROM OrderDetails od
JOIN Orders o ON od.OrderID = o.OrderID
WHERE od.OrderID = 1
GROUP BY o.CustomerID;

-- Step 4: Commit the transaction if everything is successful
COMMIT;

--SELECT * FROM OrderDetails;
--ROLLBACK;
---------------------------------------------------------------------------------------------------------

-- 2. Create the function to handle deadlocks during the update of order details
CREATE OR REPLACE FUNCTION UpdateOrderDetailWithRetry(
    p_OrderDetailID INT,
    p_NewQuantity INT,
    p_RetryLimit INT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_RetryCount INT := 0;
    v_UpdateSuccess BOOLEAN := FALSE;
    v_Stock INT;
    v_ProductID INT;
    v_Price DECIMAL(10,2);
BEGIN
    -- Loop to retry in case of deadlocks
    WHILE v_RetryCount < p_RetryLimit AND NOT v_UpdateSuccess LOOP
        BEGIN
            -- Get the ProductID and Stock for the given OrderDetailID
            SELECT ProductID INTO v_ProductID
            FROM OrderDetails
            WHERE OrderDetailID = p_OrderDetailID;

            -- Fetch the Price from the Products table
            SELECT Stock, Price INTO v_Stock, v_Price
            FROM Products
            WHERE ProductID = v_ProductID;

            -- Check if the stock is sufficient for the new quantity
            IF v_Stock < p_NewQuantity THEN
                RAISE EXCEPTION 'Not enough stock for ProductID: %, available stock: %, requested: %', 
                    v_ProductID, v_Stock, p_NewQuantity;
            END IF;

            -- Attempt to update the order details
            UPDATE OrderDetails
            SET Quantity = p_NewQuantity,
                Subtotal = (v_Price * p_NewQuantity)
            WHERE OrderDetailID = p_OrderDetailID;

            -- If the update is successful, set the success flag to TRUE
            v_UpdateSuccess := TRUE;

        EXCEPTION
            WHEN serialization_failure THEN
                -- Handle deadlock or serialization failure
                v_RetryCount := v_RetryCount + 1;
                RAISE NOTICE 'Deadlock detected. Retrying... Attempt: %', v_RetryCount;
                PERFORM pg_sleep(2); -- Sleep for 2 seconds before retrying
            WHEN OTHERS THEN
                -- Reraise any other exceptions
                RAISE;
        END;
    END LOOP;

    IF NOT v_UpdateSuccess THEN
        RAISE EXCEPTION 'Failed to update OrderDetailID % after % attempts', p_OrderDetailID, p_RetryLimit;
    END IF;
END;
$$;
--to roll back the transaction
--ROLLBACK;

--to call the functions with transaction

BEGIN;
SELECT UpdateOrderDetailWithRetry(1, 2, 5);
COMMIT;

--SELECT *FROM OrderDetails;
-------------------------------------------------------------------------------------------------------------------
--3.Use SAVEPOINT to allow partial updates in an order process where only some items might be out of stock.

BEGIN;  -- Start transaction

SAVEPOINT start_point;  -- Initial savepoint

DO $$ 
DECLARE
    v_ProductID INT;
    v_Quantity INT;
    v_AvailableStock INT;
    v_ProductPrice DECIMAL(10, 2);
    v_Subtotal DECIMAL(10, 2);
    v_TotalAmount DECIMAL(10, 2) := 0;
    v_NewOrderID INT;
    p_CustomerID INT := 1;  -- Example Customer ID
BEGIN
    -- Create a savepoint for partial rollback in case of errors
    SAVEPOINT partial_update;

    -- Step 1: Create a new order
    INSERT INTO Orders (CustomerID, OrderDate, TotalAmount)
    VALUES (p_CustomerID, CURRENT_DATE, 0)
    RETURNING OrderID INTO v_NewOrderID;

    -- Step 2: Process each cart item
    FOR v_ProductID, v_Quantity IN 
        SELECT ProductID, Quantity FROM Cart WHERE CustomerID = p_CustomerID
    LOOP
        -- Step 3: Lock stock row and check availability
        SELECT Stock INTO v_AvailableStock 
        FROM Products 
        WHERE ProductID = v_ProductID 
        FOR UPDATE;

        -- Step 4: Handle stock shortage
        IF v_AvailableStock < v_Quantity THEN
            RAISE NOTICE 'Product % is out of stock. Skipping...', v_ProductID;
            CONTINUE;
        END IF;

        -- Step 5: Retrieve product price and compute subtotal
        SELECT Price INTO v_ProductPrice FROM Products WHERE ProductID = v_ProductID;
        v_Subtotal := v_ProductPrice * v_Quantity;

        -- Step 6: Deduct stock
        UPDATE Products
        SET Stock = Stock - v_Quantity
        WHERE ProductID = v_ProductID;

        -- Step 7: Insert order details
        INSERT INTO OrderDetails (OrderID, ProductID, Quantity, Subtotal)
        VALUES (v_NewOrderID, v_ProductID, v_Quantity, v_Subtotal);

        -- Step 8: Update total order amount
        v_TotalAmount := v_TotalAmount + v_Subtotal;
    END LOOP;

    -- Step 9: Final order update
    UPDATE Orders
    SET TotalAmount = v_TotalAmount
    WHERE OrderID = v_NewOrderID;

    -- Success message
    RAISE NOTICE 'Order placed successfully with OrderID: %', v_NewOrderID;

EXCEPTION
    WHEN OTHERS THEN
        -- Rollback only to the partial update savepoint
        ROLLBACK TO SAVEPOINT partial_update;
        RAISE NOTICE 'Error occurred. Rolling back to partial_update savepoint.';
        RAISE;
END $$;

COMMIT;

------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------
--Task 4:SQL for Reporting and Analytics

--1. Generate a customer purchase report using ROLLUP that includes		
	--Total purchases by customer
	--Total of all purchases

SELECT 
    CustomerID,
    SUM(TotalAmount) AS TotalPurchaseAmount
FROM Orders
GROUP BY ROLLUP(CustomerID)
ORDER BY CustomerID;

---------------------------------------------------------------------------------------------------------
--2.Use window functions (LEAD, LAG) to show how a customer's order amount compares to their previous order amount.
SELECT 
    o.OrderID,
    o.CustomerID,
    c.Name, 
    o.OrderDate,
    o.TotalAmount AS CurrentOrderAmount,
	--Retrieves the previous row's value in a result set based on a specified ordering.
    LAG(o.TotalAmount) OVER (PARTITION BY o.CustomerID ORDER BY o.OrderDate) AS PreviousOrderAmount,
	--Retrieves the next row's value in a result set based on a specified ordering.
    LEAD(o.TotalAmount) OVER (PARTITION BY o.CustomerID ORDER BY o.OrderDate) AS NextOrderAmount
FROM Orders o
JOIN Customers c ON o.CustomerID = c.CustomerID  -- Join to get customer name
ORDER BY o.CustomerID, o.OrderDate;

