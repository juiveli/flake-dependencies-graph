{
  description = "Nix Flake dependency graph generator";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11"; # Use a stable branch

    nix-dev-toolkit.url = "github:juiveli/nix-dev-toolkit";
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-dev-toolkit,
    }:
    let
      # The system architecture to build for (e.g., "x86_64-linux")
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # The shell script that contains your logic
      dependency-script = pkgs.writeShellScriptBin "gen-dep-graph" ''
        set -e

        JQ_LOGIC="${./flake-graph.jq}"
        OUTPUT_DOT="flake-dependencies.dot"
        OUTPUT_SVG="flake-dependencies.svg"

        if [ ! -f "flake.lock" ]; then
          echo "Error: flake.lock not found." >&2
          exit 1
        fi

        ${pkgs.jq}/bin/jq -r -f "$JQ_LOGIC" flake.lock > "$OUTPUT_DOT"

        echo "--- Converting DOT to SVG ---"
        # Use Graphviz (dot) to render the SVG image (-Tsvg)
        ${pkgs.graphviz}/bin/dot -Tsvg "$OUTPUT_DOT" -o "$OUTPUT_SVG"

        echo "--- Success! $OUTPUT_SVG created. ---"
        # Clean up the temporary DOT file
        rm "$OUTPUT_DOT"
      '';
    in
    {
      formatter = nix-dev-toolkit.formatter;
      checks = nix-dev-toolkit.checks;

      # 1. Define a development environment with the necessary tools
      devShells.${system}.default = pkgs.mkShell {
        packages = [
          pkgs.jq
          pkgs.graphviz
        ];
        # Add the script to the PATH in the development shell for easy execution
        shellHook = ''
          export PATH=$PATH:${pkgs.lib.getBin dependency-script}/bin
          echo "The 'gen-dep-graph' script is now available in this shell."
          echo "Run 'gen-dep-graph' to generate flake-dependencies.svg."
        '';
      };

      # 2. Define an application to run the script directly without entering a shell
      apps.${system}.default = {
        type = "app";
        program = "${dependency-script}/bin/gen-dep-graph";
      };
    };
}
