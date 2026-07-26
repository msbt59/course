{{
  config(
    materialized = 'table',
    )
}}
with scr_hosts as (
    select * from {{ ref('scr_hosts') }}
)
select 
    HOST_ID,
    NVL(
        HOST_NAME,
       'N/A'
    ) as HOST_NAME,
    is_superhost,
    CREATED_AT,
    UPDATED_AT
from scr_hosts