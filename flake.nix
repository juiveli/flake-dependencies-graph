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
        # The JQ script is stored in a shell variable for clarity
        JQ_SCRIPT='
        .nodes as $nodes |
        # 1. CALCULATE THE CANONICAL MAP ($map)
        (
          $nodes | to_entries |
          group_by(.value.locked.type + "_" + (.value.locked.narHash // .value.locked.path // "no-hash-no-path")) |
          map({canonical: .[0].key, members: map(.key)}) |
          reduce .[] as $group ({}; . + ($group.members | map({(.): $group.canonical}) | add))
        ) as $map |

        # 2. IDENTIFY ALL CANONICAL TARGETS (Phase 2 not strictly needed for DOT generation, removed for brevity/simplicity)

        # 3. GENERATE AND STORE EDGES ($edges_array)
        (
          $nodes | to_entries |
          map(
            select(.value.inputs != null) |
            . as $p |
            .value.inputs |
            to_entries |
            map(
              .key as $alias |
              .value as $dep_id |

              # Determine the single target ID for canonicalization (same logic as Phase 2)
              ($dep_id | if type == "array" then $alias else $dep_id end) as $target_id |

              # Build the edge: Source (canonical) -> Target (canonical)
              "  \"\( ($map[$p.key] // $p.key) )\" -> \"\( ($map[$target_id] // $target_id) )\""
            )
          ) |
          flatten |
          unique
        ) as $edges_array |

        # 4. ASSEMBLE DOT FILE CONTENT
        [
          "digraph flake_dependencies {\n  rankdir=LR;\n"
        ] +
        $edges_array +
        [
          "\n}"
        ] |
        join("\n")
        '

        # Check if flake.lock exists
        if [ ! -f "flake.lock" ]; then
          echo "Error: flake.lock not found in the current directory." >&2
          exit 1
        fi

        OUTPUT_DOT="flake-dependencies.dot"
        OUTPUT_SVG="flake-dependencies.svg"

        echo "--- Generating DOT file from flake.lock ---"

        # Use jq to generate the DOT content directly
        cat flake.lock | ${pkgs.jq}/bin/jq -r "$JQ_SCRIPT" > "$OUTPUT_DOT"

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
