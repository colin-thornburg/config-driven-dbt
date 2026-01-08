{{
    config(
        materialized='view',
        tags=['staging', 'config_driven']
    )
}}

{#
    ════════════════════════════════════════════════════════════════════════════
    MODEL: stg_candidates_unioned
    ════════════════════════════════════════════════════════════════════════════
    
    🎯 PURPOSE:
    This model unions candidate data from ALL clients into a single standardized
    table. Instead of hardcoding SQL for each client, it uses DYNAMIC CODE 
    GENERATION to automatically create the UNION ALL query at runtime.
    
    ════════════════════════════════════════════════════════════════════════════
    🔄 HOW IT WORKS (Non-Technical Explanation):
    ════════════════════════════════════════════════════════════════════════════
    
    Think of this like a mail-merge template:
    
    TRADITIONAL WAY (Hardcoded):
    ┌─────────────────────────────────────────────────────────────────────────┐
    │ SELECT * FROM acme_employee_feed                                        │
    │ UNION ALL                                                               │
    │ SELECT * FROM globex_staff_records     ← Must manually add each client │
    │ UNION ALL                                                               │
    │ SELECT * FROM wayne_workers            ← Lots of copy/paste            │
    └─────────────────────────────────────────────────────────────────────────┘
    
    THIS MODEL (Dynamic):
    ┌─────────────────────────────────────────────────────────────────────────┐
    │ 1. Read list of clients from dbt_project.yml                           │
    │ 2. For each client, generate a SELECT statement using their mappings   │
    │ 3. Combine all SELECT statements with UNION ALL                        │
    │ 4. Result: Fully generated SQL with NO manual editing!                 │
    └─────────────────────────────────────────────────────────────────────────┘
    
    ════════════════════════════════════════════════════════════════════════════
    📋 WHEN A NEW CLIENT IS ADDED:
    ════════════════════════════════════════════════════════════════════════════
    
    Step 1: User submits mapping via Client Mapping Portal
            ↓
    Step 2: API adds client config to dbt_project.yml:
            vars:
              client_mappings:
                - client_code: NEW_CLIENT
                  source_table: new_client_feed
                  field_mappings: { ... }
            ↓
    Step 3: THIS MODEL automatically picks it up (no code changes needed!)
            ↓
    Step 4: Next dbt run includes NEW_CLIENT in the UNION
    
    🎉 No manual SQL changes required for new client onboarding!
    
    ════════════════════════════════════════════════════════════════════════════
    🔍 WHAT THE CODE BELOW DOES (Line by Line):
    ════════════════════════════════════════════════════════════════════════════
    
    Line 67: {% set client_mappings = get_client_mappings('dim_candidate') %}
             ↑ Calls a macro that reads dbt_project.yml and returns a list of 
               all clients configured for the 'dim_candidate' target model.
               
               Example return value:
               [
                 {client_code: 'ACME', source_table: 'acme_employee_feed', ...},
                 {client_code: 'GLOBEX', source_table: 'globex_staff_records', ...},
                 {client_code: 'WAYNE', source_table: 'wayne_workers', ...}
               ]
    
    Line 69-71: Error check
                ↑ If no clients are configured, throw an error (prevents empty query)
    
    Line 73: {% for client in client_mappings %}
             ↑ Loop through each client in the list (like a for-loop in Python/JavaScript)
               This generates one SELECT statement per client
    
    Line 78-93: SELECT statement template
                ↑ This is the template for each client's SELECT
                  {{ client.field_mappings.candidate_id }} gets replaced with the 
                  actual field name from the client's config
                  
                  Example: If ACME maps 'emp_id' to 'candidate_id':
                  Line 80 becomes: emp_id AS candidate_id
    
    Line 95: {% if not loop.last %}
             ↑ Only add "UNION ALL" if this isn't the last client
               (prevents trailing UNION ALL at the end)
    
    ════════════════════════════════════════════════════════════════════════════
    📊 COMPILED OUTPUT EXAMPLE:
    ════════════════════════════════════════════════════════════════════════════
    
    After dbt compiles this template, it generates pure SQL like:
    
    SELECT
        emp_id AS candidate_id,
        fname || ' ' || lname AS full_name,
        email_address AS email,
        ...
    FROM acme_employee_feed
    
    UNION ALL
    
    SELECT
        staff_id AS candidate_id,
        full_name AS full_name,
        work_email AS email,
        ...
    FROM globex_staff_records
    
    UNION ALL
    
    SELECT
        worker_id AS candidate_id,
        first_name || ' ' || last_name AS full_name,
        email AS email,
        ...
    FROM wayne_workers
    
    ════════════════════════════════════════════════════════════════════════════
    
    💡 TIP: Run `dbt compile --select stg_candidates_unioned` to see the 
            generated SQL in target/compiled/
    
    ════════════════════════════════════════════════════════════════════════════
#}

{# ═══════════════════════════════════════════════════════════════════════════
   STEP 1: Get list of all clients configured for dim_candidate
   ═══════════════════════════════════════════════════════════════════════════
   This calls the get_client_mappings() macro which:
   - Reads dbt_project.yml
   - Finds all clients under vars.client_mappings
   - Filters to only clients with target_model = 'dim_candidate'
   - Returns a list of client configuration objects
#}
{% set client_mappings = get_client_mappings('dim_candidate') %}

{# ═══════════════════════════════════════════════════════════════════════════
   STEP 2: Validate that we have at least one client
   ═══════════════════════════════════════════════════════════════════════════
   If no clients are configured, compilation fails with a clear error message.
   This prevents generating an empty/invalid query.
#}
{% if client_mappings | length == 0 %}
    {{ exceptions.raise_compiler_error("No client mappings found for dim_candidate. Please add at least one client mapping.") }}
{% endif %}

{# ═══════════════════════════════════════════════════════════════════════════
   STEP 3: Loop through each client and generate a SELECT statement
   ═══════════════════════════════════════════════════════════════════════════
   For each client in the list, this generates:
   1. A SELECT statement with their field mappings
   2. A UNION ALL (if not the last client)
   
   Example: If client_mappings contains [ACME, GLOBEX, WAYNE], this loop
   will run 3 times and generate 3 SELECT statements joined by UNION ALL
#}
{% for client in client_mappings %}

    {# Log which client we're processing (helps with debugging) #}
    {{ log_client_mapping(client) }}

    SELECT
        -- ═══════════════════════════════════════════════════════════════════
        -- Target dimension fields (mapped from source)
        -- ═══════════════════════════════════════════════════════════════════
        -- Each {{ client.field_mappings.X }} is replaced with the actual
        -- source field expression from dbt_project.yml
        --
        -- Example for ACME:
        --   {{ client.field_mappings.candidate_id }} → emp_id
        --   {{ client.field_mappings.full_name }} → fname || ' ' || lname
        -- ═══════════════════════════════════════════════════════════════════
        {{ client.field_mappings.candidate_id }} AS candidate_id,
        {{ client.field_mappings.full_name }} AS full_name,
        {{ client.field_mappings.email }} AS email,
        {{ client.field_mappings.phone_number }} AS phone_number,
        {{ client.field_mappings.hire_date }} AS hire_date,
        {{ client.field_mappings.hourly_rate }} AS hourly_rate,
        {{ client.field_mappings.client_code }} AS client_code,
        
        -- ═══════════════════════════════════════════════════════════════════
        -- Metadata fields (automatically added for tracking)
        -- ═══════════════════════════════════════════════════════════════════
        CURRENT_TIMESTAMP() AS _loaded_at,           -- When data was loaded
        '{{ client.client_code }}' AS _source_system, -- Which client (e.g., 'ACME')
        '{{ client.source_table }}' AS _source_table  -- Source table name
        
    FROM {{ ref(client.source_table) }}  {# References the seed/source table #}

    {# ═══════════════════════════════════════════════════════════════════════
       Add UNION ALL between clients (but not after the last one)
       ═══════════════════════════════════════════════════════════════════════
       loop.last is a Jinja variable that's True when processing the last item.
       This ensures we don't add a trailing "UNION ALL" at the end.
    #}
    {% if not loop.last %}
    UNION ALL
    {% endif %}

{% endfor %}
