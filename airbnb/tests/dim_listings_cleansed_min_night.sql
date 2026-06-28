SELECT * FROM {{ref('dim_listings_cleansed')}}
WHERE MINIMUM_NIGHTS<1
LIMIT 10