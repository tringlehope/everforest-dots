set -g fish_greeting ""

# Палитра подсветки синтаксиса Everforest Dark Soft
set -g fish_color_normal d3c6aa
set -g fish_color_command a7c080
set -g fish_color_keyword e67e80
set -g fish_color_quote dbbc7f
set -g fish_color_redirection 7fbbb3
set -g fish_color_end 83c092
set -g fish_color_error e67e80
set -g fish_color_param d3c6aa
set -g fish_color_comment 859289
set -g fish_color_operator 7fbbb3
set -g fish_color_escape d699b6
set -g fish_color_autosuggestion 859289
set -g fish_pager_color_completion d3c6aa
set -g fish_pager_color_description 859289
set -g fish_pager_color_prefix a7c080
set -g fish_pager_color_progress dbbc7f

alias ls='ls --color=auto'
alias ll='ls -lah --color=auto'

starship init fish | source
