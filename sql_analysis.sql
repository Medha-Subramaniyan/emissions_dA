-- Comprehensive SQL Analysis for CO₂ Emissions Data
-- This file contains equivalent SQL queries for all Python analysis tasks

-- ==============================================
-- DATA SETUP AND PREPARATION
-- ==============================================

-- Create tables (if not exists)
CREATE TABLE IF NOT EXISTS emissions (
    entity VARCHAR(255),
    code VARCHAR(10),
    year INT,
    annual_co2_emissions DECIMAL(15,2)
);

CREATE TABLE IF NOT EXISTS continents (
    entity VARCHAR(255),
    code VARCHAR(10),
    year INT,
    world_region VARCHAR(255)
);

-- Load data (assuming CSV files are loaded)
-- Note: Actual loading depends on your SQL environment

-- ==============================================
-- GROUPBY ANALYSIS TASKS
-- ==============================================

-- Task 1: Total CO₂ emissions per continent per year
SELECT 
    c.world_region AS continent,
    e.year,
    SUM(e.annual_co2_emissions) AS total_emissions
FROM emissions e
JOIN continents c ON e.code = c.code
GROUP BY c.world_region, e.year
ORDER BY c.world_region, e.year;

-- Task 2: Top 3 entities by average annual emissions within each continent
WITH avg_emissions AS (
    SELECT 
        c.world_region AS continent,
        e.entity,
        AVG(e.annual_co2_emissions) AS avg_annual_emissions
    FROM emissions e
    JOIN continents c ON e.code = c.code
    GROUP BY c.world_region, e.entity
),
ranked_entities AS (
    SELECT 
        continent,
        entity,
        avg_annual_emissions,
        ROW_NUMBER() OVER (PARTITION BY continent ORDER BY avg_annual_emissions DESC) AS rank
    FROM avg_emissions
)
SELECT 
    continent,
    entity,
    avg_annual_emissions,
    rank
FROM ranked_entities
WHERE rank <= 3
ORDER BY continent, rank;

-- Task 3: Percentage share of emissions for year 2000
WITH continent_totals_2000 AS (
    SELECT 
        c.world_region AS continent,
        SUM(e.annual_co2_emissions) AS total_emissions
    FROM emissions e
    JOIN continents c ON e.code = c.code
    WHERE e.year = 2000
    GROUP BY c.world_region
),
top_entities_2000 AS (
    SELECT 
        c.world_region AS continent,
        e.entity,
        e.annual_co2_emissions,
        ROW_NUMBER() OVER (PARTITION BY c.world_region ORDER BY e.annual_co2_emissions DESC) AS rank
    FROM emissions e
    JOIN continents c ON e.code = c.code
    WHERE e.year = 2000
)
SELECT 
    te.continent,
    te.entity AS top_entity,
    te.annual_co2_emissions AS top_entity_emissions,
    ct.total_emissions AS total_continent_emissions,
    ROUND((te.annual_co2_emissions / ct.total_emissions) * 100, 2) AS top_entity_share_pct,
    ROUND(100 - (te.annual_co2_emissions / ct.total_emissions) * 100, 2) AS rest_share_pct
FROM top_entities_2000 te
JOIN continent_totals_2000 ct ON te.continent = ct.continent
WHERE te.rank = 1
ORDER BY te.continent;

-- Task 4: First and last year analysis per continent
WITH year_analysis AS (
    SELECT 
        c.world_region AS continent,
        MIN(e.year) AS first_year,
        MAX(e.year) AS last_year,
        MAX(e.year) - MIN(e.year) AS year_span
    FROM emissions e
    JOIN continents c ON e.code = c.code
    GROUP BY c.world_region
),
first_year_emissions AS (
    SELECT 
        c.world_region AS continent,
        SUM(e.annual_co2_emissions) AS first_year_total_emissions
    FROM emissions e
    JOIN continents c ON e.code = c.code
    JOIN year_analysis ya ON c.world_region = ya.continent
    WHERE e.year = ya.first_year
    GROUP BY c.world_region
),
last_year_emissions AS (
    SELECT 
        c.world_region AS continent,
        SUM(e.annual_co2_emissions) AS last_year_total_emissions
    FROM emissions e
    JOIN continents c ON e.code = c.code
    JOIN year_analysis ya ON c.world_region = ya.continent
    WHERE e.year = ya.last_year
    GROUP BY c.world_region
)
SELECT 
    ya.continent,
    ya.first_year,
    ya.last_year,
    ya.year_span,
    fye.first_year_total_emissions,
    lye.last_year_total_emissions,
    lye.last_year_total_emissions - fye.first_year_total_emissions AS emission_growth,
    ROUND(((lye.last_year_total_emissions - fye.first_year_total_emissions) / fye.first_year_total_emissions) * 100, 2) AS emission_growth_pct
