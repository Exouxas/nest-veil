# nest-veil: turn on a workspace inside its directories and show its name in
# the right prompt while it's active.
status is-interactive; or exit
command -q nest-veil; or exit

function __nest_veil_hook --on-variable PWD
    command nest-veil --hook fish $PWD | source
end
__nest_veil_hook

# After new/set/unset, re-check the current directory right away.
function nest-veil --wraps nest-veil
    command nest-veil $argv
    set -l s $status
    if contains -- "$argv[1]" new set unset
        command nest-veil --hook fish $PWD refresh | source
    end
    return $s
end

if functions -q fish_right_prompt; and not functions -q __nest_veil_orig_right_prompt
    functions -c fish_right_prompt __nest_veil_orig_right_prompt
end

function fish_right_prompt
    if set -q NEST_VEIL
        set -l color magenta
        set -q NEST_VEIL_COLOR; and set color $NEST_VEIL_COLOR
        set_color --bold $color 2>/dev/null; or set_color --bold magenta
        set -q NEST_VEIL_LABEL; and printf '%s' $NEST_VEIL_LABEL; or printf '%s' $NEST_VEIL
        set_color normal
    end
    functions -q __nest_veil_orig_right_prompt; and __nest_veil_orig_right_prompt $argv
end
