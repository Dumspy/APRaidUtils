{
  description = "APRaidUtils Lua tooling shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
    in {
      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in {
          default = pkgs.mkShell {
            packages = with pkgs; [
              fd
              git
              lua-language-server
              lua5_1
              lua51Packages.luacheck
              nixd
              ripgrep
              stylua
            ];

            shellHook = ''
              echo "APRaidUtils dev shell"
              echo "  lua-language-server  # LSP server"
              echo "  luac -p <file.lua>   # syntax check"
              echo "  luacheck <paths>     # lint first-party Lua"
              echo "  stylua <paths>       # format Lua"
            '';
          };
        });
    };
}
