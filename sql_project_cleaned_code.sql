
PROJECT: HOTEL BOOKING DATA CLEANING
DATABASE: MySQL
PURPOSE: Clean and standardize the hotel booking dataset.
SOURCE TABLE: hotels
WORKING TABLE: hotels_clean

IMPORTANT:
1. Keep the original `hotels` table unchanged.
2. Run this script against a fresh `hotels_clean` table.
3. The original booking_date and arrival_date columns are retained as TEXT.
   Standardized dates are stored in clean_booking_dates and clean_arrival_dates.


-- =========================================================
-- 01. CREATE A STAGING / WORKING TABLE
-- =========================================================

SET SQL_SAFE_UPDATES = 0;

CREATE TABLE hotels_clean LIKE hotels;

INSERT INTO hotels_clean
SELECT *
FROM hotels;


-- Add a temporary row identifier so duplicate rows can be
-- identified and removed without changing the original table.
ALTER TABLE hotels_clean
ADD COLUMN row_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY FIRST;


-- =========================================================
-- 02. CHECK BOOKING_ID FOR MISSING VALUES
-- =========================================================

SELECT
    SUM(booking_id IS NULL) AS null_values,
    SUM(booking_id = '') AS empty_values,
    SUM(TRIM(booking_id) = '' AND booking_id <> '') AS whitespace_only
FROM hotels_clean;


-- =========================================================
-- 03. IDENTIFY DUPLICATE BOOKING IDS
-- =========================================================

SELECT
    booking_id,
    COUNT(*) AS total_records
FROM hotels_clean
GROUP BY booking_id
HAVING COUNT(*) > 1;


-- =========================================================
-- 04. INSPECT SAMPLE RECORDS WITH DUPLICATE BOOKING IDS
-- =========================================================

SELECT *
FROM hotels_clean
WHERE booking_id IN ('HTL03640', 'HTL01762', 'HTL01586')
ORDER BY booking_id;


-- =========================================================
-- 05. IDENTIFY EXACT DUPLICATE RECORDS
-- Compare all original dataset columns.
-- =========================================================

WITH duplicate_records AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY
                booking_id,
                hotel_type,
                guest_name,
                country,
                booking_date,
                arrival_date,
                room_type,
                meal_plan,
                adults,
                children,
                stay_nights,
                adr,
                market_segment,
                booking_status,
                deposit_type
            ORDER BY row_id
        ) AS rn
    FROM hotels_clean
)
SELECT *
FROM duplicate_records
WHERE rn > 1;


-- =========================================================
-- 06. DELETE EXTRA COPIES OF EXACT DUPLICATE RECORDS
-- Keep one copy of each identical record.
-- =========================================================

DELETE FROM hotels_clean
WHERE row_id IN (
    SELECT row_id
    FROM (
        SELECT
            row_id,
            ROW_NUMBER() OVER (
                PARTITION BY
                    booking_id,
                    hotel_type,
                    guest_name,
                    country,
                    booking_date,
                    arrival_date,
                    room_type,
                    meal_plan,
                    adults,
                    children,
                    stay_nights,
                    adr,
                    market_segment,
                    booking_status,
                    deposit_type
                ORDER BY row_id
            ) AS rn
        FROM hotels_clean
    ) AS duplicate_rows
    WHERE rn > 1
);


-- =========================================================
-- 07. HOTEL_TYPE: CHECK MISSING VALUES AND DISTINCT VALUES
-- =========================================================

SELECT
    SUM(hotel_type IS NULL) AS null_values,
    SUM(hotel_type = '') AS empty_values,
    SUM(TRIM(hotel_type) = '' AND hotel_type <> '') AS whitespace_only
FROM hotels_clean;

SELECT
    hotel_type,
    COUNT(*) AS total_records
FROM hotels_clean
GROUP BY hotel_type;


-- =========================================================
-- 08. HOTEL_TYPE: STANDARDIZE TEXT VALUES
-- =========================================================

