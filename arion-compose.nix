{ pkgs, lib ? pkgs.lib, config ? null, ... }:

let
  # Default configuration for local development
  defaultConfig = {
    port = 3000;
    serverUrl = "http://localhost:3000";
    storage = {
      type = "local";
      s3 = {};
    };
    database = {
      user = "postgres";
      password = "postgres";
      passwordFile = null;
    };
    appSecret = "replace_me_with_a_random_string";
    appSecretFile = null;
    auth = {
      google = { 
        enabled = false;
        clientIdFile = null;
        clientSecretFile = null;
      };
      microsoft = { 
        enabled = false;
        clientIdFile = null;
        clientSecretFile = null;
      };
    };
    email = { 
      driver = null;
      fromAddress = null;
      fromName = null;
      smtp = {
        host = null;
        port = null;
        userFile = null;
        passwordFile = null;
      };
    };
  };

  # Use provided config or fallback to defaults
  cfg = defaultConfig // (if config != null then config else {});

  # Build environment variables dynamically
  baseEnv = {
    NODE_PORT = toString cfg.port;
    SERVER_URL = cfg.serverUrl;
    STORAGE_TYPE = cfg.storage.type;
  };
  
  secretEnv = lib.optionalAttrs (cfg.appSecret or null != null) {
    APP_SECRET = cfg.appSecret;
  } // lib.optionalAttrs (cfg.appSecretFile or null != null) {
    APP_SECRET_FILE = "/secrets/twenty-app-secret";
  } // lib.optionalAttrs (cfg.database.password or null != null) {
    PG_DATABASE_URL = "postgres://${cfg.database.user}:${cfg.database.password}@db:5432/default";
  } // lib.optionalAttrs (cfg.database.passwordFile or null != null) {
    POSTGRES_PASSWORD_FILE = "/secrets/twenty-db-password";
    PG_DATABASE_URL = "postgres://${cfg.database.user}:$(cat /secrets/twenty-db-password)@db:5432/default";
  } // lib.optionalAttrs (cfg.storage.type == "s3") (
    lib.optionalAttrs (cfg.storage.s3.region != null) {
      STORAGE_S3_REGION = cfg.storage.s3.region;
    } // lib.optionalAttrs (cfg.storage.s3.bucket != null) {
      STORAGE_S3_NAME = cfg.storage.s3.bucket;
    } // lib.optionalAttrs (cfg.storage.s3.endpoint != null) {
      STORAGE_S3_ENDPOINT = cfg.storage.s3.endpoint;
    }
  ) // lib.optionalAttrs cfg.auth.google.enabled (
    lib.optionalAttrs (cfg.auth.google.clientIdFile != null) {
      AUTH_GOOGLE_CLIENT_ID = "$(cat /secrets/google-client-id)";
    } // lib.optionalAttrs (cfg.auth.google.clientSecretFile != null) {
      AUTH_GOOGLE_CLIENT_SECRET = "$(cat /secrets/google-client-secret)";
    } // {
      MESSAGING_PROVIDER_GMAIL_ENABLED = "true";
      CALENDAR_PROVIDER_GOOGLE_ENABLED = "true";
      AUTH_GOOGLE_CALLBACK_URL = "${cfg.serverUrl}/auth/google/callback";
      AUTH_GOOGLE_APIS_CALLBACK_URL = "${cfg.serverUrl}/auth/google-apis/callback";
    }
  ) // lib.optionalAttrs cfg.auth.microsoft.enabled (
    lib.optionalAttrs (cfg.auth.microsoft.clientIdFile != null) {
      AUTH_MICROSOFT_CLIENT_ID = "$(cat /secrets/microsoft-client-id)";
    } // lib.optionalAttrs (cfg.auth.microsoft.clientSecretFile != null) {
      AUTH_MICROSOFT_CLIENT_SECRET = "$(cat /secrets/microsoft-client-secret)";
    } // {
      CALENDAR_PROVIDER_MICROSOFT_ENABLED = "true";
      MESSAGING_PROVIDER_MICROSOFT_ENABLED = "true";
      AUTH_MICROSOFT_ENABLED = "true";
      AUTH_MICROSOFT_CALLBACK_URL = "${cfg.serverUrl}/auth/microsoft/callback";
      AUTH_MICROSOFT_APIS_CALLBACK_URL = "${cfg.serverUrl}/auth/microsoft-apis/callback";
    }
  ) // lib.optionalAttrs (cfg.email.driver != null) (
    {
      EMAIL_DRIVER = cfg.email.driver;
    } // lib.optionalAttrs (cfg.email.fromAddress != null) {
      EMAIL_FROM_ADDRESS = cfg.email.fromAddress;
    } // lib.optionalAttrs (cfg.email.fromName != null) {
      EMAIL_FROM_NAME = cfg.email.fromName;
    } // lib.optionalAttrs (cfg.email.smtp.host != null) {
      EMAIL_SMTP_HOST = cfg.email.smtp.host;
    } // lib.optionalAttrs (cfg.email.smtp.port != null) {
      EMAIL_SMTP_PORT = toString cfg.email.smtp.port;
    } // lib.optionalAttrs (cfg.email.smtp.userFile != null) {
      EMAIL_SMTP_USER = "$(cat /secrets/smtp-user)";
    } // lib.optionalAttrs (cfg.email.smtp.passwordFile != null) {
      EMAIL_SMTP_PASSWORD = "$(cat /secrets/smtp-password)";
    }
  );
  
  # Fallback values for required env vars
  environment = baseEnv // secretEnv // {
    PG_DATABASE_URL = 
      if cfg.database.passwordFile != null then "postgres://${cfg.database.user}:$(cat /secrets/twenty-db-password)@db:5432/default"
      else "postgres://${cfg.database.user}:${cfg.database.password or "postgres"}@db:5432/default";
    REDIS_URL = "redis://redis:6379";
    APP_SECRET = 
      if cfg.appSecretFile != null then "$(cat /secrets/twenty-app-secret)"
      else cfg.appSecret or "replace_me_with_a_random_string";
  } // lib.optionalAttrs (cfg.database.passwordFile != null) {
    POSTGRES_PASSWORD_FILE = "/secrets/twenty-db-password";
  };
  
  # Volume mounts for secrets
  secretVolumes = lib.optionals (cfg.database.passwordFile != null || cfg.appSecretFile != null) [
    "/run/agenix:/secrets:ro"
  ];
