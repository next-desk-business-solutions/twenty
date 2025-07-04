{ pkgs, lib, ... }:

{
  project.name = "twenty";

  services = {
    # Twenty CRM Server
    server = {
      image.name = "twentycrm/twenty:latest";
      
      service = {
        ports = [ "3000:3000" ];
        
        volumes = [
          "server-local-data:/app/packages/twenty-server/.local-storage"
        ];
        
        environment = {
          NODE_PORT = "3000";
          PG_DATABASE_URL = "postgres://postgres:postgres@db:5432/default";
          SERVER_URL = "http://localhost:3000";
          REDIS_URL = "redis://redis:6379";
          STORAGE_TYPE = "local";
          APP_SECRET = "replace_me_with_a_random_string";
          
          # Optional environment variables (commented out by default)
          # DISABLE_DB_MIGRATIONS = "";
          # DISABLE_CRON_JOBS_REGISTRATION = "";
          
          # Storage configuration
          # STORAGE_S3_REGION = "";
          # STORAGE_S3_NAME = "";
          # STORAGE_S3_ENDPOINT = "";
          
          # Authentication providers
          # MESSAGING_PROVIDER_GMAIL_ENABLED = "";
          # CALENDAR_PROVIDER_GOOGLE_ENABLED = "";
          # AUTH_GOOGLE_CLIENT_ID = "";
          # AUTH_GOOGLE_CLIENT_SECRET = "";
          # AUTH_GOOGLE_CALLBACK_URL = "";
          # AUTH_GOOGLE_APIS_CALLBACK_URL = "";
          
          # Microsoft authentication
          # CALENDAR_PROVIDER_MICROSOFT_ENABLED = "";
          # MESSAGING_PROVIDER_MICROSOFT_ENABLED = "";
          # AUTH_MICROSOFT_ENABLED = "";
          # AUTH_MICROSOFT_CLIENT_ID = "";
          # AUTH_MICROSOFT_CLIENT_SECRET = "";
          # AUTH_MICROSOFT_CALLBACK_URL = "";
          # AUTH_MICROSOFT_APIS_CALLBACK_URL = "";
          
          # Email configuration
          # EMAIL_FROM_ADDRESS = "contact@yourdomain.com";
          # EMAIL_FROM_NAME = "John from YourDomain";
          # EMAIL_SYSTEM_ADDRESS = "system@yourdomain.com";
          # EMAIL_DRIVER = "smtp";
          # EMAIL_SMTP_HOST = "smtp.gmail.com";
          # EMAIL_SMTP_PORT = "465";
          # EMAIL_SMTP_USER = "";
          # EMAIL_SMTP_PASSWORD = "";
        };
        
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
        
        environment = {
          PG_DATABASE_URL = "postgres://postgres:postgres@db:5432/default";
          SERVER_URL = "http://localhost:3000";
          REDIS_URL = "redis://redis:6379";
          STORAGE_TYPE = "local";
          APP_SECRET = "replace_me_with_a_random_string";
          
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