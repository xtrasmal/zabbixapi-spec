# lint/rules-7.0.jq — Zabbix 7.0 API JSON Schema convention rules.
#
# Input : one schema document (a single schemas/7.0/<object>/<object>.<method>.json).
# Args  : --arg object <object>   --arg method <method>
# Output: one line per convention violation. No output means the file is clean.
#
# Reused by lint-7.0.sh. A copy lives at ~/.claude/helpers/jq/zabbix-schema-lint.jq.

def want($cond; $msg): if $cond then empty else $msg end;

[
  want(.["$schema"] == "https://json-schema.org/draft/2020-12/schema";
       "$schema must be draft 2020-12 (got \(.["$schema"] // "null"))"),

  want(.["$id"] == "https://zabbix.com/7.0/api/\($object)/\($object).\($method)";
       "$id must be https://zabbix.com/7.0/api/\($object)/\($object).\($method) (got \(.["$id"] // "null"))"),

  want(.title == "\($object).\($method)";
       "title must be \($object).\($method) (got \(.title // "null"))"),

  want((.description | type) == "string" and (.description | length) > 0;
       "description must be a non-empty string"),

  want((.["$comment"] // "") | test("Source: https://www\\.zabbix\\.com/documentation/7\\.0/en/manual/api/reference/");
       "$comment must cite the doc Source URL"),

  want((has("type")) or (has("oneOf"));
       "top level must declare \"type\" or \"oneOf\""),

  # object schemas are strict — unknown params are rejected
  want(.type != "object" or .additionalProperties == false;
       "object schema must set additionalProperties:false"),

  # delete-style schemas: a non-empty array of id strings.
  # Exception: the empty-params form (maxItems:0), e.g. user.logout.
  want(.type != "array"
       or (.maxItems == 0)
       or ((.items.type == "string") and has("minItems"));
       "array schema needs items.type:string and minItems (or maxItems:0 for empty params)")
] | .[]
