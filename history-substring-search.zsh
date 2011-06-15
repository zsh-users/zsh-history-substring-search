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
# and repackaged as an OH MY ZSHELL plugin[4] and as an independently loadable
# ZSH script[5] by Suraj N. Kurapati in 2011.
#
# Further improvements were contributed by Sorin Ionescu and Vincent Guerci.
#
# [1] http://fishshell.com
# [2] http://www.zsh.org/mla/users/2009/msg00818.html
# [3] http://sourceforge.net/projects/fizsh/
# [4] https://github.com/robbyrussell/oh-my-zsh/pull/215
# [5] https://github.com/sunaku/zsh-history-substring-search
#
##############################################################################
#
# Copyright (c) 2009 Peter Stephenson
# Copyright (c) 2011 Guido van Steen
# Copyright (c) 2011 Suraj N. Kurapati
# Copyright (c) 2011 Sorin Ionescu
# Copyright (c) 2011 Vincent Guerci
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#  * Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#
#  * Redistributions in binary form must reproduce the above
#    copyright notice, this list of conditions and the following
#    disclaimer in the documentation and/or other materials provided
#    with the distribution.
#
#  * Neither the name of the FIZSH nor the names of its contributors
#    may be used to endorse or promote products derived from this
#    software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#
##############################################################################

setopt extendedglob
zmodload -F zsh/parameter

# We have to "override" some keys and widgets, unless
# the zsh-syntax-highlighting plugin has been loaded:
#
# https://github.com/nicoulaj/zsh-syntax-highlighting
#
if [[ $+functions[_zsh_highlight] -eq 0 ]]; then

  # dummy implementation of _zsh_highlight()
  # that simply removes existing highlights
  function _zsh_highlight() {
    region_highlight=()
  }

  # remove existing highlights when the user
  # inserts printable characters into $BUFFER
  function ordinary-key-press() {
    if [[ $KEYS = [[:print:]] ]]; then
      region_highlight=()
    fi
    zle .self-insert
  }
  zle -N self-insert ordinary-key-press

  # override ZLE widgets to invoke _zsh_highlight()
  #
  # https://github.com/nicoulaj/zsh-syntax-highlighting/blob/
  # bb7fcb79fad797a40077bebaf6f4e4a93c9d8163/zsh-syntax-highlighting.zsh#L121
  #
  #--------------8<-------------------8<-------------------8<-----------------
  #
  # Copyright (c) 2010-2011 zsh-syntax-highlighting contributors
  # All rights reserved.
  #
  # Redistribution and use in source and binary forms, with or without
  # modification, are permitted provided that the following conditions are
  # met:
  #
  #  * Redistributions of source code must retain the above copyright
  #    notice, this list of conditions and the following disclaimer.
  #
  #  * Redistributions in binary form must reproduce the above copyright
  #    notice, this list of conditions and the following disclaimer in the
  #    documentation and/or other materials provided with the distribution.
  #
  #  * Neither the name of the zsh-syntax-highlighting contributors nor the
  #    names of its contributors may be used to endorse or promote products
  #    derived from this software without specific prior written permission.
  #
  # THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
  # IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
  # THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
  # PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
  # CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
  # EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
  # PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
  # PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
  # LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
  # NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
  # SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

  # Load ZSH module zsh/zleparameter, needed to override user defined widgets.
  zmodload zsh/zleparameter 2>/dev/null || {
    echo 'zsh-syntax-highlighting: failed loading zsh/zleparameter, exiting.' >&2
    return -1
  }

  # Override ZLE widgets to make them invoke _zsh_highlight.
  for event in ${${(f)"$(zle -la)"}:#(_*|orig-*|.run-help|.which-command)}; do
    if [[ "$widgets[$event]" == completion:* ]]; then
      eval "zle -C orig-$event ${${${widgets[$event]}#*:}/:/ } ; $event() { builtin zle orig-$event && _zsh_highlight } ; zle -N $event"
    else
      case $event in
        accept-and-menu-complete)
          eval "$event() { builtin zle .$event && _zsh_highlight } ; zle -N $event"
          ;;

        # The following widgets should NOT remove any previously
        # applied highlighting.  Therefore we do not remap them.
        .forward-char|.backward-char|.up-line-or-history|.down-line-or-history)
          ;;

        .*)
          clean_event=$event[2,${#event}] # Remove the leading dot in the event name
          case ${widgets[$clean_event]-} in
            (completion|user):*)
              ;;
            *)
              eval "$clean_event() { builtin zle $event && _zsh_highlight } ; zle -N $clean_event"
              ;;
          esac
          ;;
        *)
          ;;
      esac
    fi
  done
  unset event clean_event
  #-------------->8------------------->8------------------->8-----------------
