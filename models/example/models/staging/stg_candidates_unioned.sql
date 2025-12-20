{{
    config(
        materialized='view',
        tags=['staging', 'config_driven']
    )
}}

{#
    Staging model: stg_candidates_unioned
    
    This model dynamically unions all client candidate data based on 
    configurations defined in the client mapping YAML files.
    
    When a new client is onboarded via the Client Mapping Portal:
    1. A new YAML file is created in models/staging/client_mappings/
    2. The macro get_client_mappings() reads the configuration
    3. This model automatically includes the new client in the UNION
    
    No manual SQL changes required for new client onboarding!
#}

{% set client_mappings = get_client_mappings('dim_candidate') %}

{% if client_mappings | length == 0 %}
    {{ exceptions.raise_compiler_error("No client mappings found for dim_candidate. Please add at least one client mapping.") }}
{% endif %}

{% for client in client_mappings %}

    {# Log the client being processed #}
    {{ log_client_mapping(client) }}

    SELECT
        -- Target dimension fields
        {{ client.field_mappings.candidate_id }} AS candidate_id,
        {{ client.field_mappings.full_name }} AS full_name,
        {{ client.field_mappings.email }} AS email,
        {{ client.field_mappings.phone_number }} AS phone_number,
        {{ client.field_mappings.hire_date }} AS hire_date,
        {{ client.field_mappings.hourly_rate }} AS hourly_rate,
        {{ client.field_mappings.client_code }} AS client_code,
        
        -- Metadata fields
        CURRENT_TIMESTAMP() AS _loaded_at,
        '{{ client.client_code }}' AS _source_system,
        '{{ client.source_table }}' AS _source_table
        
    FROM {{ ref(client.source_table) }}

    {% if not loop.last %}
    UNION ALL
    {% endif %}

{% endfor %}
