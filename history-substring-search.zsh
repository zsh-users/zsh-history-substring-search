#!/usr/bin/env zsh
#
# This is a clean-room implementation of the Fish[1] shell's history search
# feature, where you can enter any part of any previous command and press
# the UP and DOWN arrow keys to cycle through all matching commands.
#
# This was originally implemented by Peter Stephenson[2], who published it to
# the ZSH users mailing list (thereby making it public domain) in September
# 2009. It was later revised by Guido van Steen and released under the BSD
# license (see below) as part of the fizsh[3] project in January 2011.
#
# This was later extracted from fizsh[3] release 1.0.1, refactored heavily,
# and repackaged as an OH MY ZSHELL plugin[4] and as an independently loadable
# ZSH script[5] by Suraj N. Kurapati in 2011.
#
# Further improvements were contributed by Guido van Steen, Sorin Ionescu and
# Vincent Guerci.
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

#
# We have to "override" some keys and widgets if the
# zsh-syntax-highlighting plugin has not been loaded:
#
# https://github.com/nicoulaj/zsh-syntax-highlighting
#
if [[ $+functions[_zsh_highlight] -eq 0 ]]; then
  #
  # Dummy implementation of _zsh_highlight()
  # that simply removes existing highlights
  #
  function _zsh_highlight() {
    region_highlight=()
  }

  #
  # Remove existing highlights when the user
  # inserts printable characters into $BUFFER
  #
  function ordinary-key-press() {
    if [[ $KEYS = [[:print:]] ]]; then
      region_highlight=()
    fi
    zle .self-insert
  }
  zle -N self-insert ordinary-key-press

  #
  # Override ZLE widgets to invoke _zsh_highlight()
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
        # applied highlighting. Therefore we do not remap them.
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
HISTORY_SUBSTRING_SEARCH_GLOBBING_FLAGS='i' # "i" means case insensitive, see "Globbing Flags" in zshexpn(1)