UPDATE hotels_clean
SET hotel_type =
    CASE
        WHEN LOWER(TRIM(hotel_type)) = 'city hotel'
            THEN 'City Hotel'
        WHEN LOWER(TRIM(hotel_type)) = 'resort hotel'
            THEN 'Resort Hotel'
        ELSE hotel_type
    END
WHERE hotel_type IS NOT NULL;


-- =========================================================
-- 09. GUEST_NAME: CHECK AND HANDLE MISSING VALUES
-- =========================================================

SELECT
    SUM(guest_name IS NULL) AS null_values,
    SUM(guest_name = '') AS empty_values,
    SUM(TRIM(guest_name) = '' AND guest_name <> '') AS whitespace_only
FROM hotels_clean;

UPDATE hotels_clean
SET guest_name = NULL
WHERE TRIM(guest_name) = '';


-- =========================================================
-- 10. COUNTRY: CHECK DISTINCT AND MISSING VALUES
-- =========================================================

SELECT
    country,
    COUNT(*) AS total_records
FROM hotels_clean
GROUP BY country
ORDER BY country;

SELECT
    SUM(country IS NULL) AS null_values,
    SUM(country = '') AS empty_values,
    SUM(TRIM(country) = '' AND country <> '') AS whitespace_only
FROM hotels_clean;


-- =========================================================
-- 11. COUNTRY: CONVERT BLANKS TO NULL
-- =========================================================

UPDATE hotels_clean
SET country = NULL
WHERE TRIM(country) = '';


-- =========================================================
-- 12. COUNTRY: STANDARDIZE KNOWN COUNTRY LABELS
-- =========================================================

UPDATE hotels_clean
SET country =
    CASE
        WHEN LOWER(TRIM(country)) IN ('united states', 'usa')
            THEN 'United States'
        WHEN LOWER(TRIM(country)) = 'india'
            THEN 'India'
        WHEN LOWER(TRIM(country)) = 'uae'
            THEN 'UAE'
        WHEN LOWER(TRIM(country)) IN ('uk', 'u.k.')
            THEN 'United Kingdom'
        ELSE country
    END
WHERE country IS NOT NULL;


-- =========================================================
-- 13. BOOKING_DATE: CHECK MISSING VALUES
-- =========================================================

SELECT
    SUM(booking_date IS NULL) AS null_values,
    SUM(booking_date = '') AS empty_values,
    SUM(TRIM(booking_date) = '' AND booking_date <> '') AS whitespace_only
FROM hotels_clean;


-- =========================================================
-- 14. BOOKING_DATE: IDENTIFY THE ORIGINAL DATE FORMATS
-- Confirmed formats:
-- DD/MM/YYYY, YYYY/MM/DD, YYYY-MM-DD, DD-MMM-YYYY
-- =========================================================

SELECT
    CASE
        WHEN booking_date LIKE '__/__/____' THEN 'DD/MM/YYYY'
        WHEN booking_date LIKE '____/__/__' THEN 'YYYY/MM/DD'
        WHEN booking_date LIKE '____-__-__' THEN 'YYYY-MM-DD'
        WHEN booking_date LIKE '__-___-____' THEN 'DD-MMM-YYYY'
        ELSE 'Other / Unmatched'
    END AS date_format,
    COUNT(*) AS total_records
FROM hotels_clean
GROUP BY date_format;


-- =========================================================
-- 15. BOOKING_DATE: CREATE A CLEAN DATE COLUMN
-- =========================================================

ALTER TABLE hotels_clean
ADD COLUMN clean_booking_dates DATE NULL;


-- =========================================================
-- 16. BOOKING_DATE: CONVERT YYYY-MM-DD FORMAT
-- =========================================================

UPDATE hotels_clean
SET clean_booking_dates = STR_TO_DATE(booking_date, '%Y-%m-%d')
WHERE booking_date LIKE '____-__-__';


-- =========================================================
-- 17. BOOKING_DATE: CONVERT DD-MMM-YYYY FORMAT
-- =========================================================