in
{
  project.name = "twenty";

  services = {
    # Twenty CRM Server
    server = {
      service = {
        image = "twentycrm/twenty:latest";
        ports = [ "${toString cfg.port}:3000" ];
        
        volumes = [
          "server-local-data:/app/packages/twenty-server/.local-storage"
        ] ++ secretVolumes;
        
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
      service = {
        image = "twentycrm/twenty:latest";
        command = [ "yarn" "worker:prod" ];
        
        volumes = [
          "server-local-data:/app/packages/twenty-server/.local-storage"
        ] ++ secretVolumes;
        
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
        
        restart = "unless-stopped";
      };
    };

    # PostgreSQL Database
    db = {
      service = {
        image = "postgres:16";
        volumes = [
          "db-data:/var/lib/postgresql/data"
        ] ++ secretVolumes;
        
        environment = {
          POSTGRES_USER = cfg.database.user;
          # Don't set POSTGRES_DB - let Twenty create the 'default' database
        } // (if cfg.database.passwordFile != null then {
          POSTGRES_PASSWORD_FILE = "/secrets/twenty-db-password";
        } else {
          POSTGRES_PASSWORD = cfg.database.password or "postgres";
        });
        
        healthcheck = {
          test = [ "CMD" "pg_isready" "-U" "${cfg.database.user}" "-h" "localhost" "-d" "postgres" ];
          interval = "5s";
          timeout = "5s";
          retries = 10;
        };
        
        restart = "always";
      };
    };

    # Redis Cache
    redis = {
      service = {
        image = "redis:latest";
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