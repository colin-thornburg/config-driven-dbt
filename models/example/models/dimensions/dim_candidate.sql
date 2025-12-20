{{
    config(
        materialized='table',
        tags=['dimension', 'candidate']
    )
}}

{#
    Dimension model: dim_candidate
    
    This is the final, production-ready candidate dimension that combines
    all client candidate data into a single, standardized table.
    
    Source: stg_candidates_unioned (config-driven staging model)
#}

WITH staged_candidates AS (
    SELECT * FROM {{ ref('stg_candidates_unioned') }}
),

-- Add any additional transformations, deduplication, or enrichment here
final AS (
    SELECT
        -- Generate a surrogate key combining client and source ID
        {{ dbt_utils.generate_surrogate_key(['client_code', 'candidate_id']) }} AS candidate_key,
        
        -- Natural key from source
        candidate_id,
        
        -- Core attributes
        full_name,
        email,
        phone_number,
        hire_date,
        hourly_rate,
        client_code,
        
        -- Derived fields
        EXTRACT(YEAR FROM hire_date) AS hire_year,
        EXTRACT(MONTH FROM hire_date) AS hire_month,
        DATEDIFF('day', hire_date, CURRENT_DATE()) AS tenure_days,
        
        -- Rate classification
        CASE 
            WHEN hourly_rate >= 100 THEN 'Executive'
            WHEN hourly_rate >= 60 THEN 'Senior'
            WHEN hourly_rate >= 40 THEN 'Mid-Level'
            ELSE 'Entry'
        END AS rate_tier,
        
        -- Metadata
        _loaded_at,
        _source_system,
        _source_table,
        CURRENT_TIMESTAMP() AS _dim_updated_at
        
    FROM staged_candidates
)

SELECT * FROM final
