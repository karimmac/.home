#!/bin/bash

GIT_PS1_SHOWDIRTYSTATE=1
GIT_PS1_SHOWSTASHSTATE=1
GIT_PS1_SHOWUNTRACKEDFILES=1
GIT_PS1_SHOWUPSTREAM=auto

if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

if [ -d /usr/local/etc/bash_completion.d ]; then
  for f in /usr/local/etc/bash_completion.d/*; do
    . $f
  done
fi

for f in git-completion.bash git-prompt.sh; do
  xcode=/Applications/Xcode.app/Contents/Developer/usr/share/git-core
  [ ! -f "$xcode/$f" ] || . "$xcode/$f"
  unset xcode
done

[ ! -f /usr/share/git-core/git-completion.bash ] || . /usr/share/git-core/git-completion.bash
[ ! -f /usr/share/git-core/git-prompt.sh ] || . /usr/share/git-core/git-prompt.sh

case $(type -t __git_ps1) in
  function)
    ;;
  *)
    __git_ps1 () { :; }
    ;;
esac

# Displays the current working directory with s/$HOME/~/, but truncates leading
# directories until either the string is -lt $maxlen, or we're left with only
# one pathname, in which case we just show it and forget about $maxlen.
PS1_MAX_CWDLEN=25
__ps1_cwd () {
  local maxlen=$PS1_MAX_CWDLEN
  local dir=${PWD/$HOME/'~'}
  local ddd=""
  while [ ${#dir} -gt $maxlen ]; do
    ddd="…/"
    local trimmed=${dir#*/}
    if [ "$trimmed" = "$dir" ]; then break; fi
    dir=$trimmed
  done
  echo "${ddd}${dir}"
}

__ps1_prompt () {
  local GREEN='\[\033[01;32m\]'
  local YELLOW='\[\033[01;33m\]'
  local CYAN='\[\033[01;36m\]'
  local BLUE='\[\033[01;34m\]'
  local RED='\[\033[01;31m\]'
  local RESET='\[\033[00m\]'
  PS1="$GREEN"'[\u@'"$YELLOW"'\h'"$BLUE"' \t'"$CYAN"' $(__ps1_cwd)'"$RED"'$(__git_ps1 " (%s)")'"$GREEN"']\$ '"$RESET"
}
__ps1_prompt
unset __ps1_prompt

# "ep": (+) append, prepend(^) or remove(-) dirs in a "PATH" var (colon-separated list).
#       - save original var value as "ORIG_var" (the first time)
#       - remove duplicates; lets you shuffle dirs to front or back.
#       - do NOT append dir if it doesn't exist -- useful across multi platforms.
# ep accepts multiple dirs, but processes them left-to-right,
#   so "^dir" ops are prepended in the counterintuitive (reverse) order.

# 20141121 Karim MacDonald
# 'Temporarily' commented out as it doesn't work under git on Windows at least.

# ep () {
#   typeset args="$*" dir op val front var
#
#   case "$1" in [-+^]*) var=PATH ;; [A-Z_a-z]*) var=$(env | sed -n "/^$1[A-Z_0-9]*PATH=/{s/=.*//p;q;}"); shift ;;
#     *) echo >&2 'Usage: ep [var] [-+^]dir...'; return
#   esac
#   if [ -z "$var" ]; then echo >&2 "ep: unknown *path variable"; return; fi
#   if [ $# = 0 ]; then path $var; return; fi
#
#   eval "val=:\$$var:; test \"\$ORIG_$var\" || export ORIG_$var=\"\$$var\""
#   test :: != $val || val=:
#   for dir; do
#     case $dir in -?*) op=- ;; ^?*) op=^ ;; +?*) op=+ ;; *) continue; esac
#     eval dir=${dir#$op}         # Ensures ~ is expanded
#     test -z $dir || val=${val//:$dir:/:}
#     if [ -d $dir -o -L $dir ]; then
#       case $op in [-!]) ;; ^) val=:$dir$val ;; +) val=$val$dir: ;; esac
#     fi
#   done
#
#   val=${val%:}        # trailing :
#   val=${val#:}        # leading :
#   eval $var=$val
# }

lc () {
  tr [:upper:] [:lower:] "$@"
}

