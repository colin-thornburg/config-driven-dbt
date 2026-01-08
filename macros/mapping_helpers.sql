{# 
    Helper macros for the config-driven client mapping system.
    These macros assist with building dynamic SQL from mapping configurations.
#}

{% macro build_select_from_mapping(field_mappings, target_fields) %}
    {#
        Builds a SELECT clause from field mappings.
        
        Args:
            field_mappings: dict of target_field -> source_expression
            target_fields: list of target field names in desired order
            
        Returns:
            Comma-separated SELECT expressions
    #}
    {% set select_parts = [] %}
    
    {% for field in target_fields %}
        {% if field in field_mappings %}
            {% do select_parts.append(field_mappings[field] ~ ' AS ' ~ field) %}
        {% else %}
            {% do select_parts.append('NULL AS ' ~ field) %}
        {% endif %}
    {% endfor %}
    
    {{ return(select_parts | join(',\n        ')) }}
{% endmacro %}


{% macro get_target_fields(target_model) %}
    {#
        Returns the list of fields for a target model.
        This defines the schema contract that all clients must map to.
    #}
    
    {% if target_model == 'dim_candidate' %}
        {{ return([
            'candidate_id',
            'full_name', 
            'email',
            'phone_number',
            'hire_date',
            'hourly_rate',
            'client_code'
        ]) }}
    {% elif target_model == 'dim_placement' %}
        {{ return([
            'placement_id',
            'candidate_id',
            'position_title',
            'start_date',
            'end_date',
            'client_code'
        ]) }}
    {% else %}
        {{ exceptions.raise_compiler_error("Unknown target model: " ~ target_model) }}
    {% endif %}
{% endmacro %}


{% macro generate_client_staging_sql(client_config) %}
    {#
        Generates a complete SELECT statement for a single client.
        
        Args:
            client_config: dict containing client_code, source_table, field_mappings
            
        Returns:
            Complete SELECT statement string
    #}
    
    {% set target_fields = get_target_fields(client_config.target_model) %}
    {% set select_clause = build_select_from_mapping(client_config.field_mappings, target_fields) %}
    
    SELECT
        {{ select_clause }},
        CURRENT_TIMESTAMP() AS _loaded_at,
        '{{ client_config.client_code }}' AS _source_client
    FROM {{ ref(client_config.source_table) }}
{% endmacro %}


{% macro log_client_mapping(client_config) %}
    {#
        Logs client mapping details for debugging during dbt compile/run.
    #}
    {{ log("Processing client mapping: " ~ client_config.client_code ~ " -> " ~ client_config.target_model, info=true) }}
    {{ log("  Source table: " ~ client_config.source_table, info=true) }}
    {{ log("  Fields mapped: " ~ client_config.field_mappings.keys() | list | join(', '), info=true) }}
{% endmacro %}