UPDATE hotels_clean
SET clean_booking_dates = STR_TO_DATE(booking_date, '%d-%b-%Y')
WHERE booking_date LIKE '__-___-____';


-- =========================================================
-- 18. BOOKING_DATE: CONVERT YYYY/MM/DD FORMAT
-- =========================================================

UPDATE hotels_clean
SET clean_booking_dates = STR_TO_DATE(booking_date, '%Y/%m/%d')
WHERE booking_date LIKE '____/__/__';


-- =========================================================
-- 19. BOOKING_DATE: CONVERT DD/MM/YYYY FORMAT
-- All slash-separated dates were confirmed as DD/MM/YYYY.
-- =========================================================

UPDATE hotels_clean
SET clean_booking_dates = STR_TO_DATE(booking_date, '%d/%m/%Y')
WHERE clean_booking_dates IS NULL
  AND booking_date LIKE '__/__/____';


-- =========================================================
-- 20. ARRIVAL_DATE: CHECK MISSING VALUES
-- =========================================================

SELECT
    SUM(arrival_date IS NULL) AS null_values,
    SUM(arrival_date = '') AS empty_values,
    SUM(TRIM(arrival_date) = '' AND arrival_date <> '') AS whitespace_only
FROM hotels_clean;


-- =========================================================
-- 21. ARRIVAL_DATE: IDENTIFY THE ORIGINAL DATE FORMATS
-- =========================================================

SELECT
    CASE
        WHEN arrival_date LIKE '__/__/____' THEN 'DD/MM/YYYY'
        WHEN arrival_date LIKE '__-___-____' THEN 'DD-MMM-YYYY'
        WHEN arrival_date LIKE '____-__-__' THEN 'YYYY-MM-DD'
        WHEN arrival_date LIKE '____/__/__' THEN 'YYYY/MM/DD'
        ELSE 'Other / Unmatched'
    END AS date_format,
    COUNT(*) AS total_records
FROM hotels_clean
GROUP BY date_format;


-- =========================================================
-- 22. ARRIVAL_DATE: CREATE A CLEAN DATE COLUMN
-- =========================================================

ALTER TABLE hotels_clean
ADD COLUMN clean_arrival_dates DATE NULL;


-- =========================================================
-- 23. ARRIVAL_DATE: CONVERT DD-MMM-YYYY FORMAT
-- =========================================================

UPDATE hotels_clean
SET clean_arrival_dates = STR_TO_DATE(arrival_date, '%d-%b-%Y')
WHERE arrival_date LIKE '__-___-____';


-- =========================================================
-- 24. ARRIVAL_DATE: CONVERT YYYY-MM-DD FORMAT
-- =========================================================

UPDATE hotels_clean
SET clean_arrival_dates = STR_TO_DATE(arrival_date, '%Y-%m-%d')
WHERE arrival_date LIKE '____-__-__';


-- =========================================================
-- 25. ARRIVAL_DATE: CONVERT YYYY/MM/DD FORMAT
-- =========================================================

UPDATE hotels_clean
SET clean_arrival_dates = STR_TO_DATE(arrival_date, '%Y/%m/%d')
WHERE arrival_date LIKE '____/__/__';


-- =========================================================
-- 26. ARRIVAL_DATE: CONVERT DD/MM/YYYY FORMAT
-- All slash-separated dates were confirmed as DD/MM/YYYY.
-- =========================================================

UPDATE hotels_clean
SET clean_arrival_dates = STR_TO_DATE(arrival_date, '%d/%m/%Y')
WHERE clean_arrival_dates IS NULL
  AND arrival_date LIKE '__/__/____';


-- =========================================================
-- 27. ROOM_TYPE: CHECK MISSING AND DISTINCT VALUES
-- =========================================================

SELECT
    SUM(room_type IS NULL) AS null_values,
    SUM(room_type = '') AS empty_values,
    SUM(TRIM(room_type) = '' AND room_type <> '') AS whitespace_only
FROM hotels_clean;