fi

HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND='bg=magenta,fg=white,bold'
HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND='bg=red,fg=white,bold'
HISTORY_SUBSTRING_SEARCH_GLOBBING_FLAGS='i' # see "Globbing Flags" in zshexpn(1)

_history-substring-search-begin() {
  # continue using the previous "$_history_substring_search_result" by default,
  # unless the current query was cleared or a new/different query was entered
  if [[ -z $BUFFER || $BUFFER != $_history_substring_search_result ]]; then
    # $BUFFER contains the text that is in the command-line currently.
    # we put an extra "\\" before meta characters such as "\(" and "\)",
    # so that they become "\\\(" and "\\\)"
    _history_substring_search_query_escaped=${BUFFER//(#m)[\][()\\*?#<>~^]/\\$MATCH}

    # for the purpose of highlighting we will also keep a version without
    # doubly-escaped meta characters
    _history_substring_search_query=${BUFFER}

    # find all occurrences of the pattern *${query}* within the history file
    # (k) turns it an array of line numbers. (on) seems to remove duplicates.
    # (on) are default options. they can be turned off by (ON).
    _history_substring_search_matches=(${(kon)history[(R)(#$HISTORY_SUBSTRING_SEARCH_GLOBBING_FLAGS)*${_history_substring_search_query_escaped}*]})

    # define the range of value that $_history_substring_search_match_number
    # can take: [0, $_history_substring_search_number_of_matches_plus_one]
    _history_substring_search_number_of_matches=${#_history_substring_search_matches}
    let "_history_substring_search_number_of_matches_plus_one = $_history_substring_search_number_of_matches + 1"
    let "_history_substring_search_number_of_matches_minus_one = $_history_substring_search_number_of_matches - 1"

    # initial value of $_history_substring_search_match_number, which can
    # initially only be decreased by ${WIDGET/forward/backward}
    let "_history_substring_search_match_number = $_history_substring_search_number_of_matches_plus_one"
  fi
}

_history-substring-search-highlight() {
  _zsh_highlight

  if [[ -n $_history_substring_search_query ]]; then
    # _history_substring_search_query_escaped string was not empty: highlight it
    # among other things, the following expression yields a variable $MEND,
    # which indicates the end position of the first occurrence of
    # $_history_substring_search_query_escaped in $BUFFER
    : ${(S)BUFFER##(#m$HISTORY_SUBSTRING_SEARCH_GLOBBING_FLAGS)($_history_substring_search_query##)}
    let "_history_substring_search_query_mbegin = $MBEGIN - 1"
    let "_history_substring_search_query_mend = $_history_substring_search_query_mbegin + $#_history_substring_search_query"
    region_highlight+=("$_history_substring_search_query_mbegin $_history_substring_search_query_mend $1")
  fi
}

_history-substring-search-end() {
  _history_substring_search_result=$BUFFER

  # "zle .end-of-line" does not move CURSOR to the final end of line in
  # multi-line buffers.
  [[ $_history_substring_search_move_cursor_eol == true ]] && CURSOR=${#BUFFER}

  # for debugging purposes:
  # zle -R "mn: "$_history_substring_search_match_number" m#: "${#_history_substring_search_matches}
  # read -k -t 200 && zle -U $REPLY

  # suppress any errors:
  true
}

history-substring-search-backward() {
  _history-substring-search-begin

  # Check if the UP arrow was pressed to move the cursor within a multi-line
  # buffer.  This amounts to three tests:
  #
  # 1. $#buflines -gt 1
  #
  # 2. $CURSOR -ne $#BUFFER
  #
  # 3. Check if we are on the first line of the current multi-line buffer.
  #    If so, pressing UP would amount to leaving the multi-line buffer.
  #
  #    We check this by adding an extra "x" to $LBUFFER, which makes sure that
  #    xlbuflines is always equal to the number of lines until $CURSOR
  #    (including the line with the cursor on it).
  #
  buflines=(${(f)BUFFER})
  local XLBUFFER=$LBUFFER"x"
  xlbuflines=(${(f)XLBUFFER})

  if [[ $#buflines -gt 1 && $CURSOR -ne $#BUFFER && $#xlbuflines -ne 1 ]]; then
    zle up-line-or-history
    _history_substring_search_move_cursor_eol=false
  else
    if [[ $_history_substring_search_match_number -ge 2 && $_history_substring_search_match_number -le $_history_substring_search_number_of_matches_plus_one ]]; then
      let "_history_substring_search_match_number = $_history_substring_search_match_number - 1"
      BUFFER=$history[$_history_substring_search_matches[$_history_substring_search_match_number]]
      _history-substring-search-highlight $HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND
    else
      if [[ $_history_substring_search_match_number -eq 1 ]]; then
        # we will move out of the _history_substring_search_matches
        let "_history_substring_search_match_number = $_history_substring_search_match_number - 1"
        _history_substring_search_old_buffer_backward=$BUFFER
        BUFFER=$_history_substring_search_query
        _history-substring-search-highlight $HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND
      else
        if [[ $_history_substring_search_match_number -eq $_history_substring_search_number_of_matches_plus_one ]]; then
          # we will move back to the _history_substring_search_matches
          let "_history_substring_search_match_number = $_history_substring_search_match_number - 1"
          BUFFER=$_history_substring_search_old_buffer_forward
          _history-substring-search-highlight $HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND
        fi
      fi
    fi
    _history_substring_search_move_cursor_eol=true
  fi

  _history-substring-search-end
}

history-substring-search-forward() {
  _history-substring-search-begin

  # Check if the DOWN arrow was pressed to move the cursor within a multi-line
  # buffer.  This amounts to three tests:
  #
  # 1. $#buflines -gt 1
  #
  # 2. $CURSOR -ne $#BUFFER
  #
  # 3. Check if we are on the last line of the current multi-line buffer.
  #    If so, pressing DOWN would amount to leaving the multi-line buffer.
  #
  #    We check this by adding an extra "x" to $RBUFFER, which makes sure that
  #    xrbuflines is always equal to the number of lines from $CURSOR
  #    (including the line with the cursor on it).
  #
  buflines=(${(f)BUFFER})
  local XRBUFFER="x"$RBUFFER
  xrbuflines=(${(f)XRBUFFER})

  if [[ $#buflines -gt 1 && $CURSOR -ne $#BUFFER && $#xrbuflines -ne 1 ]]; then
    zle down-line-or-history
    _history_substring_search_move_cursor_eol=false
  else
    if [[ $_history_substring_search_match_number -eq $_history_substring_search_number_of_matches_plus_one ]]; then
      let "_history_substring_search_match_number = $_history_substring_search_match_number"
      _history_substring_search_old_buffer_forward=$BUFFER
      BUFFER=$_history_substring_search_query
      _history-substring-search-highlight $HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND
    elif [[ $_history_substring_search_match_number -ge 0 && $_history_substring_search_match_number -le $_history_substring_search_number_of_matches_minus_one ]]; then
      let "_history_substring_search_match_number = $_history_substring_search_match_number + 1"
      BUFFER=$history[$_history_substring_search_matches[$_history_substring_search_match_number]]
      _history-substring-search-highlight $HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND
    else
      if [[ $_history_substring_search_match_number -eq $_history_substring_search_number_of_matches ]]; then
        let "_history_substring_search_match_number = $_history_substring_search_match_number + 1"
        _history_substring_search_old_buffer_forward=$BUFFER
        BUFFER=$_history_substring_search_query
        _history-substring-search-highlight $HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND
      else
        if [[ $_history_substring_search_match_number -eq 0 ]]; then
          let "_history_substring_search_match_number = $_history_substring_search_match_number + 1"
          BUFFER=$_history_substring_search_old_buffer_backward
          _history-substring-search-highlight $HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND
        fi
      fi
    fi
    _history_substring_search_move_cursor_eol=true
  fi

  _history-substring-search-end
}

zle -N history-substring-search-backward
zle -N history-substring-search-forward

bindkey '\e[A' history-substring-search-backward
bindkey '\e[B' history-substring-search-forward

# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
