

 

  nix-shell -p jq graphviz --run '
  echo "--- Generating Flake Input DOT File with Filter ---"
  
  JQ_SCRIPT='.nodes as $nodes | 

# 1. CALCULATE THE CANONICAL MAP (from JQ_GROUPS)
# This result is stored in the $map variable.
(
  $nodes | to_entries | 
  group_by(.value.locked.type + "_" + (.value.locked.narHash // .value.locked.path // "no-hash-no-path") ) | 
  map({canonical: .[0].key, members: map(.key)}) | 
  reduce .[] as $group ({}; . + ($group.members | map({(.): $group.canonical}) | add))
) as $map | 

# 2. GENERATE AND REWRITE EDGES (modified JQ_SCRIPT)
$nodes | to_entries | map(
    select(.value.inputs != null) | 
    . as $parent | 
    .value.inputs | 
    to_entries | 
    map(
        # Source Key: Look up $parent.key in $map, or default to $parent.key
        # Target Key: Look up .key in $map, or default to .key
        "  \"\( ($map[$parent.key] // $parent.key) )\" -> \"\( ($map[.key] // .key) )\""
    )
) | flatten | unique | join("\n")'


  
  # 1. Create DOT file header
  echo "digraph flake_dependencies {" > flake-dependencies.dot
  
  # 2. Use jq to generate the input connections and append them
  cat flake.lock | jq -r "$JQ_SCRIPT" >> flake-dependencies.dot
  
  # 3. Create DOT file footer
  echo "}" >> flake-dependencies.dot

  echo "--- Converting DOTnodes to SVG ---"
  # 4. Use Graphviz (dot) to render the SVG image (-Tsvg)
  dot -Tsvg flake-dependencies.dot -o flake-dependencies.svg
  
  echo "--- Success! flake-dependencies.svg created. ---"
  # Clean up the temporary DOT file
  rm flake-dependencies.dot
'







JQ_SCRIPT='.nodes as $nodes | 

# 1. CALCULATE THE CANONICAL MAP ($map)
(
  $nodes | to_entries | 
  group_by(.value.locked.type + "_" + (.value.locked.narHash // .value.locked.path // "no-hash-no-path")) | 
  map({canonical: .[0].key, members: map(.key)}) | 
  reduce .[] as $group ({}; . + ($group.members | map({(.): $group.canonical}) | add))
) as $map | 

# 2. IDENTIFY ALL CANONICAL TARGETS ($target_keys)
(
  $nodes | to_entries | 
  map(
    select(.value.inputs != null) | 
    .value.inputs | 
    to_entries | 
    map(
      .key as $alias |
      .value as $dep_id |
      
      # Use the alias ($alias) for canonical lookup if the value is an array (follows),
      # otherwise use the dependency ID string ($dep_id).
      ($dep_id | if type == "array" then $alias else $dep_id end) |
      
      # Canonicalize the resulting ID
      ($map[.] // .)
    )
  ) | 
  flatten | 
  unique
) as $target_keys | 

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



nix eval --json --flake .#nixosConfigurations.quadlet-test.config --apply builtins.toJSON