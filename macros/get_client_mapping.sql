{% macro get_client_mappings(target_model=none) %}
    {#
        Reads all client mapping YAML files from models/staging/client_mappings/
        and returns a list of mapping configurations.
        
        Optionally filter by target_model (e.g., 'dim_candidate')
        
        Usage:
            {% set clients = get_client_mappings('dim_candidate') %}
            {% for client in clients %}
                -- Process {{ client.client_code }}
            {% endfor %}
    #},
        {
            'client_code': 'ACME',
            'client_name': 'ACME',
            'source_table': 'employee_feed',
            'target_model': 'dim_candidate',
            'field_mappings': {
                'candidate_id': "emp_id",
                'full_name': "CONCAT(fname, lname)",
                'email': "email_address",
                'phone_number': "mobile",
                'hire_date': "start_dt",
                'hourly_rate': "rate_per_hour",
                'client_code': ''ACME''
            }
        },
        {
            'client_code': 'ACME_2',
            'client_name': 'Acme_2',
            'source_table': 'employee_feed',
            'target_model': 'dim_candidate',
            'field_mappings': {
                'candidate_id': "emp_id",
                'full_name': "CONCAT(fname, ' ', lname)",
                'email': "email_address",
                'phone_number': "mobile",
                'hire_date': "start_dt",
                'hourly_rate': "rate_per_hour",
                'client_code': ''ACME_2''
            }
        }
    
    {% set mappings = [] %}
    
    {# 
        Define client mappings here. In production, these would be read from YAML files.
        The Client Mapping Portal generates these configurations automatically.
    #}
    
    {% set all_mappings = [
        {
            'client_code': 'ACME',
            'client_name': 'Acme Corp',
            'source_table': 'acme_employee_feed',
            'target_model': 'dim_candidate',
            'field_mappings': {
                'candidate_id': 'emp_id',
                'full_name': "fname || ' ' || lname",
                'email': 'email_address',
                'phone_number': 'mobile',
                'hire_date': 'TRY_CAST(start_dt AS DATE)',
                'hourly_rate': 'rate_per_hour',
                'client_code': "'ACME'"
            }
        },
        {
            'client_code': 'GLOBEX',
            'client_name': 'Globex Corporation',
            'source_table': 'globex_staff_records',
            'target_model': 'dim_candidate',
            'field_mappings': {
                'candidate_id': 'staff_id',
                'full_name': 'full_name',
                'email': 'work_email',
                'phone_number': 'phone',
                'hire_date': 'onboard_date',
                'hourly_rate': 'pay_rate',
                'client_code': "'GLOBEX'"
            }
        },
        {
            'client_code': 'WAYNE',
            'client_name': 'Wayne Enterprises',
            'source_table': 'wayne_enterprises_workers',
            'target_model': 'dim_candidate',
            'field_mappings': {
                'candidate_id': 'worker_id',
                'full_name': "first_name || ' ' || last_name",
                'email': 'email',
                'phone_number': 'contact_phone',
                'hire_date': 'hire_date',
                'hourly_rate': 'hourly_wage',
                'client_code': "'WAYNE'"
            }
        }
    ] %}
    
    {# Filter by target_model if specified #}
    {% for mapping in all_mappings %}
        {% if target_model is none or mapping.target_model == target_model %}
            {% do mappings.append(mapping) %}
        {% endif %}
    {% endfor %}
    
    {{ return(mappings) }}
{% endmacro %}
