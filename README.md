# Overview

This project creates an **automatic visualization** of your Nix Flake dependencies by iterating over the **`flake.lock`** file.

It uses **`jq`** in the background to convert the dependency hierarchy into a parent-to-consumed-flake notation (`Source -> Target`). This output is saved as a **DOT file**, which is then processed by **`graphviz`** to generate a scalable **`.svg`** image.

# Running
Run the following command in the root of your project (where your `flake.lock` is located):

**`nix run github:juiveli/flake-dependencies-graph -- `**

# Output
The tool generates a file named flake-dependencies.svg. Example is from this repos flake.lock file
![Dependency Graph](./flake-dependencies.svg)

## Technical Notes

### Merging: 
Two dependencies (boxes) are shown as the same node only if the follows keyword is used to explicitly de-duplicate them.
This is the case with precommithooks and gitignore using same nixpkgs. 

### Coincidental Identity: 
It is possible for two dependencies to point to the exact same Git hash "by chance." If they do not use follows, they will appear as separate boxes in the graph. This reflects how Nix treats them as independent inputs unless told otherwise.


### Purpose and limitations

This tool is designed purely for visualization and architectural overview.

Do not use this output as the primary basis for identifying dependencies that should be manually merged. For dedicated analysis of dependency deduplication and version conflicts, consider using a specialized tool like [flint](https://github.com/notashelf/flint).