FROM year_analysis ya
JOIN first_year_emissions fye ON ya.continent = fye.continent
JOIN last_year_emissions lye ON ya.continent = lye.continent
ORDER BY ya.continent;

-- Task 5: Decade analysis
WITH decade_data AS (
    SELECT 
        c.world_region AS continent,
        e.year,
        FLOOR(e.year / 10) * 10 AS decade,
        e.annual_co2_emissions
    FROM emissions e
    JOIN continents c ON e.code = c.code
)
SELECT 
    continent,
    decade,
    AVG(annual_co2_emissions) AS mean_emissions,
    MIN(annual_co2_emissions) AS min_emissions,
    MAX(annual_co2_emissions) AS max_emissions,
    SUM(annual_co2_emissions) AS total_emissions
FROM decade_data
GROUP BY continent, decade
ORDER BY continent, decade;

-- ==============================================
-- CUSTOM APPLY EQUIVALENTS
-- ==============================================

-- Task 6: Growth rate calculation (using window functions)
WITH ordered_emissions AS (
    SELECT 
        c.world_region AS continent,
        e.entity,
        e.year,
        e.annual_co2_emissions,
        LAG(e.annual_co2_emissions) OVER (PARTITION BY e.entity ORDER BY e.year) AS prev_year_emissions
    FROM emissions e
    JOIN continents c ON e.code = c.code
)
SELECT 
    continent,
    entity,
    year,
    annual_co2_emissions,
    prev_year_emissions,
    CASE 
        WHEN prev_year_emissions IS NOT NULL AND prev_year_emissions > 0 
        THEN ROUND(((annual_co2_emissions - prev_year_emissions) / prev_year_emissions) * 100, 2)
        ELSE NULL 
    END AS growth_rate
FROM ordered_emissions
WHERE entity IN ('United States', 'China', 'India', 'Germany', 'Japan')
ORDER BY entity, year;

-- Task 7: Largest single-year emission spike per continent
WITH growth_rates AS (
    SELECT 
        c.world_region AS continent,
        e.entity,
        e.year,
        e.annual_co2_emissions,
        LAG(e.annual_co2_emissions) OVER (PARTITION BY e.entity ORDER BY e.year) AS prev_year_emissions
    FROM emissions e
    JOIN continents c ON e.code = c.code
),
growth_calculated AS (
    SELECT 
        continent,
        entity,
        year,
        annual_co2_emissions,
        CASE 
            WHEN prev_year_emissions IS NOT NULL AND prev_year_emissions > 0 
            THEN ((annual_co2_emissions - prev_year_emissions) / prev_year_emissions) * 100
            ELSE NULL 
        END AS growth_rate
    FROM growth_rates
),
max_growth_per_continent AS (
    SELECT 
        continent,
        MAX(growth_rate) AS max_growth_rate
    FROM growth_calculated
    WHERE growth_rate IS NOT NULL
    GROUP BY continent
)
SELECT 
    gc.continent,
    gc.entity,
    gc.year,
    gc.annual_co2_emissions,
    ROUND(gc.growth_rate, 2) AS growth_rate
FROM growth_calculated gc
JOIN max_growth_per_continent mg ON gc.continent = mg.continent AND gc.growth_rate = mg.max_growth_rate
ORDER BY gc.continent;

-- Task 8: Rolling 5-year average (using window functions)
WITH rolling_data AS (
    SELECT 
        c.world_region AS continent,
        e.entity,
        e.year,
        e.annual_co2_emissions,
        AVG(e.annual_co2_emissions) OVER (
            PARTITION BY e.entity 
            ORDER BY e.year 
            ROWS BETWEEN 4 PRECEDING AND CURRENT ROW
        ) AS rolling_5yr_avg
    FROM emissions e
    JOIN continents c ON e.code = c.code
)
SELECT 
    continent,
    entity,
    year,
    annual_co2_emissions,
    ROUND(rolling_5yr_avg, 2) AS rolling_5yr_avg
FROM rolling_data
WHERE entity IN ('United States', 'China', 'Germany')
ORDER BY entity, year;

-- Task 9: Above/below median flag
WITH entity_medians AS (
    SELECT 
        c.world_region AS continent,
        e.entity,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY e.annual_co2_emissions) AS median_emissions
    FROM emissions e
    JOIN continents c ON e.code = c.code
    GROUP BY c.world_region, e.entity
)
SELECT 
    c.world_region AS continent,
    e.entity,
    e.year,
    e.annual_co2_emissions,
    em.median_emissions,
    CASE 
        WHEN e.annual_co2_emissions > em.median_emissions THEN TRUE 
        ELSE FALSE 
    END AS above_median