# how   Like "which", but finds aliases/bash-fns and perl modules.
#       Expands symlinks and shows file type.
how () {
  PATH=$PATH  # reset path search
  shopt -s extdebug
  typeset -F $1 2>&- \
  || alias $1 2>&- \
  || case $1 in *::*)
    perl -m$1 -e '($x="'$1'")=~s|::|/|g; print $INC{"$x.pm"}."\n"'
    ;;
   *)
    local w=$(which $1)
    if [ "$w" ]; then
      local r=$(realpath $w)
      test $w = $r || echo -n "$w -> "
      file $r | sed s/,.*//
    fi
   esac
  shopt -u extdebug
}

path () {
    typeset var=${1:-PATH}
    eval "env |egrep -i ^$var[a-z_0-9]*=[^\(]" | sed '/=(/!{s|=|:|; s|:|\
    |g; s|'$HOME'|~|g; }'
}

# wi    Edit a script in $PATH. Chains through symlinks.
#       Also: edit aliases and bash-fns in file from which they were sourced.
wi () {
  EDITOR=${EDITOR:-vim}
  PATH=$PATH  # Forced reset of path cache
  if alias $1 2>&- && egrep -q ^alias.$1 ~/.bashrc
  then $EDITOR +/"alias.$1" ~/.bashrc; . ~/.bashrc
  elif typeset -F $1 >/dev/null
  then shopt -s extdebug; set -- $(typeset -F $1); shopt -u extdebug
    # With extdebug on, "typeset -F" prints: funcname lineno filename
    $EDITOR +$2 $3; . $3
  else    set -- $(echo $(which $1))
    if [ $# -gt 0 ]
    then
      set -- $(file -L $1)
      case "$*" in
        *\ script*|*\ text*) $EDITOR ${1%:} ;;
        *)                   echo >&2 $*
    esac
  fi
fi
}

hi () {
  term=$1; shift
  [ -n "$term" ] || {
    echo -e "Usage: hi perl-regexp\nHighlight a term in a stream of text" 1>&2;
    return 1
  };
  if [ -z "$*" ]; then set /dev/stdin; fi
  perl -pe 'BEGIN{$a=shift}s/$a/\e[31m$&\e[0m/g' "$term" "$@"
}

b64 () {
  echo -n "$@" ---- | tr - = | base64 -D; echo
}

pi () {
  cpanm -S "$@"
}

trim () { echo $1; }

tmx () {
  local session=$1; shift

  count=$(tmux ls | grep "^$session" | wc -l)
  if [[ "$(trim $count)" = 0 ]]; then
    echo "Launching new session $session..."
    tmux new-session -d -s $session
  fi

  count=$(tmux list-windows -t $session | grep -w log | wc -l)
  if [[ "$(trim $count)" = 0 ]]; then
    tmux new-window -d -n log -t $session:9 'tail -40F /var/log/system.log'
  fi

  tmux attach-session -t $session
}

tmux_buffer () {
  tmux show-buffer -b 0 >/dev/null 2>&1 || tmux set-buffer foo
  # Arbitrarily assume a history-limit of 2000 lines.
  tmux capture-pane -b 0 -J -S -2000 "$@"
  tmux show-buffer -b 0
}

psgrep () {
  ps axuwww | grep -i "$@"
}
pslsof () {
  sudo lsof -p $(psgrep "$@" | perl -lane 'push @L,$F[1];END{print join",",@L}' )
}
pskill () {
  psgrep "$@" | awk '{print $2}' | sudo xargs kill -KILL 2>/dev/null
}
psterm () {
  psgrep "$@" | awk '{print $2}' | sudo xargs kill -TERM 2>/dev/null
}
hup () {
  psgrep "$@" | awk '{print $2}' | sudo xargs kill -HUP 2>/dev/null
}

reload_bashrc() {
  source ~/.bashrc
}

git_repo_is_clean () {
  if ! git diff-index --cached --quiet HEAD --; then
    echo "You have staged changes; commit them first"
    return 1
  fi
  if ! git diff --no-ext-diff --quiet --exit-code; then
    echo "You have modified files in your workspace; commit them first"
    return 1
  fi
  if [ -n "$(git ls-files --others --exclude-standard)" ]; then
    echo "You have untracked files in your workspace; commit or delete them first"
    return 1
  fi
}

