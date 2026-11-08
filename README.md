# Hotel Booking Data Cleaning Using MySQL

## Project Overview
A SQL-based data cleaning project focused on improving the quality and consistency of a hotel booking dataset.

## Tools Used
- MySQL
- MySQL Workbench

## Dataset Overview
- Original Records: 5,000
- Final Records: 4,891
- Columns: 15

## Data Cleaning Performed
- Identified and removed 100 duplicate records.
- Investigated NULL, empty, and whitespace values.
- Standardized inconsistent categorical values.
- Cleaned and converted multiple date formats using `STR_TO_DATE()`.
- Identified and handled invalid numerical values.
- Corrected data types.


## Final Validation
- Total records: 4,891
- Unique booking IDs: 4,891
- NULL booking IDs: 0
- Duplicate booking IDs: 0

## Repository Contents
- `hotel_booking_data_cleaning.sql` – Complete SQL cleaning script.
