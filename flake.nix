{
  description = "Twenty CRM - Arion configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    {
      # Export the nixos modules for easy importing
      nixosModules.default = { config, lib, pkgs, ... }:
        with lib;
        let
          cfg = config.services.twenty-crm;
        in
        {

          options.services.twenty-crm = {
            enable = mkEnableOption "Twenty CRM";

            serverUrl = mkOption {
              type = types.str;
              default = "http://localhost:3000";
              description = "Public URL of the Twenty instance";
            };

            port = mkOption {
              type = types.port;
              default = 3000;
              description = "Port to expose Twenty on";
            };

            appSecretFile = mkOption {
              type = types.nullOr types.path;
              default = null;
              description = "Path to file containing app secret";
              example = "/run/secrets/twenty-app-secret";
            };

            database = {
              user = mkOption {
                type = types.str;
                default = "postgres";
                description = "PostgreSQL user";
              };

              passwordFile = mkOption {
                type = types.nullOr types.path;
                default = null;
                description = "Path to file containing PostgreSQL password";
                example = "/run/secrets/twenty-db-password";
              };
            };

            storage = {
              type = mkOption {
                type = types.enum [ "local" "s3" ];
                default = "local";
                description = "Storage backend type";
              };

              s3 = {
                region = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "S3 region";
                };

                bucket = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "S3 bucket name";
                };

                endpoint = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "S3 endpoint (for S3-compatible services)";
                };
              };
            };

            auth = {
              google = {
                enabled = mkOption {
                  type = types.bool;
                  default = false;
                  description = "Enable Google authentication";
                };

                clientIdFile = mkOption {
                  type = types.nullOr types.path;
                  default = null;
                  description = "Path to file containing Google OAuth client ID";
                };

                clientSecretFile = mkOption {
                  type = types.nullOr types.path;
                  default = null;
                  description = "Path to file containing Google OAuth client secret";
                };
              };

              microsoft = {
                enabled = mkOption {
                  type = types.bool;
                  default = false;
                  description = "Enable Microsoft authentication";
                };

                clientIdFile = mkOption {
                  type = types.nullOr types.path;
                  default = null;
                  description = "Path to file containing Microsoft OAuth client ID";
                };

                clientSecretFile = mkOption {
                  type = types.nullOr types.path;
                  default = null;
                  description = "Path to file containing Microsoft OAuth client secret";
                };
              };
            };

            email = {
              driver = mkOption {
                type = types.nullOr (types.enum [ "smtp" ]);
                default = null;
                description = "Email driver";
              };

              fromAddress = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "Email from address";
              };

              fromName = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "Email from name";
              };

              smtp = {
                host = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "SMTP host";
                };

                port = mkOption {
                  type = types.nullOr types.port;
                  default = null;
                  description = "SMTP port";
                };

                userFile = mkOption {
                  type = types.nullOr types.path;
                  default = null;
                  description = "Path to file containing SMTP username";
                };

                passwordFile = mkOption {
                  type = types.nullOr types.path;
                  default = null;
                  description = "Path to file containing SMTP password";
                };
              };
            };
          };

          config = mkIf cfg.enable {
            # Twenty CRM configuration options are defined but implementation
            # is handled by the importing system (newton) which configures Arion
          };
        };
    };
}