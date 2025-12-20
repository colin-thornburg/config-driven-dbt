-- Test: assert_no_duplicate_candidates_per_client
--
-- Validates that within each client, candidate_id values are unique.
-- Duplicates could indicate issues with the source data or mapping.

WITH duplicates AS (
    SELECT 
        client_code,
        candidate_id,
        COUNT(*) AS occurrence_count
    FROM {{ ref('stg_candidates_unioned') }}
    GROUP BY client_code, candidate_id
    HAVING COUNT(*) > 1
)

SELECT * FROM duplicates