_history-substring-search-begin() {
  _history_substring_search_move_cursor_eol=false

  #
  # Continue using the previous $_history_substring_search_result by default,
  # unless the current query was cleared or a new/different query was entered.
  #
  if [[ -z $BUFFER || $BUFFER != $_history_substring_search_result ]]; then
    #
    # For the purpose of highlighting we will also keep
    # a version without doubly-escaped meta characters.
    #
    _history_substring_search_query=$BUFFER

    #
    # $BUFFER contains the text that is in the command-line currently.
    # we put an extra "\\" before meta characters such as "\(" and "\)",
    # so that they become "\\\(" and "\\\)".
    #
    _history_substring_search_query_escaped=${BUFFER//(#m)[\][()|\\*?#<>~^]/\\$MATCH}

    #
    # Find all occurrences of the search query in the history file.
    #
    # (k) turns it an array of line numbers.
    #
    # (on) seems to remove duplicates, which are default
    #      options. They can be turned off by (ON).
    #
    _history_substring_search_matches=(${(kon)history[(R)(#$HISTORY_SUBSTRING_SEARCH_GLOBBING_FLAGS)*${_history_substring_search_query_escaped}*]})

    #
    # Define the range of values that $_history_substring_search_match_number
    # can take: [0, $_history_substring_search_number_of_matches_plus_one].
    #
    _history_substring_search_number_of_matches=${#_history_substring_search_matches}
    let "_history_substring_search_number_of_matches_plus_one = $_history_substring_search_number_of_matches + 1"
    let "_history_substring_search_number_of_matches_minus_one = $_history_substring_search_number_of_matches - 1"

    #
    # initial value of $_history_substring_search_match_number, which
    # can only be decreased by the history-substring-search-* widgets.
    #
    let "_history_substring_search_match_number = $_history_substring_search_number_of_matches_plus_one"
  fi
}

_history-substring-search-highlight() {
  _zsh_highlight

  if [[ -n $_history_substring_search_query ]]; then
    #
    # The following expression yields a variable $MBEGIN, which
    # indicates the begin position + 1 of the first occurrence
    # of _history_substring_search_query_escaped in $BUFFER.
    #
    : ${(S)BUFFER##(#m$HISTORY_SUBSTRING_SEARCH_GLOBBING_FLAGS)($_history_substring_search_query##)}
    let "_history_substring_search_query_mbegin = $MBEGIN - 1"
    let "_history_substring_search_query_mend = $_history_substring_search_query_mbegin + $#_history_substring_search_query"
    region_highlight+=("$_history_substring_search_query_mbegin $_history_substring_search_query_mend $1")
  fi
}

_history-substring-search-up-buffer() {
  #
  # Check if the UP arrow was pressed to move the cursor within a multi-line
  # buffer. This amounts to three tests:
  #
  # 1. $#buflines -gt 1.
  #
  # 2. $CURSOR -ne $#BUFFER.
  #
  # 3. Check if we are on the first line of the current multi-line buffer.
  #    If so, pressing UP would amount to leaving the multi-line buffer.
  #
  #    We check this by adding an extra "x" to $LBUFFER, which makes
  #    sure that xlbuflines is always equal to the number of lines
  #    until $CURSOR (including the line with the cursor on it).
  #
  buflines=(${(f)BUFFER})
  local XLBUFFER=$LBUFFER"x"
  xlbuflines=(${(f)XLBUFFER})

  if [[ $#buflines -gt 1 && $CURSOR -ne $#BUFFER && $#xlbuflines -ne 1 ]]; then
    zle up-line-or-history
    return true
  fi

  false
}

_history-substring-search-down-buffer() {
  #
  # Check if the DOWN arrow was pressed to move the cursor within a multi-line
  # buffer. This amounts to three tests:
  #
  # 1. $#buflines -gt 1.
  #
  # 2. $CURSOR -ne $#BUFFER.
  #
  # 3. Check if we are on the last line of the current multi-line buffer.
  #    If so, pressing DOWN would amount to leaving the multi-line buffer.
  #
  #    We check this by adding an extra "x" to $RBUFFER, which makes
  #    sure that xrbuflines is always equal to the number of lines
  #    from $CURSOR (including the line with the cursor on it).
  #
  buflines=(${(f)BUFFER})
  local XRBUFFER="x"$RBUFFER
  xrbuflines=(${(f)XRBUFFER})

  if [[ $#buflines -gt 1 && $CURSOR -ne $#BUFFER && $#xrbuflines -ne 1 ]]; then
    zle down-line-or-history
    return true
  fi

  false
}

_history-substring-search-up-history() {
  #
  # When searching without a search query history-substring-search-up should
  # behave like up-history. Apart from this, such a search should end with an
  # empty $BUFFER like in Fish.
  #
  if [[ -z $_history_substring_search_query ]]; then
    # As long as we are not at the last history entry, call up-history():
    if [[ $HISTNO -gt 1 ]]; then
      zle up-history
    else
      #
      # [[ $HISTNO -eq 1 ]] means that _history-substring-search-up-history()
      # has arrived at the last entry of the history file.  In that case we
      # make $_history_substring_search_last_entry_in_history equal to
      # $BUFFER.  This value can later be retrieved by
      # _history-substring-search-down-history().  Moreover the current buffer
      # should be made empty.  In all other cases
      # $_history_substring_search_last_entry_in_history should remain empty:
      #
      if [[ $#_history_substring_search_last_entry_in_history -eq 0 ]]; then
        _history_substring_search_last_entry_in_history=$BUFFER
      fi
      BUFFER=''
    fi

    return true
  fi

  false
}

_history-substring-search-down-history() {
  #
  # When searching without a search query the widget
  # history-substring-search-down should behave like down-history. Apart
  # from this, such a search should end with an empty buffer:
  #
  if [[ -z $_history_substring_search_query ]]; then
    #
    # If _history-substring-search-up-history() has previously arrived at the
    # last history entry it will have made
    # $_history_substring_search_last_entry_in_history equal to $BUFFER (see
    # the description of _history-substring-search-up-history()).  Therefore,
    # here we test if $_history_substring_search_last_entry_in_history is
    # equal to an empty string:
    #
    if [[ $#_history_substring_search_last_entry_in_history -eq 0 ]]; then
      # If so we can safely call down-history():
      zle down-history
    else
      # If not we make $BUFFER equal to
      # $_history_substring_search_last_entry_in_history and we move the the
      # cursor to the end of the buffer:
      BUFFER=$_history_substring_search_last_entry_in_history
      CURSOR=$#BUFFER

      # And we make $_history_substring_search_last_entry_in_history equal to
      # an empty string, so that later we will be able to call up-history()
      # and down-history() again:
      _history_substring_search_last_entry_in_history=''
    fi

    return true
  fi

  false
}

_history-substring-search-up-search() {
  _history_substring_search_move_cursor_eol=true

  #
  # Highlight matches during a history-substring-search:
  #
  # * $_history_substring_search_matches: the current list of matches
  # * $_history_substring_search_number_of_matches: the current number of matches
  # * $_history_substring_search_number_of_matches_plus_one: the current number of matches + 1
  # * $_history_substring_search_number_of_matches_minus_one: the current number of matches - 1
  # * $_history_substring_search_match_number: the number of the current match
  #
  # The range of values that $_history_substring_search_match_number can take
  # is: [0, $_history_substring_search_number_of_matches_plus_one].  A value
  # of 0 indicates that we are beyond the end of
  # $_history_substring_search_matches.  A value of
  # $_history_substring_search_number_of_matches_plus_one indicates that we
  # are beyond the beginning of $_history_substring_search_matches.
  #
  # The initial value of $_history_substring_search_match_number is
  # $_history_substring_search_number_of_matches_plus_one.
  #
  if [[ $_history_substring_search_match_number -ge 2 ]]; then
    #
    # Highlight the next match:
    #
    # 1. Decrease the value of $_history_substring_search_match_number.
    #
    # 2. Use $HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND
    #    to highlight the current buffer.
    #
    let "_history_substring_search_match_number = $_history_substring_search_match_number - 1"
    BUFFER=$history[$_history_substring_search_matches[$_history_substring_search_match_number]]
    _history-substring-search-highlight $HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND

  elif [[ $_history_substring_search_match_number -eq 1 ]]; then
    #
    # We will move beyond the end of $_history_substring_search_matches:
    #
    # 1. Decrease the value of $_history_substring_search_match_number.
    #
    # 2. Save the current buffer in $_history_substring_search_old_buffer,
    #    so that it can be retrieved by
    #    _history-substring-search-down-search() later.
    #
    # 3. Make $BUFFER equal to $_history_substring_search_query.
    #
    # 4. Use $HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND
    #    to highlight the current buffer.
    #
    let "_history_substring_search_match_number = $_history_substring_search_match_number - 1"
    _history_substring_search_old_buffer=$BUFFER
    BUFFER=$_history_substring_search_query
    _history-substring-search-highlight $HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND

  elif [[ $_history_substring_search_match_number -eq $_history_substring_search_number_of_matches_plus_one ]]; then
    #
    # We were beyond the beginning of $_history_substring_search_matches but
    # UP makes us move back to $_history_substring_search_matches:
    #
    # 1. Decrease the value $of _history_substring_search_match_number.
    #
    # 2. Restore $BUFFER from $_history_substring_search_old_buffer.
    #
    # 3. Use $HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND
    #    to highlight the current buffer.
    #
    let "_history_substring_search_match_number = $_history_substring_search_match_number - 1"
    BUFFER=$_history_substring_search_old_buffer
    _history-substring-search-highlight $HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND
  fi
}

_history-substring-search-down-search() {
  _history_substring_search_move_cursor_eol=true

  #
  # Highlight matches during a history-substring-search:
  #
  # $_history_substring_search_matches: the current list of matches
  # $_history_substring_search_number_of_matches: the current number of matches
  # $_history_substring_search_number_of_matches_plus_one: the current number of matches + 1
  # $_history_substring_search_number_of_matches_minus_one: the current number of matches - 1
  # $_history_substring_search_match_number: the number of the current match
  #
  # The range of values that $_history_substring_search_match_number can take
  # is: [0, $_history_substring_search_number_of_matches_plus_one].  A value
  # of 0 indicates that we are beyond the end of
  # $_history_substring_search_matches.  A value of
  # $_history_substring_search_number_of_matches_plus_one indicates that we
  # are beyond the beginning of $_history_substring_search_matches.
  #
  # The initial value of $_history_substring_search_match_number is
  # $_history_substring_search_number_of_matches_plus_one.
  #
  if [[ $_history_substring_search_match_number -eq $_history_substring_search_number_of_matches_plus_one ]]; then
    #
    # DOWN was pressed immediately. $_history_substring_search_match_number is
    # still equal to $_history_substring_search_match_number_plus_one.
    # However, there is no highlighting yet:
    #
    # 1. We have to use $HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND
    #    to highlight the current buffer.
    #
    _history-substring-search-highlight $HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND

  elif [[ $_history_substring_search_match_number -le $_history_substring_search_number_of_matches_minus_one ]]; then
    #
    # Highlight the next match:
    #
    # 1. Increase $_history_substring_search_match_number by 1.
    #
    # 2. Use $HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND
    #    to highlight the current buffer.
    #
    let "_history_substring_search_match_number = $_history_substring_search_match_number + 1"
    BUFFER=$history[$_history_substring_search_matches[$_history_substring_search_match_number]]
    _history-substring-search-highlight $HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND

  elif [[ $_history_substring_search_match_number -eq $_history_substring_search_number_of_matches ]]; then
    #
    # We will move beyond the beginning of $_history_substring_search_matches:
    #
    # 1. Increase $_history_substring_search_match_number by 1.
    #
    # 2. Save the current buffer in $_history_substring_search_old_buffer, so
    #    that it can be retrieved by _history-substring-search-up-search()
    #    later.
    #
    # 3. Make $BUFFER equal to $_history_substring_search_query.
    #
    # 4. Use $HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND
    #    to highlight the current buffer.
    #
    let "_history_substring_search_match_number = $_history_substring_search_match_number + 1"
    _history_substring_search_old_buffer=$BUFFER
    BUFFER=$_history_substring_search_query
    _history-substring-search-highlight $HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND

  elif [[ $_history_substring_search_match_number -eq 0 ]]; then
    #
    # We were beyond the end of $_history_substring_search_matches but DOWN
    # makes us move back to the $_history_substring_search_matches:
    #
    # 1. Increase $_history_substring_search_match_number by 1.
    #
    # 2. Restore $BUFFER from $_history_substring_search_old_buffer.
    #
    # 3. Use $HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND
    #    to highlight the current buffer.
    #
    let "_history_substring_search_match_number = $_history_substring_search_match_number + 1"
    BUFFER=$_history_substring_search_old_buffer
    _history-substring-search-highlight $HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND
  fi
}

_history-substring-search-end() {
  _history_substring_search_result=$BUFFER

  if [[ $_history_substring_search_move_cursor_eol == true ]]; then
    # Move the cursor to the end of the $BUFFER.
    CURSOR=${#BUFFER}
  fi

  # For debugging purposes:
  # zle -R "mn: "$_history_substring_search_match_number" m#: "${#_history_substring_search_matches}
  # read -k -t 200 && zle -U $REPLY

  # Exit successfully from the history-substring-search-* widgets.
  true
}

history-substring-search-up() {
  _history-substring-search-begin

  _history-substring-search-up-history ||
  _history-substring-search-up-buffer ||
  _history-substring-search-up-search

  _history-substring-search-end
}

history-substring-search-down() {
  _history-substring-search-begin

  _history-substring-search-down-history ||
  _history-substring-search-down-buffer ||
  _history-substring-search-down-search

  _history-substring-search-end
}

zle -N history-substring-search-up
zle -N history-substring-search-down

bindkey '\e[A' history-substring-search-up
bindkey '\e[B' history-substring-search-down

# -*- mode: zsh; sh-indentation: 2; indent-tabs-mode: nil; sh-basic-offset: 2; -*-
# vim: ft=zsh sw=2 ts=2 et
