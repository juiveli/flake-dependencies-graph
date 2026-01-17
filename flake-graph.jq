# flake-graph.jq

# 1. Preparation: Extract raw node/input mapping
def clean_nodes:
  .nodes | to_entries
  | map({
      key: .key,
      value: (if .value.inputs then .value.inputs else null end)
    })
  | from_entries;

# 2. Logic Helpers: Recursive resolution of "follows" paths
def resolve(map; parent_node; path):
  if (path | type) == "string" then map[parent_node][path] 
  elif (path | type) == "array" and (path | length) == 1 then map[parent_node][path[0]]
  elif (path | type) == "array" then resolve(map; map[parent_node][path[0]]; path[1:])
  else null end;

def deep_resolve(map; parent_node; initial_path):
  initial_path | until((type != "array"); resolve(map; parent_node; .));

# 3. Resolution Logic
def resolve_all_inputs(lookup_table):
  map_values(
    if . == null then null
    else map_values(if type == "array" then deep_resolve(lookup_table; "root"; .) else . end)
    end
  );

# 4. Presentation: Assembly into DOT format
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
  ([ "digraph flake_dependencies {\n  rankdir=LR;\n" ] 
   + $edges_array + ["\n}"]) | join("\n");

# 5. Main Orchestration
def main:
  clean_nodes as $map 
  | $map 
  | resolve_all_inputs($map) 
  | assembly_dot;

main