SELECT DISTINCT room_type
FROM hotels_clean;


-- =========================================================
-- 28. ROOM_TYPE: CONVERT BLANKS TO NULL
-- =========================================================

UPDATE hotels_clean
SET room_type = NULL
WHERE TRIM(room_type) = '';


-- =========================================================
-- 29. ROOM_TYPE: STANDARDIZE KNOWN VALUES
-- ELSE preserves any other category, such as Family.
-- =========================================================

UPDATE hotels_clean
SET room_type =
    CASE
        WHEN LOWER(TRIM(room_type)) IN ('std', 'standard')
            THEN 'Standard'
        WHEN LOWER(TRIM(room_type)) = 'deluxe'
            THEN 'Deluxe'
        WHEN LOWER(TRIM(room_type)) = 'suite'
            THEN 'Suite'
        WHEN LOWER(TRIM(room_type)) = 'family'
            THEN 'Family'
        ELSE room_type
    END
WHERE room_type IS NOT NULL;


-- =========================================================
-- 30. MEAL_PLAN: CHECK DISTINCT AND MISSING VALUES
-- =========================================================

SELECT DISTINCT meal_plan
FROM hotels_clean;

SELECT
    SUM(meal_plan IS NULL) AS null_values,
    SUM(meal_plan = '') AS empty_values,
    SUM(TRIM(meal_plan) = '' AND meal_plan <> '') AS whitespace_only
FROM hotels_clean;


-- =========================================================
-- 31. MEAL_PLAN: CONVERT BLANKS TO NULL
-- =========================================================

UPDATE hotels_clean
SET meal_plan = NULL
WHERE TRIM(meal_plan) = '';


-- =========================================================
-- 32. MEAL_PLAN: STANDARDIZE KNOWN VALUES
-- =========================================================

UPDATE hotels_clean
SET meal_plan =
    CASE
        WHEN LOWER(TRIM(meal_plan)) = 'breakfast'
            THEN 'Breakfast'
        WHEN LOWER(TRIM(meal_plan)) = 'half-board'
            THEN 'Half Board'
        WHEN LOWER(TRIM(meal_plan)) = 'ro'
            THEN 'Room Only'
        ELSE meal_plan
    END
WHERE meal_plan IS NOT NULL;


-- =========================================================
-- 33. ADULTS: CHECK DISTINCT AND MISSING VALUES
-- =========================================================

SELECT DISTINCT adults
FROM hotels_clean;

SELECT
    SUM(adults IS NULL) AS null_values,
    SUM(adults = '') AS empty_values,
    SUM(TRIM(adults) = '' AND adults <> '') AS whitespace_only
FROM hotels_clean;


-- =========================================================
-- 34. ADULTS: REMOVE RECORDS WITH INVALID VALUES
-- As decided for this project, records with 0 and -1 adults
-- are removed.
-- =========================================================

DELETE FROM hotels_clean
WHERE adults IN ('0', '-1');


-- =========================================================
-- 35. CHILDREN: CHECK MISSING VALUES
-- =========================================================

SELECT
    SUM(children IS NULL) AS null_values,
    SUM(children = '') AS empty_values,
    SUM(TRIM(children) = '' AND children <> '') AS whitespace_only
FROM hotels_clean;


-- =========================================================
-- 36. CHILDREN: CONVERT BLANKS TO NULL
-- =========================================================

UPDATE hotels_clean
SET children = NULL
WHERE children = '';


-- =========================================================
-- 37. CHILDREN: HANDLE INVALID NEGATIVE VALUE
-- =========================================================

UPDATE hotels_clean
SET children = NULL
WHERE children = '-1.0';


-- =========================================================
-- 38. STAY_NIGHTS: CHECK MISSING VALUES
-- =========================================================

SELECT
    SUM(stay_nights IS NULL) AS null_values,
    SUM(stay_nights = '') AS empty_values,
    SUM(TRIM(stay_nights) = '' AND stay_nights <> '') AS whitespace_only
FROM hotels_clean;


