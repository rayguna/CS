/*I. Create tables*/
--1. GDP
CREATE TABLE economic_data.GDP(
	country_name varchar(100),
	country_code varchar(3),
	years integer,
	gdp_value float(24)
);
--2. CPI
CREATE TABLE economic_data.CPI(
	country_name varchar(100),
	country_code varchar(3),
	years integer,
	cpi_value float(24)
);
--3. Inflation
CREATE TABLE economic_data.Inflation(
	country_name varchar(100),
	country_code varchar(3),
	years integer,
	inflation_value float(24)
);
--4. Population
CREATE TABLE economic_data.Population(
	country_name varchar(100),
	country_code varchar(3),
	years integer,
	population_value float(24)
);
--5. Cash Surplus Deficit
CREATE TABLE economic_data.Cash_Surplus_Deficit(
	country_name varchar(100),
	country_code varchar(3),
	years integer,
	cash_surplus_deficit_value float(24)
);

--II. populate tables with data from csv files
/*To overcome permission denied error:
Right click on the file or folder containing the csv files -> Properties. 
Go to Security tab -> Edit  -> Add. Type 'Everyone'
(without apostrophe) inside the box an click Apply.

--NOTE: You will need to specify the absolute path to the csv file on your computer to be found by postgresql.
*/
--1. GDP
COPY economic_data.GDP
FROM 'gdp_csv.csv' 
DELIMITER ',' 
CSV HEADER;

--2. CPI
COPY economic_data.CPI
FROM 'cpi_csv.csv' 
DELIMITER ',' 
CSV HEADER;

--3. Inflation
COPY economic_data.inflation
FROM 'inflation-gdp_csv.csv' 
DELIMITER ',' 
CSV HEADER;

--4. Population
COPY economic_data.population
FROM 'population_csv.csv' 
DELIMITER ',' 
CSV HEADER;

--5.
COPY economic_data.cash_surplus_deficit
FROM 'cash-surp-def_csv.csv' 
DELIMITER ',' 
CSV HEADER;

/*
III. Create a parent table and create a one to many relations with the rest of the tables 
*/
--A. get DISTINCT country_code and country_name from all tables and create a new table called countries
CREATE TABLE economic_data.countries AS (
	SELECT DISTINCT country_code, country_name FROM economic_data.GDP
	WHERE country_code IS NOT NULL
	UNION DISTINCT
	SELECT DISTINCT country_code, country_name FROM economic_data.CPI
	WHERE country_code IS NOT NULL
	UNION DISTINCT
	SELECT DISTINCT country_code, country_name FROM economic_data.inflation
	WHERE country_code IS NOT NULL
	UNION DISTINCT
	SELECT DISTINCT country_code, country_name FROM economic_data.population
	WHERE country_code IS NOT NULL
	UNION DISTINCT
	SELECT DISTINCT country_code, country_name FROM economic_data.cash_surplus_deficit
	WHERE country_code IS NOT NULL
);

--Make country name the primary key to maintain its uniqueness
--I found that the country_code is not unique, but the country_name is.

SELECT * 
FROM economic_data.countries
WHERE country_name='Kosovo';

--delete duplicated country_name
DELETE FROM economic_data.countries 
WHERE country_code='XKX';

--Make sure than the country_name columns is unique and turn it into a primary key column
ALTER TABLE economic_data.countries
ADD UNIQUE (country_name);

ALTER TABLE economic_data.countries
ADD PRIMARY KEY (country_name);

--B. Relate countries table to the rest of the table via a foreign key
ALTER TABLE economic_data.GDP
ADD FOREIGN KEY (country_name)
REFERENCES economic_data.countries(country_name);
 
ALTER TABLE economic_data.CPI
ADD FOREIGN KEY (country_name)
REFERENCES economic_data.countries(country_name);

ALTER TABLE economic_data.inflation
ADD FOREIGN KEY (country_name)
REFERENCES economic_data.countries(country_name);

ALTER TABLE economic_data.population
ADD FOREIGN KEY (country_name)
REFERENCES economic_data.countries(country_name);

ALTER TABLE economic_data.cash_surplus_deficit
ADD FOREIGN KEY (country_name)
REFERENCES economic_data.countries(country_name);

/*
--Get the minimum year
--C. Check the time it takes for sql to get minimum years from all columns
	 without indexing
*/
	 
EXPLAIN ANALYZE
WITH temporary_column AS(
SELECT MAX(years) AS years
FROM economic_data.GDP
UNION
SELECT MAX(years) AS years
FROM economic_data.CPI
UNION
SELECT MAX(years) AS years
FROM economic_data.inflation
UNION
SELECT MAX(years) AS years
FROM economic_data.population
UNION
SELECT MAX(years) AS years
FROM economic_data.cash_surplus_deficit
)

SELECT MIN(years)
FROM temporary_column;

--The data of the most recent year that is available from all tables is 2014.


/*
--D. Indexing the years on each table did not seem to improve the query time.
I also noticed that the query times varied each time the query is executed.

Note that the insertion operation of an indexed table is slow. Also,
improperly indexed table can slow down SELECT queries.
*/

