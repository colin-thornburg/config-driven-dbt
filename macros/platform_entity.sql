{#
    ════════════════════════════════════════════════════════════════════════════
    PLATFORM ENTITY MACROS
    ════════════════════════════════════════════════════════════════════════════
    
    These macros provide a "platform layer" that automatically:
    1. Injects control fields based on entity type
    2. Adds metadata for CDC and incremental processing
    3. Provides standard patterns for dimensions, facts, and bridges
    
    USAGE:
    In your dbt model, simply call the wrapper macro:
    
        {{ platform_entity(
            entity_type='dimension',
            primary_key='customer_id',
            source_cdc_column='updated_at'
        ) }}
        
        SELECT
            customer_id,
            first_name,
            last_name,
            email
        FROM {{ ref('raw_customers') }}
        
        {{ platform_entity_end() }}
    
    The platform will automatically add:
    - _surrogate_key (for dimensions)
    - _valid_from, _valid_to, _is_current (for SCD Type 2)
    - _loaded_at, _source_system, _dbt_run_id (for all entities)
    - _transaction_time, _ingestion_time (for facts from CDC)
    
    ════════════════════════════════════════════════════════════════════════════
#}


{# ═══════════════════════════════════════════════════════════════════════════
   ENTITY TYPE DEFINITIONS
   ═══════════════════════════════════════════════════════════════════════════
   Each entity type has specific control fields that get auto-injected.
#}

{% macro get_entity_control_fields(entity_type, config={}) %}
    {#
        Returns the list of control fields for a given entity type.
        
        Args:
            entity_type: 'dimension', 'fact', 'bridge', 'snapshot', 'staging'
            config: dict with optional overrides (primary_key, source_cdc_column, etc.)
            
        Returns:
            List of SQL expressions for control fields
    #}
    
    {% set control_fields = [] %}
    
    {# Common fields for ALL entity types #}
    {% do control_fields.append("CURRENT_TIMESTAMP() AS _loaded_at") %}
    {% do control_fields.append("'" ~ this.schema ~ "' AS _source_schema") %}
    {% do control_fields.append("'" ~ this.name ~ "' AS _model_name") %}
    {% do control_fields.append("'" ~ invocation_id ~ "' AS _dbt_run_id") %}
    
    {% if entity_type == 'dimension' %}
        {# Dimension-specific: SCD Type 2 fields #}
        {% if config.primary_key %}
            {% do control_fields.append("MD5(CAST(" ~ config.primary_key ~ " AS VARCHAR)) AS _surrogate_key") %}
        {% endif %}
        {% if config.source_cdc_column %}
            {% do control_fields.append("CAST(" ~ config.source_cdc_column ~ " AS TIMESTAMP) AS _valid_from") %}
        {% else %}
            {% do control_fields.append("CURRENT_TIMESTAMP() AS _valid_from") %}
        {% endif %}
        {% do control_fields.append("CAST('9999-12-31' AS TIMESTAMP) AS _valid_to") %}
        {% do control_fields.append("TRUE AS _is_current") %}
        
    {% elif entity_type == 'fact' %}
        {# Fact-specific: CDC and transaction tracking #}
        {% if config.transaction_time_column %}
            {% do control_fields.append("CAST(" ~ config.transaction_time_column ~ " AS TIMESTAMP) AS _transaction_time") %}
        {% else %}
            {% do control_fields.append("CURRENT_TIMESTAMP() AS _transaction_time") %}
        {% endif %}
        {% if config.ingestion_time_column %}
            {% do control_fields.append("CAST(" ~ config.ingestion_time_column ~ " AS TIMESTAMP) AS _ingestion_time") %}
        {% else %}
            {% do control_fields.append("CURRENT_TIMESTAMP() AS _ingestion_time") %}
        {% endif %}
        {% do control_fields.append("'" ~ config.get('source_system', 'unknown') ~ "' AS _source_system") %}
        
    {% elif entity_type == 'bridge' %}
        {# Bridge-specific: relationship tracking #}
        {% do control_fields.append("CURRENT_TIMESTAMP() AS _relationship_created_at") %}
        {% do control_fields.append("TRUE AS _is_active") %}
        
    {% elif entity_type == 'snapshot' %}
        {# Snapshot-specific: point-in-time tracking #}
        {% do control_fields.append("CURRENT_DATE() AS _snapshot_date") %}
        {% do control_fields.append("'" ~ run_started_at ~ "' AS _snapshot_timestamp") %}
        
    {% elif entity_type == 'staging' %}
        {# Staging: minimal control fields #}
        {% do control_fields.append("'raw' AS _layer") %}
    {% endif %}
    
    {{ return(control_fields) }}
{% endmacro %}


{# ═══════════════════════════════════════════════════════════════════════════
   PLATFORM ENTITY WRAPPER
   ═══════════════════════════════════════════════════════════════════════════
   Main macro that wraps user SQL with control fields.
#}

{% macro platform_entity(entity_type, primary_key=none, source_cdc_column=none, transaction_time_column=none, ingestion_time_column=none, source_system=none) %}
    {#
        Starts a platform entity definition.
        
        The user's SQL will be wrapped with automatic control fields.
        
        Args:
            entity_type: 'dimension', 'fact', 'bridge', 'snapshot', 'staging'
            primary_key: Column name for primary key (used for surrogate key generation)
            source_cdc_column: Column containing CDC timestamp (e.g., updated_at)
            transaction_time_column: Column with transaction timestamp (for facts)
            ingestion_time_column: Column with ingestion timestamp (for facts)
            source_system: Name of source system (e.g., 'salesforce', 'shopify')
    #}
    
    {# Log what we're doing for debugging #}
    {{ log("🏗️  Platform Entity: " ~ this.name ~ " (type: " ~ entity_type ~ ")", info=true) }}
    
    {# Build config object #}
    {% set config = {
        'primary_key': primary_key,
        'source_cdc_column': source_cdc_column,
        'transaction_time_column': transaction_time_column,
        'ingestion_time_column': ingestion_time_column,
        'source_system': source_system
    } %}
    
    {# Get control fields for this entity type #}
    {% set control_fields = get_entity_control_fields(entity_type, config) %}
    
    {# Store in context for platform_entity_end() to use #}
    {% do context.update({'_platform_control_fields': control_fields}) %}
    {% do context.update({'_platform_entity_type': entity_type}) %}
    
    {# Start the wrapper SELECT #}
    SELECT
        __user_query__.*,
        -- ═══════════════════════════════════════════════════════════════
        -- Platform Control Fields (auto-injected for {{ entity_type }})
        -- ═══════════════════════════════════════════════════════════════
        {% for field in control_fields %}
        {{ field }}{% if not loop.last %},{% endif %}
        {% endfor %}
    FROM (
{% endmacro %}


{% macro platform_entity_end() %}
    {#
        Closes the platform entity wrapper.
        Call this at the end of your user SQL.
    #}
    ) AS __user_query__
{% endmacro %}


{# ═══════════════════════════════════════════════════════════════════════════
   RELATIONSHIP METADATA READER
   ═══════════════════════════════════════════════════════════════════════════
   Reads relationship metadata from model meta tags.
#}

{% macro get_entity_relationships(model_name) %}
    {#
        Reads relationship metadata from the model's schema.yml meta tags.
        
        Example schema.yml:
            models:
              - name: fact_orders
                meta:
                  platform:
                    entity_type: fact
                    relationships:
                      - target: dim_customer
                        join_key: customer_id
                        type: many_to_one
                        
        Returns:
            List of relationship dictionaries
    #}
    
    {% set model_node = graph.nodes.get('model.' ~ project_name ~ '.' ~ model_name) %}
    
    {% if model_node and model_node.meta and model_node.meta.platform %}
        {% set platform_meta = model_node.meta.platform %}
        {% set relationships = platform_meta.get('relationships', []) %}
        
        {% for rel in relationships %}
            {{ log("  📎 Relationship: " ~ model_name ~ " -> " ~ rel.target ~ " via " ~ rel.join_key ~ " (" ~ rel.type ~ ")", info=true) }}
        {% endfor %}
        
        {{ return(relationships) }}
    {% else %}
        {{ return([]) }}
    {% endif %}
{% endmacro %}


{# ═══════════════════════════════════════════════════════════════════════════
   ENTITY VALIDATION
   ═══════════════════════════════════════════════════════════════════════════
   Validates entity metadata at compile time.
#}

{% macro validate_entity_metadata(model_name) %}
    {#
        Validates that the entity has required metadata defined.
        Called during dbt compile to catch errors early.
    #}
    
    {% set model_node = graph.nodes.get('model.' ~ project_name ~ '.' ~ model_name) %}
    
    {% if model_node and model_node.meta and model_node.meta.platform %}
        {% set platform_meta = model_node.meta.platform %}
        
        {# Check required fields based on entity type #}
        {% set entity_type = platform_meta.get('entity_type') %}
        
        {% if entity_type == 'dimension' and not platform_meta.get('primary_key') %}
            {{ exceptions.raise_compiler_error("Dimension '" ~ model_name ~ "' requires 'primary_key' in platform metadata") }}
        {% endif %}
        
        {% if entity_type == 'fact' %}
            {% set rels = platform_meta.get('relationships', []) %}
            {% if rels | length == 0 %}
                {{ log("⚠️  Warning: Fact table '" ~ model_name ~ "' has no relationships defined", info=true) }}
            {% endif %}
        {% endif %}
        
        {{ log("✅ Metadata validated for " ~ model_name, info=true) }}
    {% endif %}
{% endmacro %}


{# ═══════════════════════════════════════════════════════════════════════════
   SIMPLE WRAPPER FOR ONE-LINE USAGE
   ═══════════════════════════════════════════════════════════════════════════
   For simpler models, users can use this all-in-one wrapper.
#}

{% macro wrap_with_platform_fields(user_sql, entity_type, config={}) %}
    {#
        Simple wrapper that takes user SQL and adds platform fields.
        
        Usage:
            {{ wrap_with_platform_fields(
                "SELECT * FROM raw_customers",
                'dimension',
                {'primary_key': 'customer_id'}
            ) }}
    #}
    
    {% set control_fields = get_entity_control_fields(entity_type, config) %}
    
    SELECT
        __base__.*,
        -- Platform Control Fields
        {% for field in control_fields %}
        {{ field }}{% if not loop.last %},{% endif %}
        {% endfor %}
    FROM (
        {{ user_sql }}
    ) AS __base__
{% endmacro %}

