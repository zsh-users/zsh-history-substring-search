#!/usr/bin/env zsh
#
# This is a clean-room implementation of the Fish[1] shell's history search
# feature, where you can enter any part of any previous command and press
# the UP and DOWN arrow keys to cycle through all matching commands.
#
# This was originally implemented by Peter Stephenson[2], who published it to
# the ZSH users mailing list (thereby making it public domain) in September
# 2009.  It was later revised by Guido van Steen and released under the BSD
# license (see below) as part of the fizsh[3] project in January 2011.
#
# This was later extracted from fizsh[3] release 1.0.1, refactored heavily,
# and repackaged as an OH MY ZSHELL plugin[4] by Suraj N. Kurapati in 2011.
#
# [1] http://fishshell.com
# [2] http://www.zsh.org/mla/users/2009/msg00818.html
# [3] http://sourceforge.net/projects/fizsh/
# [4] https://github.com/robbyrussell/oh-my-zsh/pull/215
#
# -------------------------------------------------------------------------------------------------
# Copyright (c) 2011 Guido van Steen
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification, are permitted
# provided that the following conditions are met:
#
#  * Redistributions of source code must retain the above copyright notice, this list of conditions
#    and the following disclaimer.
#  * Redistributions in binary form must reproduce the above copyright notice, this list of
#    conditions and the following disclaimer in the documentation and/or other materials provided
#    with the distribution.
#  * Neither the name of the FIZSH nor the names of its contributors may be used to endorse or
#    promote products derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
# FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
# IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
# OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# -------------------------------------------------------------------------------------------------
# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et

setopt extendedglob
zmodload -F zsh/parameter

HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND='bg=magenta,fg=white,bold'
HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND='bg=red,fg=white,bold'
HISTORY_SUBSTRING_SEARCH_GLOBBING_FLAGS='i' # see "Globbing Flags" in zshexpn(1)

