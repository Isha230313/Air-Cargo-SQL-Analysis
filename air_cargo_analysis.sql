-- ============================================================
-- Air Cargo Analysis
-- Author: Isha Sharma
-- Description: SQL analysis of customer, passenger, route,
--              and ticket data for an air cargo/airline dataset.
-- Database: MySQL
-- ============================================================

CREATE SCHEMA IF NOT EXISTS air_cargo;
USE air_cargo;

-- ------------------------------------------------------------
-- 1. Preview the source tables
-- ------------------------------------------------------------
SELECT * FROM customer;
SELECT * FROM passengers_on_flights;
SELECT * FROM routes;
SELECT * FROM ticket_details;

-- ------------------------------------------------------------
-- 2. Passengers who travelled on routes 1 to 25
-- ------------------------------------------------------------
SELECT CONCAT(first_name, ' ', last_name) AS customer_name
FROM customer
WHERE customer_id IN (
    SELECT DISTINCT customer_id
    FROM passengers_on_flights
    WHERE route_id BETWEEN 1 AND 25
);

-- ------------------------------------------------------------
-- 3. Number of passengers and total revenue in Business class
-- ------------------------------------------------------------
SELECT
    COUNT(DISTINCT customer_id) AS customer_count,
    SUM(no_of_tickets * price_per_ticket) AS total_revenue
FROM ticket_details
WHERE class_id = 'Business';

-- ------------------------------------------------------------
-- 4. Display each customer's full name
-- ------------------------------------------------------------
SELECT CONCAT(first_name, ' ', last_name) AS customer_name
FROM customer;

-- ------------------------------------------------------------
-- 5. Customers who registered and booked a ticket
-- ------------------------------------------------------------
SELECT CONCAT(first_name, ' ', last_name) AS customer_name
FROM customer
WHERE customer_id IN (
    SELECT DISTINCT customer_id
    FROM ticket_details
);

-- ------------------------------------------------------------
-- 6. Customers who booked with Emirates
-- ------------------------------------------------------------
SELECT CONCAT(first_name, ' ', last_name) AS customer_name
FROM customer
WHERE customer_id IN (
    SELECT DISTINCT customer_id
    FROM ticket_details
    WHERE brand = 'Emirates'
);

-- ------------------------------------------------------------
-- 7. Customers who travelled in Economy Plus class
--    using GROUP BY and HAVING
-- ------------------------------------------------------------
SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name
FROM customer AS c
JOIN passengers_on_flights AS p
    ON c.customer_id = p.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
HAVING SUM(CASE WHEN p.class_id = 'Economy Plus' THEN 1 ELSE 0 END) > 0;

-- ------------------------------------------------------------
-- 8. Check whether total revenue crossed 10,000
-- ------------------------------------------------------------
SELECT
    IF(
        SUM(no_of_tickets * price_per_ticket) > 10000,
        'Greater than 10K',
        'Less than or equal to 10K'
    ) AS revenue_check
FROM ticket_details;

SELECT
    CASE
        WHEN SUM(no_of_tickets * price_per_ticket) > 10000
            THEN 'Greater than 10K'
        ELSE 'Less than or equal to 10K'
    END AS revenue_check
FROM ticket_details;

-- ------------------------------------------------------------
-- 9. User creation and privileges
-- Security note: use your own username, host, and strong password.
-- Run administrative statements only with appropriate permissions.
-- ------------------------------------------------------------
-- CREATE USER IF NOT EXISTS 'new_user'@'localhost'
-- IDENTIFIED BY 'YOUR_STRONG_PASSWORD';
-- GRANT ALL PRIVILEGES ON air_cargo.* TO 'new_user'@'localhost';

-- ------------------------------------------------------------
-- 10. Maximum ticket price for each class using a window function
-- ------------------------------------------------------------
SELECT
    *,
    MAX(price_per_ticket) OVER (PARTITION BY class_id) AS max_ticket_price
FROM ticket_details;

-- ------------------------------------------------------------
-- 11. Improve route_id lookup performance and query route 4
-- ------------------------------------------------------------
CREATE INDEX idx_route_id
ON passengers_on_flights (route_id);

SELECT customer_id
FROM passengers_on_flights
WHERE route_id = 4;

-- View the execution plan
EXPLAIN
SELECT *
FROM passengers_on_flights
WHERE route_id = 4;

