drop database INSEPTI_SNOWPIPE;
CREATE  DATABASE INSEPTI_SNOWPIPE;
CREATE  schema INSEPTI_SNOWPIPE.TEST1;

CREATE STORAGE INTEGRATION AZURE_SNOWPIPE_INSEPTI
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'AZURE'
  ENABLED = TRUE
  AZURE_TENANT_ID = 'e6395e03-5130-40c6-b321-98099c6d9975'
  STORAGE_ALLOWED_LOCATIONS = ('azure://testinsepti.blob.core.windows.net/json');

DESC INTEGRATION AZURE_SNOWPIPE_INT;

 
CREATE OR REPLACE TABLE INSEPTI_SNOWPIPE.PUBLIC.VENTES_VARIANT(
contenue variant, 
nom_fichier varchar(1000),
DATE_INSERT timestamp DEFAULT current_timestamp());


CREATE OR REPLACE FILE FORMAT ff_xml
TYPE = XML;

-- create stage object
create or replace stage INSEPTI_SNOWPIPE.public.stage_azure
    STORAGE_INTEGRATION = AZURE_SNOWPIPE_INT
    URL = 'azure://testinsepti.blob.core.windows.net/json'
    FILE_FORMAT = ff_xml;

LIST @INSEPTI_SNOWPIPE.public.stage_azure;



create OR REPLACE pipe inspeti_ticket_pipe
auto_ingest = true
integration = 'SNOWPIPE_EVENT'
as
COPY INTO INSEPTI_SNOWPIPE.public.VENTES_VARIANT (contenue, nom_fichier,DATE_INSERT)
FROM (
  SELECT $1, metadata$filename,current_timestamp
FROM @INSEPTI_SNOWPIPE.public.stage_azure

);

DESC PIPE inspeti_ticket_pipe;