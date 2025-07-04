{ pkgs, lib, config }:

let
  # Helper function to read file content at runtime
  readSecret = file: if file != null then "$(cat ${file})" else null;
  
  # Build environment variables dynamically
  baseEnv = {
    NODE_PORT = toString config.port;
    SERVER_URL = config.serverUrl;
    STORAGE_TYPE = config.storage.type;
  };
  
  secretEnv = lib.optionalAttrs (config.appSecretFile != null) {
    APP_SECRET = readSecret config.appSecretFile;
  } // lib.optionalAttrs (config.database.passwordFile != null) {
    PG_DATABASE_URL = "postgres://${config.database.user}:$(cat ${config.database.passwordFile})@db:5432/default";
  } // lib.optionalAttrs (config.storage.type == "s3") (
    lib.optionalAttrs (config.storage.s3.region != null) {
      STORAGE_S3_REGION = config.storage.s3.region;
    } // lib.optionalAttrs (config.storage.s3.bucket != null) {
      STORAGE_S3_NAME = config.storage.s3.bucket;
    } // lib.optionalAttrs (config.storage.s3.endpoint != null) {
      STORAGE_S3_ENDPOINT = config.storage.s3.endpoint;
    }
  ) // lib.optionalAttrs config.auth.google.enabled (
    lib.optionalAttrs (config.auth.google.clientIdFile != null) {
      AUTH_GOOGLE_CLIENT_ID = readSecret config.auth.google.clientIdFile;
    } // lib.optionalAttrs (config.auth.google.clientSecretFile != null) {
      AUTH_GOOGLE_CLIENT_SECRET = readSecret config.auth.google.clientSecretFile;
    } // {
      MESSAGING_PROVIDER_GMAIL_ENABLED = "true";
      CALENDAR_PROVIDER_GOOGLE_ENABLED = "true";
      AUTH_GOOGLE_CALLBACK_URL = "${config.serverUrl}/auth/google/callback";
      AUTH_GOOGLE_APIS_CALLBACK_URL = "${config.serverUrl}/auth/google-apis/callback";
    }
  ) // lib.optionalAttrs config.auth.microsoft.enabled (
    lib.optionalAttrs (config.auth.microsoft.clientIdFile != null) {
      AUTH_MICROSOFT_CLIENT_ID = readSecret config.auth.microsoft.clientIdFile;
    } // lib.optionalAttrs (config.auth.microsoft.clientSecretFile != null) {
      AUTH_MICROSOFT_CLIENT_SECRET = readSecret config.auth.microsoft.clientSecretFile;
    } // {
      CALENDAR_PROVIDER_MICROSOFT_ENABLED = "true";
      MESSAGING_PROVIDER_MICROSOFT_ENABLED = "true";
      AUTH_MICROSOFT_ENABLED = "true";
      AUTH_MICROSOFT_CALLBACK_URL = "${config.serverUrl}/auth/microsoft/callback";
      AUTH_MICROSOFT_APIS_CALLBACK_URL = "${config.serverUrl}/auth/microsoft-apis/callback";
    }
  ) // lib.optionalAttrs (config.email.driver != null) (
    {
      EMAIL_DRIVER = config.email.driver;
    } // lib.optionalAttrs (config.email.fromAddress != null) {
      EMAIL_FROM_ADDRESS = config.email.fromAddress;
    } // lib.optionalAttrs (config.email.fromName != null) {
      EMAIL_FROM_NAME = config.email.fromName;
    } // lib.optionalAttrs (config.email.smtp.host != null) {
      EMAIL_SMTP_HOST = config.email.smtp.host;
    } // lib.optionalAttrs (config.email.smtp.port != null) {
      EMAIL_SMTP_PORT = toString config.email.smtp.port;
    } // lib.optionalAttrs (config.email.smtp.userFile != null) {
      EMAIL_SMTP_USER = readSecret config.email.smtp.userFile;
    } // lib.optionalAttrs (config.email.smtp.passwordFile != null) {
      EMAIL_SMTP_PASSWORD = readSecret config.email.smtp.passwordFile;
    }
  );
  
  # Fallback values for required env vars
  environment = baseEnv // secretEnv // {
    PG_DATABASE_URL = 
      if config.database.passwordFile != null 
      then "postgres://${config.database.user}:$(cat ${config.database.passwordFile})@db:5432/default"
      else "postgres://${config.database.user}:postgres@db:5432/default";
    REDIS_URL = "redis://redis:6379";
    APP_SECRET = 
      if config.appSecretFile != null 
      then readSecret config.appSecretFile
      else "replace_me_with_a_random_string";
  };
in
{
  project.name = "twenty";

  services = {
    # Twenty CRM Server
    server = {
      image.name = "twentycrm/twenty:latest";
      
      service = {
        ports = [ "${toString config.port}:3000" ];
        
        volumes = [
          "server-local-data:/app/packages/twenty-server/.local-storage"
        ];
        
        environment = environment;
        
        depends_on = {
          db = {
            condition = "service_healthy";
          };
        };
        
        healthcheck = {
          test = [ "CMD" "curl" "--fail" "http://localhost:3000/healthz" ];
          interval = "5s";
          timeout = "5s";
          retries = 20;
        };
        
        restart = "always";
      };
    };

    # Twenty CRM Worker
    worker = {
      image.name = "twentycrm/twenty:latest";
      
      service = {
        command = [ "yarn" "worker:prod" ];
        
        volumes = [
          "server-local-data:/app/packages/twenty-server/.local-storage"
        ];
        
        environment = environment // {
          # Disable migrations and cron registration for worker
          DISABLE_DB_MIGRATIONS = "true";
          DISABLE_CRON_JOBS_REGISTRATION = "true";
        };
        
        depends_on = {
          db = {
            condition = "service_healthy";
          };
          server = {
            condition = "service_healthy";
          };
        };
        
        restart = "always";
      };
    };

    # PostgreSQL Database
    db = {
      image.name = "postgres:16";
      
      service = {
        volumes = [
          "db-data:/var/lib/postgresql/data"
        ];
        
        environment = {
          POSTGRES_USER = "postgres";
          POSTGRES_PASSWORD = "postgres";
        };
        
        healthcheck = {
          test = [ "CMD" "pg_isready" "-U" "postgres" "-h" "localhost" "-d" "postgres" ];
          interval = "5s";
          timeout = "5s";
          retries = 10;
        };
        
        restart = "always";
      };
    };

    # Redis Cache
    redis = {
      image.name = "redis:latest";
      
      service = {
        command = [ "--maxmemory-policy" "noeviction" ];
        restart = "always";
      };
    };
  };

  # Docker volumes
  docker-compose.volumes = {
    db-data = {};
    server-local-data = {};
  };
}