-- ------------------------------------------------------------
-- 12. Total ticket price by customer and aircraft using ROLLUP
-- ------------------------------------------------------------
SELECT
    customer_id,
    aircraft_id,
    SUM(no_of_tickets * price_per_ticket) AS total_booking
FROM ticket_details
GROUP BY customer_id, aircraft_id WITH ROLLUP;

-- ------------------------------------------------------------
-- 13. View containing Business class customers and airline brands
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW business_class_customers AS
SELECT
    customer_id,
    brand,
    class_id
FROM ticket_details
WHERE class_id = 'Business';

SELECT * FROM business_class_customers;

-- ------------------------------------------------------------
-- 14. Stored procedure: passenger details for a route range
-- ------------------------------------------------------------
DELIMITER //

DROP PROCEDURE IF EXISTS check_route //

CREATE PROCEDURE check_route(IN start_route INT, IN end_route INT)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SELECT
            'Please check whether the required tables and route data exist.'
            AS message;
    END;

    SELECT *
    FROM customer
    WHERE customer_id IN (
        SELECT DISTINCT customer_id
        FROM passengers_on_flights
        WHERE route_id BETWEEN start_route AND end_route
    );
END //

DELIMITER ;

CALL check_route(1, 5);

-- ------------------------------------------------------------
-- 15. Stored procedure: routes longer than 2,000 miles
-- ------------------------------------------------------------
DELIMITER //

DROP PROCEDURE IF EXISTS check_dist //

CREATE PROCEDURE check_dist()
BEGIN
    SELECT *
    FROM routes
    WHERE distance_miles > 2000;
END //

DELIMITER ;

CALL check_dist();

-- ------------------------------------------------------------
-- 16. Classify routes by travelled distance
-- SDT: 0-2,000 miles
-- IDT: 2,001-6,500 miles
-- LDT: more than 6,500 miles
-- ------------------------------------------------------------
SELECT
    *,
    CASE
        WHEN distance_miles BETWEEN 0 AND 2000 THEN 'SDT'
        WHEN distance_miles BETWEEN 2001 AND 6500 THEN 'IDT'
        ELSE 'LDT'
    END AS distance_classification
FROM routes;

DELIMITER //

DROP FUNCTION IF EXISTS group_dist //

CREATE FUNCTION group_dist(dist INT)
RETURNS VARCHAR(3)
DETERMINISTIC
BEGIN
    DECLARE dist_cat VARCHAR(3);

    IF dist BETWEEN 0 AND 2000 THEN
        SET dist_cat = 'SDT';
    ELSEIF dist BETWEEN 2001 AND 6500 THEN
        SET dist_cat = 'IDT';
    ELSE
        SET dist_cat = 'LDT';
    END IF;

    RETURN dist_cat;
END //

DROP PROCEDURE IF EXISTS group_dist_proc //

CREATE PROCEDURE group_dist_proc()
BEGIN
    SELECT
        flight_num,
        distance_miles,
        group_dist(distance_miles) AS distance_category
    FROM routes;
END //

DELIMITER ;

CALL group_dist_proc();

-- ------------------------------------------------------------
-- 17. Complimentary service eligibility by travel class
-- Business and Economy Plus customers receive complimentary services
-- ------------------------------------------------------------
SELECT
    p_date,
    customer_id,
    class_id,
    CASE
        WHEN class_id IN ('Business', 'Economy Plus') THEN 'Yes'
        ELSE 'No'
    END AS complimentary_services
FROM ticket_details;

DELIMITER //

DROP FUNCTION IF EXISTS check_comp_serv //

CREATE FUNCTION check_comp_serv(cls VARCHAR(50))
RETURNS CHAR(3)
DETERMINISTIC
BEGIN
    DECLARE comp_ser CHAR(3);

    IF cls IN ('Business', 'Economy Plus') THEN
        SET comp_ser = 'Yes';
    ELSE
        SET comp_ser = 'No';
    END IF;

    RETURN comp_ser;
END //

DROP PROCEDURE IF EXISTS check_comp_serv_proc //

CREATE PROCEDURE check_comp_serv_proc()
BEGIN
    SELECT
        p_date,
        customer_id,
        class_id,
        check_comp_serv(class_id) AS complimentary_service
    FROM ticket_details;
END //

DELIMITER ;

CALL check_comp_serv_proc();

-- ------------------------------------------------------------
-- 18. First customer record whose last name ends with 'Scott'
-- ------------------------------------------------------------
SELECT *
FROM customer
WHERE last_name LIKE '%Scott'
LIMIT 1;
