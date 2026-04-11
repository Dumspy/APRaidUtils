{
  description = "APRaidUtils Lua tooling shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    wow-api.url = "github:Ketho/vscode-wow-api";
    wow-api.flake = false;
  };

  outputs = {
    nixpkgs,
    flake-utils,
    wow-api,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs { inherit system; };
        wow-api-path = "${wow-api}/Annotations/Core";
      in {
        devShells = {
          default = pkgs.mkShell {
            packages = with pkgs; [
              lua-language-server
              lua5_1
              lua51Packages.luacheck
              stylua
            ];

            shellHook = ''
              # Copy WoW API annotations to local folder for editor/agent access
              mkdir -p .lua-libs
              chmod -R +w .lua-libs/wow-api 2>/dev/null || true
              rm -rf .lua-libs/wow-api
              cp -r "${wow-api-path}" .lua-libs/wow-api
              echo "WoW API annotations: .lua-libs/wow-api"
            '';
          };
        };
      }
    );
}
