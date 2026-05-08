{{ log("target.name = " ~ target.name, info=True) }}
{{ log("target.schema = " ~ target.schema, info=True) }}

select
  '{{ target.name }}' as target_name,
  '{{ target.schema }}' as target_schema,
  '{{ target.database }}' as target_database