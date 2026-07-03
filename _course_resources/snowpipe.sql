CREATE OR REPLACE DATABASE SNOWPIPE;

-- create integration object that contains the access information
CREATE OR REPLACE STORAGE INTEGRATION azure_snowpipe_integration
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = AZURE
  ENABLED = TRUE
  AZURE_TENANT_ID =  'e6395e03-5130-40c6-b321-98099c6d9975'
  --il faut aller dans Répertoire par défaut | Vue d'ensemble dans azure
  STORAGE_ALLOWED_LOCATIONS = ( 'azure://msetestazure.blob.core.windows.net/ventes');
  --url du conteneur dans conteneur x2 et proprite

  
  
-- Describe integration object to provide access
DESC STORAGE integration azure_snowpipe_integration;
--il faut prendre la valeur AZURE_MULTI_TENANT_APP_NAME et rechercher dans azure IAM 

---- Create file format & stage objects ----

-- create file format

CREATE OR REPLACE FILE FORMAT ff_xml
TYPE = XML;

-- create stage object
create or replace stage snowpipe.public.stage_azure
    STORAGE_INTEGRATION = azure_snowpipe_integration
    URL = 'azure://msetestazure.blob.core.windows.net/ventes'
    FILE_FORMAT = ff_xml;
    

-- list files
LIST @snowpipe.public.stage_azure;



SELECT $1, metadata$filename,current_timestamp
FROM @snowpipe.public.stage_azure;



CREATE OR REPLACE NOTIFICATION INTEGRATION snowpipe_event
  ENABLED = true
  TYPE = QUEUE
  NOTIFICATION_PROVIDER = AZURE_STORAGE_QUEUE
  AZURE_STORAGE_QUEUE_PRIMARY_URI = 'https://msetestazure.queue.core.windows.net/ventesfileattente'
  AZURE_TENANT_ID = 'e6395e03-5130-40c6-b321-98099c6d9975';
  
  
  -- Register Integration
  
  DESC notification integration snowpipe_event;
  

CREATE OR REPLACE TABLE SNOWPIPE.PUBLIC.VENTES_VARIANT(
contenue variant, 
nom_fichier varchar(1000),
DATE_INSERT timestamp DEFAULT current_timestamp());
    

-- create pipe
  create OR REPLACE pipe ticket_pipe
  auto_ingest = true
  integration = 'SNOWPIPE_EVENT'
  as
COPY INTO snowpipe.public.VENTES_VARIANT (contenue, nom_fichier,DATE_INSERT)
FROM (
  SELECT $1, metadata$filename,current_timestamp
FROM @snowpipe.public.stage_azure

);

SELECT *
from VENTES_VARIANT;

SELECT SYSTEM$PIPE_STATUS( 'ticket_pipe' );

Create stream tickek_stream on table VENTES_VARIANT;

select *
from tickek_stream;

--table finale

create table ticket_entete
(
magasin number,
caisse number,
date_ticket date,
id number,
montant float,
codeclient number,
moyen_paiement varchar,
date_insert timestamp,
date_maj timestamp,
constraint pk_ticket primary key (magasin,caisse,date_ticket,id)
);

--creation de notre select pour une table finale
SELECT
    GET(XMLGET(contenue, 'magasin'), '$')::NUMBER AS magasin,
    GET(XMLGET(contenue, 'caisse'), '$')::NUMBER AS caisse,
    GET(XMLGET(contenue, 'date'), '$')::DATE AS date_ticket,
    GET(XMLGET(contenue, 'id_unique'), '$')::NUMBER AS id_unique,
    GET(XMLGET(contenue, 'montant'), '$')::NUMBER(10,2) AS montant,
    GET(XMLGET(contenue, 'codeclient'), '$')::NUMBER AS codeclient,
    GET(XMLGET(contenue, 'moyen_paiement'), '$')::STRING AS moyen_paiement,
    current_timestamp(),
    current_timestamp()
