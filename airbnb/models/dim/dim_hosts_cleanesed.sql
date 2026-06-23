{{
  config(
    materialized = 'view'
    )
}}
with scr_hosts as (
    select * from {{ ref('scr_hosts') }}
)
select 
    HOST_ID,
    NVL(
        HOST_NAME,
       'Anonymous'
    ) as HOST_NAME,
    is_superhost,
    CREATED_AT,
    UPDATED_AT
from scr_hosts