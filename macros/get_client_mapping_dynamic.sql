{% macro get_client_mappings_dynamic(target_model='dim_candidate') %}
    {#
        DYNAMIC VERSION: Reads client configurations from the graph
        This uses dbt's metadata to discover all client mapping YAML files
        
        How it works:
        1. Each client_mappings/*.yml file defines client_config
        2. dbt parses these as part of the project metadata
        3. This macro uses graph.sources or vars to access them
        
        However, dbt doesn't natively expose arbitrary YAML files in the graph.
        So we use a hybrid approach with a config file.
    #}
    
    {% set ns = namespace(mappings=[]) %}
    
    {# Read from project variable if set #}
    {% if var('client_mappings', none) is not none %}
        {% set all_mappings = var('client_mappings') %}
    {% else %}
        {# Fallback: Use run_query to read from a metadata table or config #}
        {# For now, we'll use a simpler approach with sources #}
        
        {% set all_mappings = [] %}
        
        {# Alternative: Read from sources metadata #}
        {% for node in graph.sources.values() %}
            {% if node.schema == 'raw_clients' %}
                {# Auto-detect clients from available sources #}
                {{ log("Found source: " ~ node.name, info=true) }}
            {% endif %}
        {% endfor %}
    {% endif %}
    
    {# Filter by target model #}
    {% for mapping in all_mappings %}
        {% if mapping.target_model == target_model %}
            {% do ns.mappings.append(mapping) %}
        {% endif %}
    {% endfor %}
    
    {{ return(ns.mappings) }}
{% endmacro %}

