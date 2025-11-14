# Overview
This project creates an **automatic visualization** of your Nix Flake dependencies by iterating over the **`flake.lock`** file.

It uses **`jq`** in the background to convert the dependency hierarchy into a parent-to-consumed-flake notation (`Source -> Target`). This output is saved as a **DOT file**, which is then processed by **`graphviz`** to generate a scalable **`.svg`** image.

# Running

**`nix run github:juiveli/flake-dependencies-graph -- `**

# Output
![Dependency Graph](./flake-dependencies.svg)
## Note
The graph identifies and combines identical locked dependencies (those with the same narHash). In the example above, multiple inputs happen to reference the different version of nixpkgs, and they are correctly consolidated into a multiple nodes.

Note on Dependency Merging

This tool is designed purely for visualization purposes.

Do not use this output as a basis for identifying dependencies that can be manually merged. For dedicated analysis of dependency deduplication and version conflicts, consider using a dedicated tool like [flint](https://github.com/notashelf/flint).
