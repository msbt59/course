create or replace database test_network_policy;
create schema test_network_policy.test_simple;
CREATE OR REPLACE NETWORK RULE test_network_policy.test_simple.POWERBI_IPS
  TYPE = IPV4
  MODE = INGRESS
  VALUE_LIST = (
    '13.80.200.0/23',
    '13.80.202.0/26',
    '13.80.212.128/26'
  )
  COMMENT = 'IPs Power BI Europe – test';

DESCRIBE NETWORK RULE POWERBI_IPS;

CREATE OR REPLACE NETWORK POLICY POWERBI_POLICY
  ALLOWED_NETWORK_RULE_LIST = ('POWERBI_IPS')
  COMMENT = 'Policy Power BI – test';


DESCRIBE NETWORK POLICY POWERBI_POLICY;

CREATE USER SVC_POWERBI
  PASSWORD = 'TempPassword123!'
  DEFAULT_ROLE = PUBLIC
  COMMENT = 'Service user Power BI';

  ALTER USER SVC_POWERBI
  SET NETWORK_POLICY = POWERBI_POLICY;

DESCRIBE USER SVC_POWERBI;

SHOW PARAMETERS LIKE 'NETWORK_POLICY' IN USER SVC_POWERBI;


CREATE OR REPLACE PROCEDURE UPDATE_POWERBI_NETWORK_RULE()
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python', 'requests')
HANDLER = 'run'
AS
$$
import requests
import re

TARGET_REGIONS = [
    "PowerBI.WestEurope",
    "PowerBI.NorthEurope",
    "PowerBI.FranceCentral",
    "PowerBI.FranceSouth",
]

def get_latest_json_url():
    page = requests.get(
        "https://www.microsoft.com/en-us/download/confirmation.aspx?id=56519",
        timeout=15
    )
    match = re.search(
        r'https://download\.microsoft\.com/download/[^"]+ServiceTags_Public_\d+\.json',
        page.text
    )
    if not match:
        raise ValueError("URL du JSON Microsoft introuvable")
    return match.group(0)

def get_powerbi_ips(url):
    response = requests.get(url, timeout=30)
    response.raise_for_status()
    data = response.json()
    all_ips = set()
    for entry in data.get("values", []):
        if entry.get("name") in TARGET_REGIONS:
            for ip in entry["properties"]["addressPrefixes"]:
                if ":" not in ip:  # IPv4 uniquement
                    all_ips.add(ip)
    return sorted(all_ips)

def run(session):
    url = get_latest_json_url()
    ips = get_powerbi_ips(url)
    if not ips:
        return "ERREUR : aucune IP trouvée"
    
    ip_list = ", ".join([f"'{ip}'" for ip in ips])
    session.sql(f"""
        ALTER NETWORK RULE POWERBI_IPS
        SET VALUE_LIST = ({ip_list})
    """).collect()
    
    return f"OK — {len(ips)} IPs mises à jour"
$$;

CALL UPDATE_POWERBI_NETWORK_RULE();


CREATE OR REPLACE NETWORK RULE MICROSOFT_DOWNLOAD_RULE
  TYPE = HOST_PORT
  MODE = EGRESS
  VALUE_LIST = (
    'www.microsoft.com:443',
    'download.microsoft.com:443'
  )
  COMMENT = 'Accès sortant vers Microsoft pour télécharger les Service Tags';

  CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION MICROSOFT_DOWNLOAD_INTEGRATION
  ALLOWED_NETWORK_RULES = (MICROSOFT_DOWNLOAD_RULE)
  ENABLED = TRUE
  COMMENT = 'Accès externe Microsoft pour mise à jour IPs Power BI';

  -------------------------------

CREATE OR REPLACE PROCEDURE UPDATE_POWERBI_NETWORK_RULE(IP_LIST STRING)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'run'
AS
$$
def run(session, ip_list):
    if not ip_list:
        return "ERREUR : liste d'IPs vide"
    
    ips = [ip.strip() for ip in ip_list.split(",")]
    formatted = ", ".join([f"'{ip}'" for ip in ips])
    
    session.sql(f"""
        ALTER NETWORK RULE POWERBI_IPS
        SET VALUE_LIST = ({formatted})
    """).collect()
    
    return f"OK — {len(ips)} IPs mises à jour"
$$;

CALL UPDATE_POWERBI_NETWORK_RULE('13.80.200.0/23,13.80.202.0/26,13.80.212.128/26');

DESCRIBE NETWORK RULE POWERBI_IPS;

CREATE OR REPLACE NETWORK POLICY powerbi_service_policy
  ALLOWED_NETWORK_RULE_LIST = ('SNOWFLAKE.NETWORK_SECURITY.POWERBI_WESTEUROPE_AZURE');

DESCRIBE NETWORK RULE SNOWFLAKE.NETWORK_SECURITY.POWERBI_WESTEUROPE_AZURE;

SHOW NETWORK RULES IN SNOWFLAKE.NETWORK_SECURITY;

SELECT name
  FROM SNOWFLAKE.ACCOUNT_USAGE.NETWORK_RULES
  WHERE DATABASE = 'SNOWFLAKE' AND SCHEMA = 'NETWORK_SECURITY'
  and name like '%POWER%WEST%EURO%'
;

DESCRIBE NETWORK POLICY POWERBI_SERVICE_POLICY;

CREATE USER SVC_POWERBI_PAT
  DEFAULT_ROLE = PUBLIC
  COMMENT = 'Service user Power BI – authentification PAT';

ALTER USER SVC_POWERBI_PAT
  ADD PROGRAMMATIC ACCESS TOKEN POWERBI_PAT_365
  DAYS_TO_EXPIRY = 365
  COMMENT = 'Token PAT Power BI – 1 an';

--eyJraWQiOiIyNTY1MDE2MzczNyIsImFsZyI6IkVTMjU2In0.eyJwIjoiMTAwMTk2MDA0OjEwMDE5NTk3MiIsImlzcyI6IlNGOjIwMDIiLCJleHAiOjE4MTI2MjQyMjJ9.2unrM4WqWrzKWjJOAaMrY-3Mb-6jGN-OJPZ-_Z-rnzqo7K-uKT_WXKKUW2akyc8R1q8y9U3JjMws68DcL78z_g


ALTER USER SVC_POWERBI_PAT
  SET NETWORK_POLICY = POWERBI_SERVICE_POLICY;

  ALTER USER SVC_POWERBI_PAT
  UNSET NETWORK_POLICY;

SHOW PARAMETERS LIKE 'NETWORK_POLICY' IN USER SVC_POWERBI_PAT;