-- =========================================================
-- 39. STAY_NIGHTS: HANDLE INVALID NEGATIVE VALUE
-- Negative stay duration -2 is converted to NULL.
-- Zero-night stays are retained.
-- =========================================================

UPDATE hotels_clean
SET stay_nights = NULL
WHERE stay_nights = -2;


-- =========================================================
-- 40. ADR: CHECK MISSING VALUES
-- =========================================================

SELECT
    SUM(adr IS NULL) AS null_values,
    SUM(adr = '') AS empty_values,
    SUM(TRIM(adr) = '' AND adr <> '') AS whitespace_only
FROM hotels_clean;


-- =========================================================
-- 41. ADR: CONVERT BLANKS TO NULL
-- =========================================================

UPDATE hotels_clean
SET adr = NULL
WHERE adr = '';


-- =========================================================
-- 42. ADR: HANDLE NEGATIVE VALUES
-- =========================================================

UPDATE hotels_clean
SET adr = NULL
WHERE adr < 0;


-- =========================================================
-- 43. MARKET_SEGMENT: CHECK MISSING AND DISTINCT VALUES
-- =========================================================

SELECT
    SUM(market_segment IS NULL) AS null_values,
    SUM(market_segment = '') AS empty_values,
    SUM(market_segment IS NOT NULL AND TRIM(market_segment) = '') AS whitespace_values
FROM hotels_clean;

SELECT DISTINCT market_segment
FROM hotels_clean;


-- =========================================================
-- 44. MARKET_SEGMENT: CONVERT BLANKS TO NULL
-- =========================================================

UPDATE hotels_clean
SET market_segment = NULL
WHERE TRIM(market_segment) = '';


-- =========================================================
-- 45. MARKET_SEGMENT: STANDARDIZE TEXT VALUES
-- =========================================================

UPDATE hotels_clean
SET market_segment =
    CASE
        WHEN LOWER(TRIM(market_segment)) = 'online ta'
            THEN 'Online TA'
        WHEN LOWER(TRIM(market_segment)) = 'offline ta'
            THEN 'Offline TA'
        WHEN LOWER(TRIM(market_segment)) = 'corporate'
            THEN 'Corporate'
        WHEN LOWER(TRIM(market_segment)) = 'direct'
            THEN 'Direct'
        WHEN LOWER(TRIM(market_segment)) = 'groups'
            THEN 'Groups'
        ELSE market_segment
    END
WHERE market_segment IS NOT NULL;


-- =========================================================
-- 46. BOOKING_STATUS: CHECK MISSING VALUES
-- =========================================================

SELECT
    SUM(booking_status IS NULL) AS null_values,
    SUM(booking_status = '') AS empty_values,
    SUM(booking_status IS NOT NULL AND TRIM(booking_status) = '') AS whitespace_values
FROM hotels_clean;


-- =========================================================
-- 47. BOOKING_STATUS: CONVERT BLANKS TO NULL
-- =========================================================

UPDATE hotels_clean
SET booking_status = NULL
WHERE TRIM(booking_status) = '';


-- =========================================================
-- 48. BOOKING_STATUS: STANDARDIZE STATUS LABELS
-- =========================================================

UPDATE hotels_clean
SET booking_status =
    CASE
        WHEN LOWER(TRIM(booking_status)) IN ('check-out', 'checked out')
            THEN 'Check-Out'
        WHEN LOWER(TRIM(booking_status)) IN ('cancelled', 'canceled')
            THEN 'Canceled'
        WHEN LOWER(TRIM(booking_status)) IN ('no-show', 'no show')
            THEN 'No-Show'
        ELSE booking_status
    END
WHERE booking_status IS NOT NULL;


-- =========================================================
-- 49. DEPOSIT_TYPE: CHECK MISSING VALUES
-- =========================================================

SELECT
    SUM(deposit_type IS NULL) AS null_values,
    SUM(deposit_type = '') AS empty_values,
    SUM(deposit_type IS NOT NULL AND TRIM(deposit_type) = '') AS whitespace_values
