# This file configures zsh-history-substring-search as a plugin so it can
# be loaded by oh-my-zsh-compatible ZSH frameworks like zgen, antigen and
# zplug.

source "${0:r:r}.zsh"

if test "$CASE_SENSITIVE" = true; then
  unset HISTORY_SUBSTRING_SEARCH_GLOBBING_FLAGS
fi

if test "$DISABLE_COLOR" = true; then
  unset HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND
  unset HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND
fi
