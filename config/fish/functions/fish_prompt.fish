function fish_prompt
    set -l last_status $status
    set -l cwd (prompt_pwd)

    echo ""
    set_color a7c080
    echo -n " 󰉋  $cwd "

    set -l branch (git branch --show-current 2>/dev/null)
    if test -n "$branch"
        set_color dbbc7f
        echo -n "  $branch"
        if test -n "(git status --porcelain 2>/dev/null)"
            set_color e67e80
            echo -n "*"
        end
        echo -n " "
    end

    if test $last_status -ne 0
        set_color e67e80
        echo -n " [$last_status] "
    end

    echo ""
    set_color 7fbbb3
    echo -n " ❯ "
    set_color normal
end
