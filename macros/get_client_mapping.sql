{% macro get_client_mappings(target_model=none) %}
    {#
        Reads client mapping configurations from dbt project variables.
        This is FULLY DYNAMIC - no code changes needed when adding new clients!
        
        Configurations are stored in dbt_project.yml under vars.client_mappings
        The Client Mapping Portal automatically updates this file.
        
        Optionally filter by target_model (e.g., 'dim_candidate')
        
        Usage:
            {% set clients = get_client_mappings('dim_candidate') %}
            {% for client in clients %}
                -- Process {{ client.client_code }}
            {% endfor %}
    #}
    
    {% set all_mappings = var('client_mappings', []) %},
        {
            'client_code': 'ACME_3',
            'client_name': 'ACME_3',
            'source_table': 'employee_feed',
            'target_model': 'dim_candidate',
            'field_mappings': {
                'candidate_id': "emp_id",
                'email': "email_address",
                'phone_number': "mobile",
                'hire_date': "start_dt",
                'hourly_rate': "rate_per_hour",
                'full_name': "CONCAT(fname, ' ', lname)",
                'client_code': ''ACME_3''
            }
        }
    {% set filtered_mappings = [] %}
    
    {# Filter by target_model if specified #}
    {% for mapping in all_mappings %}
        {% if target_model is none or mapping.target_model == target_model %}
            {% do filtered_mappings.append(mapping) %}
        {% endif %}
    {% endfor %}
    
    {# Log what we found for debugging #}
    {{ log("Found " ~ filtered_mappings|length ~ " client mapping(s) for target_model: " ~ target_model, info=true) }}
    
    {{ return(filtered_mappings) }}
{% endmacro %}