CREATE INDEX years_idx ON economic_data.GDP(years);
CREATE INDEX years_idx ON economic_data.CPI(years);
CREATE INDEX years_idx ON economic_data.inflation(years);
CREATE INDEX years_idx ON economic_data.population(years);
CREATE INDEX years_idx ON economic_data.cash_surplus_deficit(years);

EXPLAIN ANALYZE
WITH temporary_column AS(
SELECT MAX(years) AS years
FROM economic_data.GDP
UNION
SELECT MAX(years) AS years
FROM economic_data.CPI
UNION
SELECT MAX(years) AS years
FROM economic_data.inflation
UNION
SELECT MAX(years) AS years
FROM economic_data.population
UNION
SELECT MAX(years) AS years
FROM economic_data.cash_surplus_deficit
)

SELECT MIN(years)
FROM temporary_column;


--IV. Create a minimal role called world_data_user
CREATE ROLE world_data_user WITH NOSUPERUSER LOGIN;
--this line is required
GRANT USAGE ON SCHEMA economic_data TO world_data_user;
GRANT SELECT ON ALL TABLES IN SCHEMA economic_data TO world_data_user;

--check privileges
SELECT grantee, table_name, privilege_type
FROM information_schema.table_privileges
WHERE grantee='world_data_user';


/*
V. Analyze Tables
--get all data for all years for a certain country.
--filter certain data range by specifying year range.
*/

--Test
SET role world_data_user;

/*
--To optionally change role back to postgres
--SET ROLE postgres;
*/

--A. join countries table with the rest of the tables for the most recent year that is available: 2014 

--EXPLAIN ANALYZE
SELECT economic_data.countries.country_code, 
		economic_data.countries.country_name,
		economic_data.GDP.gdp_value, 
		economic_data.inflation.inflation_value,
		economic_data.population.population_value,
		economic_data.cash_surplus_deficit.cash_surplus_deficit_value
		
FROM economic_data.countries
	JOIN economic_data.GDP
	ON economic_data.countries.country_name=economic_data.GDP.country_name
	JOIN economic_data.CPI
	ON economic_data.countries.country_name=economic_data.CPI.country_name
	JOIN economic_data.inflation
	ON economic_data.countries.country_name=economic_data.inflation.country_name
	JOIN economic_data.population
	ON economic_data.countries.country_name=economic_data.population.country_name
	JOIN economic_data.cash_surplus_deficit
	ON economic_data.countries.country_name=economic_data.cash_surplus_deficit.country_name
WHERE economic_data.GDP.years=2014 
	AND economic_data.CPI.years=2014
	AND economic_data.inflation.years=2014
	AND economic_data.population.years=2014
	AND economic_data.cash_surplus_deficit.years=2014
ORDER BY economic_data.countries.country_code ASC
LIMIT 5;


--B. Join all tables by year for a specific country

--First, know the right keywords
SELECT *
FROM economic_data.GDP
WHERE economic_data.GDP.country_name LIKE '%States%'
LIMIT 5;

--Select economic data for United states over time
SELECT economic_data.GDP.country_code, 
		economic_data.GDP.country_name,
		economic_data.GDP.years,
		economic_data.GDP.gdp_value, 
		economic_data.inflation.inflation_value,
		economic_data.population.population_value,
		economic_data.cash_surplus_deficit.cash_surplus_deficit_value

FROM economic_data.GDP
	JOIN economic_data.CPI
	ON economic_data.GDP.years=economic_data.CPI.years
	JOIN economic_data.inflation
	ON economic_data.GDP.years=economic_data.inflation.years
	JOIN economic_data.population
	ON economic_data.GDP.years=economic_data.population.years
	JOIN economic_data.cash_surplus_deficit
	ON economic_data.GDP.years=economic_data.cash_surplus_deficit.years
WHERE economic_data.GDP.country_name='United States'
	AND economic_data.CPI.country_name='United States'
	AND economic_data.inflation.country_name='United States'
	AND economic_data.population.country_name='United States'
	AND economic_data.cash_surplus_deficit.country_name='United States'
	
ORDER BY economic_data.GDP.years DESC
LIMIT 15;

--VI. Get sizes
/*SELECT pg_size_pretty(pg_table_size('economic_data')) AS tbl_size, 
pg_size_pretty(pg_indexes_size('economic_data')) AS idx_size, 
pg_size_pretty(pg_total_relation_size('economic_data')) AS total_size;
*/

SELECT pg_size_pretty(pg_relation_size('economic_data.countries'))
UNION
SELECT pg_size_pretty(pg_relation_size('economic_data.GDP'))
UNION
SELECT pg_size_pretty(pg_relation_size('economic_data.CPI'))
UNION
SELECT pg_size_pretty(pg_relation_size('economic_data.inflation'))
UNION
SELECT pg_size_pretty(pg_relation_size('economic_data.population'))
UNION
SELECT pg_size_pretty(pg_relation_size('economic_data.cash_surplus_deficit'));

--clean cache by restarting when you see postgresql acting weird
