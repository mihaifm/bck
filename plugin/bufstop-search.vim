"""""""""""""""""""""""""""""
" bufstop search - using ack

if exists('g:BufstopSearch_loaded') 
  finish
endif

let g:BufstopSearch_loaded = 1

if !exists('g:BufstopSearchRoots')
  let g:BufstopSearchRoots = ['.git/', '.git', '_darcs/', '.hg/', '.bzr/', '.svn/', 'Gemfile']
endif

" detect system ack
let s:ack = executable('ack-grep') ? 'ack-grep' : 'ack'
let s:ack .= ' -H --nocolor --nogroup --column '

let s:name = "--Bufstop-search--"
let s:output = ""
let s:types = ["path", "line_no", "col_no", "text"]
let s:keystr = "1234asfcvzx5qwertyuiopbnm67890ABCEFGHIJKLMNOPQRSTUVZ"
let s:keys = split(s:keystr, '\zs')
let s:local_bufnr = -1
let s:current_result = -1

function! s:SetProperties()
  setlocal nonumber
  setlocal foldcolumn=0
  setlocal nofoldenable
  setlocal cursorline
  setlocal nospell
  setlocal nobuflisted
  setlocal buftype=nofile
  setlocal noswapfile
  setlocal nowrap

  if has("syntax")
    syn match bufstopKey /\v^\s\s(\d|\a|\s)/ contained
    syn match bufstopName /\v^\s\s(\d|\a|\s)\s+.+\s\s/ contains=bufstopKey
   
    hi def link bufstopKey String
    hi def link bufstopName Type
  endif
endfunction

function! s:BufStopSearchSelectBuffer(k)
  let keyno = strridx(s:keystr, a:k) 
  let result_file = ''
  let line = -1 

  if (keyno >= 0)
    for b in s:allresults
      if b.key ==# a:k
        let result_file = b.path
        let line = b.line_no
      endif
    endfor
    " move cursor on the selected line
    exe keyno+1
    let s:current_result = keyno
  else
    let idx = line('.') - 1
    let result_file = s:allresults[idx].path
    let line = s:allresults[idx].line_no
    let s:current_result = idx
  endif

  exe "wincmd p"
  exe "e " . result_file
  exe line
  exe "normal zz"
  setlocal cursorline
  exe "wincmd p"
endfunction

function! s:BufstopSearchQuit()
  exec 'q'
  exec 'wincmd p'
  exec 'setlocal nocursorline'
endfunction

function! s:MapKeys()
  nnoremap <buffer> <silent> <Esc>   :call <SID>BufstopSearchQuit()<cr>
  nnoremap <buffer> <silent> <cr>    :call <SID>BufStopSearchSelectBuffer('cr')<cr>
  nnoremap <buffer> <silent> <2-LeftMouse> :call <SID>BufStopSearchSelectBuffer('cr')<cr>

  for buf in s:allresults
    exe "nnoremap <buffer> <silent> ". buf.key . "   :call <SID>BufStopSearchSelectBuffer('" . buf.key . "')<cr>"
  endfor
endfunction

function! s:GetResultsInfo()
  let s:allresults = []
  let [s:allresults, allwidths] = [[], {}]

  for n in s:types
    let allwidths[n] = []
  endfor
 
  let k = 0

  let bu_li = split(s:output, '\n')

  for line in bu_li
    let b = {}
    let [full_match, path, line_no, col_no, text; rest] = matchlist(line, '\(.\{-}\):\(.\{-}\):\(.\{-}\):\(.*\)') 
    let b.path = path
    let b.line_no = line_no
    let b.col_no = col_no
    " strip spaces
    let text = substitute(text, '^\s\+\|\s\+$', '', 'g')
    let b.text = text

    if (k < len(s:keys))
      let b.key = s:keys[k]
    else
      let b.key = 'X'
    endif

    let k = k + 1

    call add(s:allresults, b)

    for n in s:types
      call add(allwidths[n], len(b[n]))
    endfor
  endfor

  let s:allpads = {}

  for n in s:types
    let s:allpads[n] = repeat(' ', max(allwidths[n]))
  endfor

  return s:allresults
endfunction

function! s:BufstopSearchOpen()
  if !exists("s:lines")
    return
  endif

  exe "botright " . min([len(s:lines), 20]) . " split"

  if s:local_bufnr < 0
    exe "silent e ".s:name
    let s:local_bufnr = bufnr(s:name)
  else
    exe "b ". s:local_bufnr
    exe s:current_result+1
  endif
endfunction

function! s:BufstopSearchNext()
  if !exists("s:lines")
    return
  endif

  let s:current_result = s:current_result + 1
  if s:current_result >= len(s:lines)
    let s:current_result = len(s:lines) - 1
  endif

  let result_file = s:allresults[s:current_result].path
  let line = s:allresults[s:current_result].line_no
  exe "e " . result_file
  exe line

endfunction

function! s:BufstopSearchPrev()
  if !exists("s:lines")
    return
  endif

  let s:current_result = s:current_result - 1
  if s:current_result < 0
    let s:current_result = 0
  endif

  let result_file = s:allresults[s:current_result].path
  let line = s:allresults[s:current_result].line_no
  exe "e " . result_file
  exe line

endfunction

function! BufstopSearch(args)
  let args = ''
  if a:args == ''
    let args = expand('<cword>')
    if args == ''
      return
    endif
    call s:ChangeToRootDirectory()
  else
    let args = a:args
  endif

  let cmd = "ack -H --nocolor --nogroup --column " . shellescape(args)
  echo "running: " . cmd
 
  if exists("g:xolox#shell#version")
    " use vim-shell when available
    let s:output = join(xolox#shell#execute(cmd, 1), "\n")
  else
    let s:output = system(cmd)
  end

  let s:lines = []
  let searchdata = s:GetResultsInfo()

  for buf in searchdata
    let line = ''
    if buf.key ==# 'X'
      let line = "  " . " " . "   "  
    else
      let line = "  " . buf.key . "   "
    endif

    let path = buf["path"]
    let line_no = buf["line_no"]
    let pad = s:allpads.text

    let line .= buf.text . "  " . strpart(pad . path . ':' . line_no, len(buf.text))

    call add(s:lines, line)
  endfor
  
  exe "botright " . min([len(s:lines), 20]) . " split"

  if s:local_bufnr < 0
    exe "silent e ".s:name
    let s:local_bufnr = bufnr(s:name)
  else
    exe "b ". s:local_bufnr
  endif
  
  setlocal modifiable
  exe 'setlocal statusline=Bufstop-search:\ ' . len(s:lines) . '\ results' 
  exe 'goto'
  exe '%delete'
  call setline(1, s:lines)
  setlocal nomodifiable

  call s:SetProperties()

  call s:MapKeys()
endfunction

function! BufstopSearchProject(args)
  call s:ChangeToRootDirectory()
  call BufstopSearch(a:args)
endfunction

""""""""""""""""""""""""""""""""""""""""""""""
" change to root functionality via vim-rooter
" github.com/airblade/vim-rooter