FROM emissions e
JOIN continents c ON e.code = c.code
JOIN entity_medians em ON c.world_region = em.continent AND e.entity = em.entity
WHERE e.entity = 'United States'
ORDER BY e.year;

-- Task 10: Summary statistics per continent
SELECT 
    c.world_region AS continent,
    MIN(e.annual_co2_emissions) AS min_emissions,
    MAX(e.annual_co2_emissions) AS max_emissions,
    MAX(e.annual_co2_emissions) - MIN(e.annual_co2_emissions) AS range_emissions,
    ROUND(STDDEV(e.annual_co2_emissions), 2) AS std_emissions,
    ROUND(AVG(e.annual_co2_emissions), 2) AS mean_emissions,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY e.annual_co2_emissions), 2) AS median_emissions,
    COUNT(DISTINCT e.entity) AS total_entities,
    COUNT(DISTINCT e.year) AS total_years
FROM emissions e
JOIN continents c ON e.code = c.code
GROUP BY c.world_region
ORDER BY c.world_region;

-- ==============================================
-- MELT & PIVOT EQUIVALENTS
-- ==============================================

-- Task 11: Wide format (years as columns) - This would typically be done with PIVOT
-- Note: PIVOT syntax varies by SQL dialect. Here's a PostgreSQL example using crosstab
-- For other databases, you might need to use CASE statements or specific PIVOT syntax

-- Example for PostgreSQL with crosstab extension:
/*
SELECT * FROM crosstab(
    'SELECT entity, year, annual_co2_emissions FROM emissions ORDER BY entity, year',
    'SELECT DISTINCT year FROM emissions ORDER BY year'
) AS ct(entity VARCHAR, year_1949 DECIMAL, year_1950 DECIMAL, ...);
*/

-- Alternative using CASE statements (works in most SQL databases)
WITH year_columns AS (
    SELECT 
        entity,
        MAX(CASE WHEN year = 1949 THEN annual_co2_emissions END) AS year_1949,
        MAX(CASE WHEN year = 1950 THEN annual_co2_emissions END) AS year_1950,
        MAX(CASE WHEN year = 1951 THEN annual_co2_emissions END) AS year_1951,
        MAX(CASE WHEN year = 1952 THEN annual_co2_emissions END) AS year_1952,
        MAX(CASE WHEN year = 1953 THEN annual_co2_emissions END) AS year_1953
        -- Add more years as needed
    FROM emissions
    GROUP BY entity
)
SELECT * FROM year_columns
WHERE entity IN ('United States', 'China', 'India')
ORDER BY entity;

-- Task 12: Melt back to long format (reverse of above)
-- This would involve UNPIVOT or UNION ALL with CASE statements
-- Example using UNION ALL:
WITH wide_data AS (
    SELECT entity, year_1949 AS emissions, 1949 AS year FROM year_columns WHERE year_1949 IS NOT NULL
    UNION ALL
    SELECT entity, year_1950 AS emissions, 1950 AS year FROM year_columns WHERE year_1950 IS NOT NULL
    UNION ALL
    SELECT entity, year_1951 AS emissions, 1951 AS year FROM year_columns WHERE year_1951 IS NOT NULL
    UNION ALL
    SELECT entity, year_1952 AS emissions, 1952 AS year FROM year_columns WHERE year_1952 IS NOT NULL
    UNION ALL
    SELECT entity, year_1953 AS emissions, 1953 AS year FROM year_columns WHERE year_1953 IS NOT NULL
)
SELECT entity, year, emissions FROM wide_data
ORDER BY entity, year;

-- Task 13: Continent × Year matrix
SELECT 
    c.world_region AS continent,
    SUM(CASE WHEN e.year = 1949 THEN e.annual_co2_emissions ELSE 0 END) AS year_1949,
    SUM(CASE WHEN e.year = 1950 THEN e.annual_co2_emissions ELSE 0 END) AS year_1950,
    SUM(CASE WHEN e.year = 1951 THEN e.annual_co2_emissions ELSE 0 END) AS year_1951,
    SUM(CASE WHEN e.year = 1952 THEN e.annual_co2_emissions ELSE 0 END) AS year_1952,
    SUM(CASE WHEN e.year = 1953 THEN e.annual_co2_emissions ELSE 0 END) AS year_1953
    -- Add more years as needed
FROM emissions e
JOIN continents c ON e.code = c.code
GROUP BY c.world_region
ORDER BY c.world_region;