FROM VENTES_VARIANT;

---
MERGE INTO ticket_entete tgt
USING (
    SELECT
        GET(XMLGET(contenue, 'magasin'), '$')::NUMBER AS magasin,
        GET(XMLGET(contenue, 'caisse'), '$')::NUMBER AS caisse,
        GET(XMLGET(contenue, 'date'), '$')::DATE AS date_ticket,
        GET(XMLGET(contenue, 'id_unique'), '$')::NUMBER AS id,
        GET(XMLGET(contenue, 'montant'), '$')::FLOAT AS montant,
        GET(XMLGET(contenue, 'codeclient'), '$')::NUMBER AS codeclient,
        GET(XMLGET(contenue, 'moyen_paiement'), '$')::STRING AS moyen_paiement
    FROM VENTES_VARIANT
) src
ON tgt.magasin = src.magasin
AND tgt.caisse = src.caisse
AND tgt.date_ticket = src.date_ticket
AND tgt.id = src.id

WHEN MATCHED THEN
UPDATE SET
    tgt.montant = src.montant,
    tgt.codeclient = src.codeclient,
    tgt.moyen_paiement = src.moyen_paiement,
    tgt.date_maj = CURRENT_TIMESTAMP()

WHEN NOT MATCHED THEN
INSERT (
    magasin,
    caisse,
    date_ticket,
    id,
    montant,
    codeclient,
    moyen_paiement,
    date_insert,
    date_maj
)
VALUES (
    src.magasin,
    src.caisse,
    src.date_ticket,
    src.id,
    src.montant,
    src.codeclient,
    src.moyen_paiement,
    CURRENT_TIMESTAMP(),
    CURRENT_TIMESTAMP()
);



---creation de la task finale
SHOW STREAMS;
CREATE OR REPLACE TASK task_merge_ticket_entete
WAREHOUSE = 'COMPUTE_WH'
SCHEDULE = 'USING CRON 0 2 * * * Europe/Paris'  -- tous les jours à 02:00
WHEN SYSTEM$STREAM_HAS_DATA('SNOWPIPE.PUBLIC.tickek_stream')
AS

MERGE INTO ticket_entete tgt
USING (
    SELECT
        GET(XMLGET(contenue, 'magasin'), '$')::NUMBER AS magasin,
        GET(XMLGET(contenue, 'caisse'), '$')::NUMBER AS caisse,
        GET(XMLGET(contenue, 'date'), '$')::DATE AS date_ticket,
        GET(XMLGET(contenue, 'id_unique'), '$')::NUMBER AS id,
        GET(XMLGET(contenue, 'montant'), '$')::FLOAT AS montant,
        GET(XMLGET(contenue, 'codeclient'), '$')::NUMBER AS codeclient,
        GET(XMLGET(contenue, 'moyen_paiement'), '$')::STRING AS moyen_paiement
    FROM tickek_stream
) src
ON tgt.magasin = src.magasin
AND tgt.caisse = src.caisse
AND tgt.date_ticket = src.date_ticket
AND tgt.id = src.id

WHEN MATCHED THEN
UPDATE SET
    tgt.montant = src.montant,
    tgt.codeclient = src.codeclient,
    tgt.moyen_paiement = src.moyen_paiement,
    tgt.date_maj = CURRENT_TIMESTAMP()

WHEN NOT MATCHED THEN
INSERT (
    magasin,
    caisse,
    date_ticket,
    id,
    montant,
    codeclient,
    moyen_paiement,
    date_insert,
    date_maj
)
VALUES (
    src.magasin,
    src.caisse,
    src.date_ticket,
    src.id,
    src.montant,
    src.codeclient,
    src.moyen_paiement,
    CURRENT_TIMESTAMP(),
    CURRENT_TIMESTAMP()
);

select *
from SNOWPIPE.PUBLIC.ticket_entete;

ALTER TASK task_merge_ticket_entete RESUME;

execute task task_merge_ticket_entete;