" Find the root directory of the current file, i.e the closest parent directory
" containing a <pattern> directory, or an empty string if no such directory is found.
function! s:FindInCurrentPath(pattern)
  " Don't try to change directories when on a virtual filesystem (netrw, fugitive,...).
  if match(expand('%:p'), '^\w\+://.*') != -1
    return ""
  endif

  let dir_current_file = fnameescape(expand("%:p:h"))
  let pattern_dir = ""

  " Check for directory or a file
  if (stridx(a:pattern, "/")) != -1
    let pattern = substitute(a:pattern, "/", "", "")
    let pattern_dir = finddir(a:pattern, dir_current_file . ";")
  else
    let pattern_dir = findfile(a:pattern, dir_current_file . ";")
  endif

  " If we're at the project root or we can't find one above us
  if pattern_dir == a:pattern || empty(pattern_dir)
    return ""
  else
    return substitute(pattern_dir, a:pattern . "$", "", "")
  endif
endfunction

" Returns the root directory for the current file based on the list of SCM directory names
function! s:FindRootDirectory()
  for pattern in g:BufstopSearchRoots
    let result = s:FindInCurrentPath(pattern)
    if !empty(result)
      return result
    endif
  endfor
endfunction

" Changes the current working directory to the current file's root directory.
function! s:ChangeToRootDirectory()
  let root_dir = s:FindRootDirectory()
  if !empty(root_dir)
    if exists('+autochdir')
      set noautochdir
    endif
    exe ":cd " . fnameescape(root_dir)
  endif
endfunction

""""""""""""""""""
" create commands

command! ChangeToRoot call <SID>ChangeToRootDirectory()
command! -nargs=* -complete=file Bck call BufstopSearch(<q-args>)
command! BufstopSearchOpen call <SID>BufstopSearchOpen()
command! BufstopSearchNext call <SID>BufstopSearchNext()
command! BufstopSearchPrev call <SID>BufstopSearchPrev()