-- Task 14: Average emissions per continent per decade
WITH decade_data AS (
    SELECT 
        c.world_region AS continent,
        FLOOR(e.year / 10) * 10 AS decade,
        e.annual_co2_emissions
    FROM emissions e
    JOIN continents c ON e.code = c.code
)
SELECT 
    continent,
    decade,
    ROUND(AVG(annual_co2_emissions), 2) AS avg_emissions
FROM decade_data
GROUP BY continent, decade
ORDER BY continent, decade;

-- Task 15: Entities × Continents matrix
SELECT 
    e.entity,
    SUM(CASE WHEN c.world_region = 'Africa' THEN e.annual_co2_emissions ELSE 0 END) AS Africa,
    SUM(CASE WHEN c.world_region = 'Asia' THEN e.annual_co2_emissions ELSE 0 END) AS Asia,
    SUM(CASE WHEN c.world_region = 'Europe' THEN e.annual_co2_emissions ELSE 0 END) AS Europe,
    SUM(CASE WHEN c.world_region = 'North America' THEN e.annual_co2_emissions ELSE 0 END) AS North_America,
    SUM(CASE WHEN c.world_region = 'South America' THEN e.annual_co2_emissions ELSE 0 END) AS South_America,
    SUM(CASE WHEN c.world_region = 'Oceania' THEN e.annual_co2_emissions ELSE 0 END) AS Oceania
FROM emissions e
JOIN continents c ON e.code = c.code
GROUP BY e.entity
ORDER BY e.entity;

-- ==============================================
-- ADDITIONAL ANALYTICAL QUERIES
-- ==============================================

-- Top 10 countries by total emissions (all time)
SELECT 
    c.world_region AS continent,
    e.entity,
    SUM(e.annual_co2_emissions) AS total_emissions,
    AVG(e.annual_co2_emissions) AS avg_annual_emissions,
    COUNT(DISTINCT e.year) AS years_reported
FROM emissions e
JOIN continents c ON e.code = c.code
GROUP BY c.world_region, e.entity
ORDER BY total_emissions DESC
LIMIT 10;

-- Countries with highest emission growth rates
WITH growth_rates AS (
    SELECT 
        c.world_region AS continent,
        e.entity,
        e.year,
        e.annual_co2_emissions,
        LAG(e.annual_co2_emissions) OVER (PARTITION BY e.entity ORDER BY e.year) AS prev_year_emissions
    FROM emissions e
    JOIN continents c ON e.code = c.code
),
growth_calculated AS (
    SELECT 
        continent,
        entity,
        year,
        annual_co2_emissions,
        CASE 
            WHEN prev_year_emissions IS NOT NULL AND prev_year_emissions > 0 
            THEN ((annual_co2_emissions - prev_year_emissions) / prev_year_emissions) * 100
            ELSE NULL 
        END AS growth_rate
    FROM growth_rates
)
SELECT 
    continent,
    entity,
    year,
    annual_co2_emissions,
    ROUND(growth_rate, 2) AS growth_rate
FROM growth_calculated
WHERE growth_rate IS NOT NULL
ORDER BY growth_rate DESC
LIMIT 20;

-- Emission trends by decade
WITH decade_trends AS (
    SELECT 
        c.world_region AS continent,
        FLOOR(e.year / 10) * 10 AS decade,
        SUM(e.annual_co2_emissions) AS total_emissions,
        AVG(e.annual_co2_emissions) AS avg_emissions,
        COUNT(DISTINCT e.entity) AS countries_count
    FROM emissions e
    JOIN continents c ON e.code = c.code
    GROUP BY c.world_region, FLOOR(e.year / 10) * 10
)
SELECT 
    continent,
    decade,
    total_emissions,
    ROUND(avg_emissions, 2) AS avg_emissions,
    countries_count
FROM decade_trends
ORDER BY continent, decade;

-- Countries with most consistent emission reporting
SELECT 
    c.world_region AS continent,
    e.entity,
    COUNT(DISTINCT e.year) AS years_reported,
    MIN(e.year) AS first_year,
    MAX(e.year) AS last_year,
    MAX(e.year) - MIN(e.year) + 1 AS expected_years,
    ROUND(COUNT(DISTINCT e.year) * 100.0 / (MAX(e.year) - MIN(e.year) + 1), 2) AS reporting_completeness_pct
FROM emissions e
JOIN continents c ON e.code = c.code
GROUP BY c.world_region, e.entity
HAVING COUNT(DISTINCT e.year) >= 50  -- At least 50 years of data
ORDER BY reporting_completeness_pct DESC, years_reported DESC
LIMIT 20;
