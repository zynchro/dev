.hooks.Stop |= (map(.hooks |= map(select(.command != $c))) | map(select(.hooks | length > 0)))
| if (.hooks.Stop | length) == 0 then del(.hooks.Stop) else . end
| if (.hooks | length) == 0 then del(.hooks) else . end
