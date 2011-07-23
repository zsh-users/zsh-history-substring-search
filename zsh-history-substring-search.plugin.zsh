# This file integrates the zsh-history-substring-search script into oh-my-zsh.

source "$ZSH/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh"

if test "$CASE_SENSITIVE" = true; then
  unset HISTORY_SUBSTRING_SEARCH_GLOBBING_FLAGS
fi

if test "$DISABLE_COLOR" = true; then
  unset HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND
  unset HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND
fi