function vo() {
  (cd "$(git rev-parse --show-toplevel)" && vim -p $(git status -z | tr '\000' '\n' | grep -E '^([AMR]. |\?\? )' | cut -c 4-))
}

function vl() {
  (cd "$(git rev-parse --show-toplevel)" && vim -p $(git show --name-status | grep -E '^[AM]\t' | cut -f 2))
}

if [[ ! -f /usr/local/bin/idea ]]; then
  idea () {
    echo Get a better launcher from IntelliJ 13.1 and later: Tools =\> Create Command-line Launcher...
    open -a /Applications/IntelliJ\ IDEA\ 13.app/ `cd "${@-.}"; pwd`
  }
fi

function _cache_git_dirs() {
  local git_root=~/g
  [[ -z $__GIT_DIRS ]] && __GIT_DIRS=$(cd $git_root && find . -maxdepth 5 -type d -path "*/.git" | sed "s,^.,$git_root,g")
}

# cd into a git repo under ~/g
function cgd() {
  local git_dir

  _cache_git_dirs
  git_dir=$(grep "/${1}/\.git$" <<< "$__GIT_DIRS" | head -n1)
  [[ ! -d "$git_dir" ]] || cd "${git_dir}/.."
}

function _cgd() {
  local cur=${COMP_WORDS[COMP_CWORD]}
  local words=""
  local git_dir

  _cache_git_dirs
  while read git_dir; do
    git_dir=$(dirname "$git_dir")
    words="${words} ${git_dir##*/}"
  done < <(grep "/${cur}.*/\.git$" <<< "$__GIT_DIRS")
  COMPREPLY=( $(compgen -W "$words" -- $cur) )
}

function jira_issues() {
  perl -lne '$ISSUES{$1}++ if /\b(C[A-Z]+-\d+)\b/; END { print "$_" for sort keys %ISSUES }'
}

alias jira-issues=jira_issues

function _ssh_autocomplete() {
  local cur=${COMP_WORDS[COMP_CWORD]}
  local words=""

  local ssh_config_file="${HOME}/.ssh/config"
  if [[ -f $ssh_config_file ]]; then
    while read key value; do
      if [[ $key == 'Host' ]]; then
        words="${words} $value"
      fi
    done < "$ssh_config_file"
  fi

  local known_hosts_file="${HOME}/.ssh/known_hosts"
  if [[ -f $known_hosts_file ]]; then
    while read host_or_ip _; do
      host_or_ip=${host_or_ip//[/}
      host_or_ip=${host_or_ip//]/}
      host_or_ip=${host_or_ip//,/ }
      words="${words} ${host_or_ip}"
    done < "$known_hosts_file"
  fi

  COMPREPLY=( $(compgen -W "$words" -- $cur) )
}

complete -F _ssh_autocomplete ssh

alias cdg=cgd
complete -F _cgd cgd
complete -F _cgd cdg

if ls --color=auto &>/dev/null; then
    alias ls='ls --color=auto'
fi
alias ll='ls -l'
alias la='ls -al'
alias l='less -S'
alias g='git'

# Make sure completion works for alias g=git, too
complete -o bashdefault -o default -o nospace -F _git g 2>/dev/null \
        || complete -o default -o nospace -F _git g

export P4EDITOR='vim +"set ft=p4"'
export P4USER='KarimMacDonald'

export COLORTERM=1
export CLICOLOR=1
if grep --color 'a' <<< 'a' &>/dev/null; then
    export GREP_COLOR='1;31'
    export GREP_OPTIONS='--color=auto'
fi
export PS1

# Manipulate $PATH
# 20141121 Karim MacDonald 'Temporarily' comment out until I have a working ep on Windows.

# ep +~/bin

# First, we ensure that Gemfile.lock didn't get changed (and nor did anything else).
# Then, we run all tests.
# Then, we check that the tests didn't change or add any files to the working directory.
# Then, we push!
alias rp="git_repo_is_clean && bundle exec rake && git_repo_is_clean && git push"

# THIS MUST ALWAYS BE THE LAST LINE...
# Source custom .bash init scripts.
[ ! -f ~/.bash_custom ] || . ~/.bash_custom

# vim: set ft=sh:
