-- Test: assert_all_clients_have_candidates
-- 
-- This test verifies that every configured client mapping has at least one
-- candidate record. A client with zero records likely indicates a mapping
-- or source data issue.

WITH client_counts AS (
    SELECT 
        client_code,
        COUNT(*) AS candidate_count
    FROM {{ ref('stg_candidates_unioned') }}
    GROUP BY client_code
),

-- Get all configured clients from the mapping macro
expected_clients AS (
    SELECT 'ACME' AS client_code
    UNION ALL SELECT 'GLOBEX'
    UNION ALL SELECT 'WAYNE'
),

-- Find clients with missing or zero records
missing_data AS (
    SELECT 
        e.client_code,
        COALESCE(c.candidate_count, 0) AS candidate_count
    FROM expected_clients e
    LEFT JOIN client_counts c ON e.client_code = c.client_code
    WHERE COALESCE(c.candidate_count, 0) = 0
)

SELECT * FROM missing_data
