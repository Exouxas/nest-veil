function __nest_veil_args
    set -l t (commandline -opc)
    set -e t[1]
    printf '%s\n' $t
end

function __nest_veil_at -a sub n
    set -l t (__nest_veil_args)
    test "$t[1]" = "$sub"; and test (count $t) -eq $n
end

complete -c nest-veil -f
complete -c nest-veil -n __fish_is_first_arg -a '(command nest-veil --names)' -d workspace
complete -c nest-veil -n __fish_is_first_arg -a new -d 'create a workspace'
complete -c nest-veil -n __fish_is_first_arg -a set -d 'auto-enable a workspace in a directory'
complete -c nest-veil -n __fish_is_first_arg -a unset -d 'stop auto-enabling in a directory'
complete -c nest-veil -n __fish_is_first_arg -a off -d 'run outside any workspace'
complete -c nest-veil -n __fish_is_first_arg -l help -d 'show help'
complete -c nest-veil -n __fish_is_first_arg -l version -d 'show version'
complete -c nest-veil -n '__nest_veil_at set 1' -a '(command nest-veil --names)' -d workspace
complete -c nest-veil -n '__nest_veil_at set 2' -a '(__fish_complete_directories)'
complete -c nest-veil -n '__nest_veil_at unset 1' -a '(__fish_complete_directories)'
complete -c nest-veil -n 'not __fish_is_first_arg; and not contains -- (__nest_veil_args)[1] new set unset' \
    -xa '(__fish_complete_subcommand --fcs-skip=2)'
