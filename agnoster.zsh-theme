# vim:ft=zsh ts=2 sw=2 sts=2
#
# agnoster's Theme - https://gist.github.com/3712874
# A Powerline-inspired theme for ZSH
#
# # README
#
# In order for this theme to render correctly, you will need a
# [Powerline-patched font](https://gist.github.com/1595572).
#
# In addition, I recommend the
# [Solarized theme](https://github.com/altercation/solarized/) and, if you're
# using it on Mac OS X, [iTerm 2](http://www.iterm2.com/) over Terminal.app -
# it has significantly better color fidelity.
#
# # Goals
#
# The aim of this theme is to only show you *relevant* information. Like most
# prompts, it will only show git information when in a git working directory.
# However, it goes a step further: everything from the current user and
# hostname to whether the last call exited with an error to whether background
# jobs are running in this shell will all be displayed automatically when
# appropriate.

### Segment drawing
# A few utility functions to make it easy and re-usable to draw segmented prompts

CURRENT_BG='NONE'
PRIMARY_FG=black

# Characters
SEGMENT_SEPARATOR="\ue0b0"
PLUSMINUS="\u00b1"
BRANCH="\ue0a0"
DETACHED="\u27a6"
CROSS="\u2718"
LIGHTNING="\u26a1"
GEAR="\u2699"

# Begin a segment
# Takes two arguments, background and foreground. Both can be omitted,
# rendering default background/foreground.
prompt_segment() {
  local bg fg
  [[ -n $1 ]] && bg="%K{$1}" || bg="%k"
  [[ -n $2 ]] && fg="%F{$2}" || fg="%f"
  if [[ $CURRENT_BG != 'NONE' && $1 != $CURRENT_BG ]]; then
    print -n "%{$bg%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR%{$fg%}"
  else
    print -n "%{$bg%}%{$fg%}"
  fi
  CURRENT_BG=$1
  [[ -n $3 ]] && print -n $3
}

# End the prompt, closing any open segments
prompt_end() {
  if [[ -n $CURRENT_BG ]]; then
    print -n "%{%k%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR"
  else
    print -n "%{%k%}"
  fi
  print -n "%{%f%}"
  CURRENT_BG=''
}

### Prompt components
# Each component will draw itself, and hide itself if no information needs to be shown

# Context: user@hostname (who am I and where am I)
prompt_context() {
  local user=`whoami`

  if [[ "$user" != "$DEFAULT_USER" || -n "$SSH_CONNECTION" ]]; then
    prompt_segment $PRIMARY_FG default " %(!.%{%F{yellow}%}.)$user@%m "
  fi
}

prompt_agnoster_check_git_arrows() {
	# reset git arrows
	prompt_agnoster_git_arrows=

	# check if there is an upstream configured for this branch
	command git rev-parse --abbrev-ref @'{u}' &>/dev/null || return 128

	local arrow_status
	# check git left and right arrow_status
	arrow_status="$(command git rev-list --left-right --count HEAD...@'{u}' 2>/dev/null)"
	# exit if the command failed
	(( !$? )) || return

	# left and right are tab-separated, split on tab and store as array
	arrow_status=(${(ps:\t:)arrow_status})
	local arrows left=${arrow_status[1]} right=${arrow_status[2]}

	(( ${right:-0} > 0 )) && arrows+="${GIT_DOWN_ARROW:-\u2193}${right}"
	(( ${left:-0} > 0 )) && arrows+="${GIT_UP_ARROW:-\u2191}${left}"

	[[ -n $arrows ]] && prompt_agnoster_git_arrows="${arrows}"
}

# async_git_fetch() {
  # GIT_TERMINAL_PROMPT=0 command git -c gc.auto=0 fetch
# }

# Git: branch/detached head, dirty status
prompt_git() {
  local color ref
  is_dirty() {
    test -n "$(git status --porcelain --ignore-submodules)"
  }
  ref="$vcs_info_msg_0_"
  if [[ -n "$ref" ]]; then
    # if [[ -n $(git remote show) ]]; then
    #   (
    #     async_job asyncw async_git_fetch
    #   )
    # fi
    git_changed_c=$(command git diff --name-status --diff-filter=ABCDMRTX | wc -l | tr -d "[[:space:]]")
    git_conflict_c=$(command git diff --name-status --diff-filter=U | wc -l | tr -d "[[:space:]]")
    git_staged_c=$(command git diff --staged --name-status | wc -l | tr -d "[[:space:]]")
    git_untracked_c=$(command git ls-files --others --exclude-standard $(git rev-parse --show-cdup) | wc -l | tr -d "[[:space:]]")
    git_stashed_c=$(command git stash list | wc -l | tr -d "[[:space:]]")
    if (( git_changed_c > 0 )) ; then git_changed="✚${git_changed_c}"; fi
    if (( git_conflict_c > 0 )) ; then git_conflict="✖${git_conflict_c}"; fi
    if (( git_staged_c > 0 )) ; then git_staged="●${git_staged_c}"; fi
    if (( git_untracked_c > 0 )) ; then git_untracked="…${git_untracked_c}"; fi
    if (( git_stashed_c > 0 )) ; then git_stashed="⚑${git_stashed_c}"; fi
    prompt_agnoster_check_git_arrows
    (( $? == 128)) && git_is_local="𝑳"

    if is_dirty; then
      prompt_segment green $PRIMARY_FG
      print -Pn "$prompt_agnoster_git_arrows$git_staged$git_conflict$git_changed$git_untracked$git_stashed"
      color=yellow
      ref="${ref}"
    else
      prompt_segment green $PRIMARY_FG
      print -Pn "$prompt_agnoster_git_arrows$git_staged$git_conflict$git_changed$git_untracked$git_stashed"
      color=green
      ref="${ref}"
    fi
    if [[ "${ref/.../}" == "$ref" ]]; then
      ref="$BRANCH$git_is_local $ref"
    else
      ref="$DETACHED ${ref/.../}"
    fi
    prompt_segment $color $PRIMARY_FG
    print -Pn " $ref "
  fi
}

# Dir: current working directory
prompt_dir() {
  prompt_segment blue $PRIMARY_FG ' %~ '
}

# Status:
# - was there an error
# - am I root
# - are there background jobs?
prompt_status() {
  local symbols
  symbols=()
  [[ $RETVAL -ne 0 ]] && symbols+="%{%F{red}%}$CROSS"
  [[ $UID -eq 0 ]] && symbols+="%{%F{yellow}%}$LIGHTNING"
  [[ $(jobs -l | wc -l) -gt 0 ]] && symbols+="%{%F{cyan}%}$GEAR"

  [[ -n "$symbols" ]] && prompt_segment $PRIMARY_FG default " $symbols "
}

## Main prompt
prompt_agnoster_main() {
  RETVAL=$?
  CURRENT_BG='NONE'
  prompt_status
  prompt_context
  prompt_dir
  prompt_git
  prompt_end
}

prompt_agnoster_precmd() {
  vcs_info
  PROMPT='%{%f%b%k%}$(prompt_agnoster_main) '
}

prompt_agnoster_setup() {
  autoload -Uz add-zsh-hook
  autoload -Uz vcs_info

  prompt_opts=(cr subst percent)

  add-zsh-hook precmd prompt_agnoster_precmd

  zstyle ':vcs_info:*' enable git
  zstyle ':vcs_info:*' check-for-changes false
  zstyle ':vcs_info:git*' formats '%b'
  zstyle ':vcs_info:git*' actionformats '%b (%a)'
}

prompt_agnoster_setup "$@"
