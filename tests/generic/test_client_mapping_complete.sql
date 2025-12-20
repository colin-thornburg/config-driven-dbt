{#
    Custom test: test_client_mapping_complete
    
    Validates that a client mapping has all required fields mapped.
    This test is run during CI to catch incomplete mappings before they
    reach production.
#}

{% test client_mapping_complete(model, client_code, required_fields) %}

WITH source_data AS (
    SELECT * FROM {{ model }}
    WHERE client_code = '{{ client_code }}'
),

null_checks AS (
    SELECT
        '{{ client_code }}' AS client_code,
        {% for field in required_fields %}
        SUM(CASE WHEN {{ field }} IS NULL THEN 1 ELSE 0 END) AS {{ field }}_nulls{% if not loop.last %},{% endif %}
        {% endfor %}
    FROM source_data
),

validation AS (
    SELECT
        client_code,
        {% for field in required_fields %}
        {{ field }}_nulls{% if not loop.last %} + {% endif %}
        {% endfor %} AS total_null_count
    FROM null_checks
)

SELECT *
FROM validation
WHERE total_null_count > 0

{% endtest %}
