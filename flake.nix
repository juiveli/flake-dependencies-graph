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

        OUTPUT_DOT="flake-dependencies.dot"
        OUTPUT_SVG="flake-dependencies.svg"

        if [ ! -f "flake.lock" ]; then
          echo "Error: flake.lock not found." >&2
          exit 1
        fi

        ${pkgs.jq}/bin/jq -r '
          def clean_nodes:
            .nodes | to_entries
            | map({
              key: .key,
              value: (if .value.inputs then .value.inputs else null end)
            })
          | from_entries;

          def resolve(map; parent_node; path):
            if (path | type) == "string" then map[parent_node][path] 
            elif (path | type) == "array" and (path | length) == 1 then map[parent_node][path[0]]
            elif (path | type) == "array" then resolve(map; map[parent_node][path[0]]; path[1:])
            else null end;

          def deep_resolve(map; parent_node; initial_path):
            initial_path | until((type != "array"); resolve(map; parent_node; .));

          def assembly_dot:
            (
            to_entries | map(
              .key as $parent |
              select(.value != null) |
              .value | to_entries | map(
                "  \"\($parent)\" -> \"\(.value)\""
              )
            ) | flatten | unique
          ) as $edges_array |
          ([ "digraph flake_dependencies {\n  rankdir=LR;\n" ] + $edges_array + ["\n}"]) | join("\n");
          
          clean_nodes as $map | $map |

          map_values(
            if . == null then null
            else map_values(if type == "array" then deep_resolve($map; "root"; .) else . end)
            end
          ) | assembly_dot

        ' flake.lock > $OUTPUT_DOT


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
