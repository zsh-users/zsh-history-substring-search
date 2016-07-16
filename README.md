# zsh-history-substring-search

This is a clean-room implementation of the [Fish shell][1]'s history search
feature, where you can type in any part of any previously entered command
and press the UP and DOWN arrow keys to cycle through the matching commands.
You can also use K and J in VI mode or ^P and ^N in EMACS mode for the same.

[1]: http://fishshell.com
[2]: http://www.zsh.org/mla/users/2009/msg00818.html
[3]: http://sourceforge.net/projects/fizsh/
[4]: https://github.com/robbyrussell/oh-my-zsh/pull/215
[5]: https://github.com/zsh-users/zsh-history-substring-search
[6]: https://github.com/zsh-users/zsh-syntax-highlighting


Requirements
------------------------------------------------------------------------------

* [ZSH](http://zsh.sourceforge.net) 4.3 or newer


Usage
------------------------------------------------------------------------------

1.  Load this script into your interactive ZSH session:

        % source zsh-history-substring-search.zsh

    If you want to use [zsh-syntax-highlighting][6] along with this script,
    then make sure that you load it *before* you load this script:

        % source zsh-syntax-highlighting.zsh
        % source zsh-history-substring-search.zsh

2.  Bind keyboard shortcuts to this script's functions:

        ## Arrow Keys ###########################################

        # OPTION 1: for most systems
        zmodload zsh/terminfo
        bindkey "$terminfo[kcuu1]" history-substring-search-up
        bindkey "$terminfo[kcud1]" history-substring-search-down

        # OPTION 2: for iTerm2 running on Apple MacBook laptops
        zmodload zsh/terminfo
        bindkey "$terminfo[cuu1]" history-substring-search-up
        bindkey "$terminfo[cud1]" history-substring-search-down

        # OPTION 3: for Ubuntu 12.04, Fedora 21, and MacOSX 10.9
        bindkey '^[[A' history-substring-search-up
        bindkey '^[[B' history-substring-search-down

        ## EMACS mode ###########################################

        bindkey -M emacs '^P' history-substring-search-up
        bindkey -M emacs '^N' history-substring-search-down

        ## VI mode ##############################################

        bindkey -M vicmd 'k' history-substring-search-up
        bindkey -M vicmd 'j' history-substring-search-down

3.  Type any part of any previous command and then:

    * Press the UP arrow key to select the nearest command that (1) contains
      your query and (2) is older than the current command in the command
      history.

    * Press the DOWN arrow key to select the nearest command that (1)
      contains your query and (2) is newer than the current command in the
      command history.

    * Press ^U (the Control and U keys simultaneously) to abort the search.

4.  If a matching command spans more than one line of text, press the LEFT
    arrow key to move the cursor away from the end of the command, and then:

    * Press the UP arrow key to move the cursor to the line above.  When the
      cursor reaches the first line of the command, pressing the UP arrow
      key again will cause this script to perform another search.

    * Press the DOWN arrow key to move the cursor to the line below.  When
      the cursor reaches the last line of the command, pressing the DOWN
      arrow key again will cause this script to perform another search.


Configuration
------------------------------------------------------------------------------

This script defines the following global variables. You may override their
default values only after having loaded this script into your ZSH session.

* `HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND` is a global variable that defines
  how the query should be highlighted inside a matching command. Its default
  value causes this script to highlight using bold, white text on a magenta
  background. See the "Character Highlighting" section in the zshzle(1) man
  page to learn about the kinds of values you may assign to this variable.

* `HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND` is a global variable that
  defines how the query should be highlighted when no commands in the
  history match it. Its default value causes this script to highlight using
  bold, white text on a red background. See the "Character Highlighting"
  section in the zshzle(1) man page to learn about the kinds of values you
  may assign to this variable.

* `HISTORY_SUBSTRING_SEARCH_GLOBBING_FLAGS` is a global variable that defines
  how the command history will be searched for your query. Its default value
  causes this script to perform a case-insensitive search. See the "Globbing
  Flags" section in the zshexpn(1) man page to learn about the kinds of
  values you may assign to this variable.

* `HISTORY_SUBSTRING_SEARCH_ENSURE_UNIQUE` is a global variable that defines
  whether all search results returned are _unique_. If set to a non-empty
  value, then only unique search results are presented. This behaviour is off
  by default. An alternative way to ensure that search results are unique is
  to use `setopt HIST_IGNORE_ALL_DUPS`. If this configuration variable is off
  and `setopt HIST_IGNORE_ALL_DUPS` is unset, then `setopt HIST_FIND_NO_DUPS`
  is still respected and it makes this plugin skip duplicate _adjacent_ search
  results as you cycle through them, but this does not guarantee that search
  results are unique: if your search results were "Dog", "Dog", "HotDog",
  "Dog", then cycling them gives "Dog", "HotDog", "Dog". Notice that the "Dog"
  search result appeared twice as you cycled through them. If you wish to
  receive globally unique search results only once, then use this
  configuration variable, or use `setopt HIST_IGNORE_ALL_DUPS`.


History
------------------------------------------------------------------------------

* September 2009: [Peter Stephenson][2] originally wrote this script and it
  published to the zsh-users mailing list.

* January 2011: Guido van Steen (@guidovansteen) revised this script and
  released it under the 3-clause BSD license as part of [fizsh][3], the
  Friendly Interactive ZSHell.

* January 2011: Suraj N. Kurapati (@sunaku) extracted this script from
  [fizsh][3] 1.0.1, refactored it heavily, and finally repackaged it as an
  [oh-my-zsh plugin][4] and as an independently loadable [ZSH script][5].

* July 2011: Guido van Steen, Suraj N. Kurapati, and Sorin Ionescu
  (@sorin-ionescu) [further developed it][4] with Vincent Guerci (@vguerci).

* March 2016: Geza Lore (@gezalore) greatly refactored it in pull request #55.
