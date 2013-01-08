##Bufstop-search

**Bufstop-search** is a plugin for searching in files. It puts bits and pieces together to make searching a better experience in Vim.

Searching is powered by [ack](http://betterthangrep.com/) , which needs to be installed first.
The plugin provides a `:Bck` command, similar to `:Ack` (see [Ack.vim](https://github.com/mileszs/ack.vim)).
The difference is that the results are not displayed in the quickfix window, but in a special buffer called `Bufstop-search`.
Each result has an associated hotkey which triggers the file to be displayed
in the previous window, without leaving the search results. This is similar 
to the [Bufstop](https://github.com/mihaifm/bufstop) plugin.

In addition, if the `:Bck` command is used without arguments, it makes a _**project-wide search**_ for the word under cursor. 

A project represents the first parent directory that contains a .git folder
inside it (or other project root markers which are obviously configurable). 
This is similar to the [vim-rooter](https://github.com/airblade/vim-rooter) plugin or the root markers in [CtrlP](https://github.com/kien/ctrlp.vim).

Some additional commands are provided to enhance the search experience (see below).

##Installation

This plugin uses [ack](http://betterthangrep.com/) for the search, which is a Perl script better that grep. 
Download and install from http://betterthangrep.com/

To install this plugin just copy `bufstop-search.vim` in the plugin directory
of your vim installation, or install via [pathogen](https://github.com/tpope/vim-pathogen)

##Usage

This plugin provides the following commands:

###:Bck

`:Bck [options] [{pattern}] [{directory}]`

Same as [Ack](https://github.com/mileszs/ack.vim#usage) but uses the [Bufstop](https://github.com/mihaifm/bufstop) window instead of the Quickfix window.
Inside it, each result will have an associated hotkey that can be used to preview the search result.

If `{pattern}` is not specified it will make a project-wide search for the word
under cursor (Note: this changes the current working directory in Vim to the
project root. You can use `cd-` to change it back to the previous working
directory after closing the [Bufstop](https://github.com/mihaifm/bufstop) window).

The following key mappings are present in the [Bufstop](https://github.com/mihaifm/bufstop) window:

    <CR>     Open the selected result. cursorline is used for highlighting
    <Esc>    Dismiss the Bufstop window
    k,j      Move up/down


###:ChangeToRoot

Changes Vim's working directory to the project root directory. Project root markers are definded by the `g:BufstopSearchRoots` variable.
If you wish to cd back to the previous directory before the change, you can use the `cd-` command. 

This command borrows some code from the [vim-rooter](https://github.com/airblade/vim-rooter) plugin.

###:BufstopSearchOpen

Open the search results after the window was closed.

###:BufstopSearchNext

Go to the next result

###:BufstopSearchPrev     

Go to the previous result

##Configuration

    g:BufstopSearchRoots

Defines project root markers used for the `:ChangeToRoot` command.    
Defaults: 

    ['.git/', '.git', '_darcs/', '.hg/', '.bzr/', '.svn/', 'Gemfile']

Note: a slash / at the end identifies a directory, no slash means a file.

##Recommended mappings

You can put these in your `vimrc`, or use totally different mappings:

    nmap <F4> :Bck<CR>
    map <leader>q :BufstopSearchOpen<CR>
    map <F7> :BufstopSearchNext<cr>
    map <F8> :BufstopSearchPrev<cr>