FROM hotels_clean;


-- =========================================================
-- 50. DEPOSIT_TYPE: CONVERT BLANKS TO NULL
-- =========================================================

UPDATE hotels_clean
SET deposit_type = NULL
WHERE TRIM(deposit_type) = '';


-- =========================================================
-- 51. DEPOSIT_TYPE: STANDARDIZE DEPOSIT LABELS
-- =========================================================

UPDATE hotels_clean
SET deposit_type =
    CASE
        WHEN LOWER(TRIM(deposit_type)) = 'no deposit'
            THEN 'No Deposit'
        WHEN LOWER(TRIM(deposit_type)) IN ('non refund', 'non-refund')
            THEN 'Non Refund'
        WHEN LOWER(TRIM(deposit_type)) = 'refundable'
            THEN 'Refundable'
        ELSE deposit_type
    END
WHERE deposit_type IS NOT NULL;


-- =========================================================
-- 52. DATA TYPE: CONVERT BOOKING_ID TO VARCHAR
-- =========================================================

ALTER TABLE hotels_clean
MODIFY COLUMN booking_id VARCHAR(20) NOT NULL;


-- =========================================================
-- 53. DATA TYPE: CONVERT NUMERIC COLUMNS
-- =========================================================

ALTER TABLE hotels_clean
MODIFY COLUMN adults INT NULL,
MODIFY COLUMN children INT NULL,
MODIFY COLUMN stay_nights INT NULL;


-- =========================================================
-- 54. DATA TYPE: CONVERT ADR TO DECIMAL
-- =========================================================

ALTER TABLE hotels_clean
MODIFY COLUMN adr DECIMAL(10,2) NULL;


-- =========================================================
-- 55. PRIMARY KEY: REPLACE ROW_ID WITH BOOKING_ID
-- Run only after confirming booking_id has no duplicates
-- and no NULL values.
-- =========================================================

ALTER TABLE hotels_clean
DROP PRIMARY KEY,
DROP COLUMN row_id,
ADD PRIMARY KEY (booking_id);


-- =========================================================
-- 56. DATA TYPE: CONVERT HOTEL_TYPE TO VARCHAR
-- =========================================================

ALTER TABLE hotels_clean
MODIFY COLUMN hotel_type VARCHAR(30) NULL;


-- =========================================================
-- 57. DATA TYPE: CONVERT GUEST_NAME TO VARCHAR
-- =========================================================

ALTER TABLE hotels_clean
MODIFY COLUMN guest_name VARCHAR(50) NULL;


-- =========================================================
-- 58. DATA TYPE: CONVERT COUNTRY TO VARCHAR
-- =========================================================

ALTER TABLE hotels_clean
MODIFY COLUMN country VARCHAR(50) NULL;


-- =========================================================
-- 59. DATA TYPE: CONVERT ROOM_TYPE TO VARCHAR
-- =========================================================

ALTER TABLE hotels_clean
MODIFY COLUMN room_type VARCHAR(30) NULL;


-- =========================================================
-- 60. DATA TYPE: CONVERT MEAL_PLAN TO VARCHAR
-- =========================================================

ALTER TABLE hotels_clean
MODIFY COLUMN meal_plan VARCHAR(30) NULL;


-- =========================================================
-- 61. DATA TYPE: CONVERT MARKET_SEGMENT TO VARCHAR
-- =========================================================

ALTER TABLE hotels_clean
MODIFY COLUMN market_segment VARCHAR(30) NULL;


-- =========================================================
-- 62. DATA TYPE: CONVERT BOOKING_STATUS TO VARCHAR
-- =========================================================

ALTER TABLE hotels_clean
MODIFY COLUMN booking_status VARCHAR(30) NULL;


-- =========================================================
-- 63. DATA TYPE: CONVERT DEPOSIT_TYPE TO VARCHAR
-- =========================================================

ALTER TABLE hotels_clean
MODIFY COLUMN deposit_type VARCHAR(30) NULL;