history-substring-search-begin() {
  # continue using the previous "$history_substring_search_result" by default,
  # unless the current query was cleared or a new/different query was entered
  if [[ -z $BUFFER || $BUFFER != $history_substring_search_result ]]; then
    # $BUFFER contains the text that is in the command-line currently.
    # we put an extra "\\" before meta characters such as "\(" and "\)",
    # so that they become "\\\(" and "\\\)"
    history_substring_search_query_escaped=${BUFFER//(#m)[\][()\\*?#<>~^]/\\$MATCH}

    # for the purpose of highlighting we will also keep a version without
    # doubly-escaped meta characters
    history_substring_search_query=${BUFFER}

    # find all occurrences of the pattern *${query}* within the history file
    # (k) turns it an array of line numbers. (on) seems to remove duplicates.
    # (on) are default options. they can be turned off by (ON).
    history_substring_search_matches=(${(kon)history[(R)(#$HISTORY_SUBSTRING_SEARCH_GLOBBING_FLAGS)*${history_substring_search_query_escaped}*]})

    # define the range of value that $history_substring_search_match_number
    # can take: [0, $history_substring_search_number_of_matches_plus_one]
    history_substring_search_number_of_matches=${#history_substring_search_matches}
    let "history_substring_search_number_of_matches_plus_one = $history_substring_search_number_of_matches + 1"
    let "history_substring_search_number_of_matches_minus_one = $history_substring_search_number_of_matches - 1"

    # initial value of $history_substring_search_match_number, which can
    # initially only be decreased by ${WIDGET/forward/backward}
    let "history_substring_search_match_number = $history_substring_search_number_of_matches_plus_one"
  fi
}

history-substring-search-highlight() {
  # clear previously applied search query highlighting
  region_highlight=()

  # highlight $BUFFER using zsh-syntax-highlighting plugin
  # https://github.com/nicoulaj/zsh-syntax-highlighting
  if [[ $+functions[_zsh_highlight-zle-buffer] -eq 1 ]]; then
    _zsh_highlight-zle-buffer
  fi

  if [[ -n $history_substring_search_query ]]; then
    # history_substring_search_query_escaped string was not empty: highlight it
    # among other things, the following expression yields a variable $MEND,
    # which indicates the end position of the first occurrence of
    # $history_substring_search_query_escaped in $BUFFER
    : ${(S)BUFFER##(#m$HISTORY_SUBSTRING_SEARCH_GLOBBING_FLAGS)($history_substring_search_query##)}
    let "history_substring_search_query_mbegin = $MEND - $#history_substring_search_query"
    # this is slightly more informative than highlighting that fish performs
    region_highlight+=("$history_substring_search_query_mbegin $MEND $1")
  fi
}

history-substring-search-end() {
  history_substring_search_result=$BUFFER

  # "zle .end-of-line" does not move CURSOR to the final end of line in
  # multi-line buffers.
  [[ $history_substring_search_move_cursor_eol == true ]] && CURSOR=${#BUFFER}

  # for debugging purposes:
  #zle -R "mn: "$history_substring_search_match_number" m#: "${#history_substring_search_matches}
  #read -k -t 200 && zle -U $REPLY

  true
}

history-substring-search-backward() {
  history-substring-search-begin

  # check if the UP arrow was pressed to move cursor in multi-line buffer:
  # First create XLBUFFER (i.e. Xtended LBUFFER). Add an X before the cursor,
  # so that we can later detect whether there is a newline immediately before
  # the current cursor.
  buflines=(${(f)BUFFER})
  local XLBUFFER=$LBUFFER"x"
  xlbuflines=(${(f)XLBUFFER})

  if [[ $#buflines -gt 1 && $#xlbuflines -ne 1 && $#BUFFER -ne $#LBUFFER ]]; then
    zle up-line-or-history
    history_substring_search_move_cursor_eol=false
  else
    if [[ $history_substring_search_match_number -ge 2 && $history_substring_search_match_number -le $history_substring_search_number_of_matches_plus_one ]]; then
      let "history_substring_search_match_number = $history_substring_search_match_number - 1"
      history_substring_search_command_to_be_retrieved=$history[$history_substring_search_matches[$history_substring_search_match_number]]
      BUFFER=$history_substring_search_command_to_be_retrieved
      history-substring-search-highlight $HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND
    else
      if [[ $history_substring_search_match_number -eq 1 ]]; then
        # we will move out of the history_substring_search_matches
        let "history_substring_search_match_number = $history_substring_search_match_number - 1"
        history_substring_search_old_buffer_backward=$BUFFER
        BUFFER=$history_substring_search_query
        history-substring-search-highlight $HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND
      else
        if [[ $history_substring_search_match_number -eq $history_substring_search_number_of_matches_plus_one ]]; then
          # we will move back to the history_substring_search_matches
          let "history_substring_search_match_number = $history_substring_search_match_number - 1"
          BUFFER=$history_substring_search_old_buffer_forward
          history-substring-search-highlight $HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND
        fi
      fi
    fi
    history_substring_search_move_cursor_eol=true
  fi

  history-substring-search-end
}

history-substring-search-forward() {
  history-substring-search-begin

  # check if the DOWN arrow was pressed to move cursor in multi-line buffer:
  # First create XRBUFFER (i.e. Xtended RBUFFER). Add an X after the cursor,
  # so that we can later detect whether there is a newline immediately behind
  # the current cursor.
  buflines=(${(f)BUFFER})
  local XRBUFFER="x"$RBUFFER
  xrbuflines=(${(f)XRBUFFER})

  if [[ $#buflines -gt 1 && $#xrbuflines -ne 1 && $#BUFFER -ne $#LBUFFER ]]; then
    zle down-line-or-history
    history_substring_search_move_cursor_eol=false
  else
    if [[ $history_substring_search_match_number -eq $history_substring_search_number_of_matches_plus_one ]]; then
      let "history_substring_search_match_number = $history_substring_search_match_number"
      history_substring_search_old_buffer_forward=$BUFFER
      BUFFER=$history_substring_search_query
      history-substring-search-highlight $HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND
    elif [[ $history_substring_search_match_number -ge 0 && $history_substring_search_match_number -le $history_substring_search_number_of_matches_minus_one ]]; then
      let "history_substring_search_match_number = $history_substring_search_match_number + 1"
      history_substring_search_command_to_be_retrieved=$history[$history_substring_search_matches[$history_substring_search_match_number]]
      BUFFER=$history_substring_search_command_to_be_retrieved
      history-substring-search-highlight $HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND
    else
      if [[ $history_substring_search_match_number -eq $history_substring_search_number_of_matches ]]; then
        let "history_substring_search_match_number = $history_substring_search_match_number + 1"
        history_substring_search_old_buffer_forward=$BUFFER
        BUFFER=$history_substring_search_query
        history-substring-search-highlight $HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND
      else
        if [[ $history_substring_search_match_number -eq 0 ]]; then
          let "history_substring_search_match_number = $history_substring_search_match_number + 1"
          BUFFER=$history_substring_search_old_buffer_backward
          history-substring-search-highlight $HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND
        fi
      fi
    fi
    history_substring_search_move_cursor_eol=true
  fi

  history-substring-search-end
}

zle -N history-substring-search-backward
zle -N history-substring-search-forward

bindkey '\e[A' history-substring-search-backward
bindkey '\e[B' history-substring-search-forward
