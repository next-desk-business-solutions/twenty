{
  description = "Twenty CRM - Arion configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    arion.url = "github:hercules-ci/arion";
    arion.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, arion }:
    {
      # Export the nixos modules for easy importing
      nixosModules.default = {
        imports = [
          arion.nixosModules.arion
        ];

        virtualisation.arion.projects.twenty = {
          serviceName = "twenty";
          settings = {
            imports = [ ./arion-compose.nix ];
          };
        };
      };
    };
}