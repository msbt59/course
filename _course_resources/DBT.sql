CREATE or replace DATABASE DBT;
CREATE  schema DBT.INTRO;

USE DBT.INTRO;
CREATE OR REPLACE SECRET DBT.INTRO.tb_dbt_git_secret
  TYPE = PASSWORD
  USERNAME = 'msbt59'
  PASSWORD = 'xxx';




CREATE OR REPLACE API INTEGRATION tb_dbt_git_api_integration
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/msbt59')
  ALLOWED_AUTHENTICATION_SECRETS = (DBT.INTRO.tb_dbt_git_secret)
  ENABLED = TRUE;


CREATE OR REPLACE GIT REPOSITORY DBT.INTRO.dbt_mse_repo
  API_INTEGRATION = tb_dbt_git_api_integration
  GIT_CREDENTIALS = DBT.INTRO.tb_dbt_git_secret
  ORIGIN = 'https://github.com/msbt59/dbt_mse.git';
