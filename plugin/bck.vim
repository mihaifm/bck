"""""""""""""""""""""""""""""""""""
" Bck - enhanced searching for Vim

if exists('g:loaded_bck') 
  finish
endif

let g:loaded_bck = 1

function s:InitVariable(var, value)
  if !exists(a:var)
    exec 'let ' . a:var . ' = ' . "'" . a:value . "'"
  endif
endfunction

if !exists('g:BckRoots')
  let g:BckRoots = ['.git/', '.git', '_darcs/', '.hg/', '.bzr/', '.svn/', 'Gemfile']
endif

call s:InitVariable('g:BckPreserveCWD', 0)
call s:InitVariable('g:BckKeys', '12345asfcvzxqwertyuiopbnm6789ABCEFGHIKLMNOPQRSTUVXZ')
call s:InitVariable('g:BckOptions', 'pirw')
call s:InitVariable('g:BckSplit', 'botright')
call s:InitVariable('g:BckHidden', 0)

" g:BckOptions - a string containing search options
"
" [0]
"   p - project
"   d - parent dir
"   c - current dir
"   f - current file 
"   b - buffers
"
" [1]
"   i - ignore case
"   m - match case
"
" [2] 
"   r - recurse into subdirectories
"   n - non recursive
" 
" [3]
"   w - entire word
"   s - substring

" detect system ack
let s:ack = executable('ack-grep') ? 'ack-grep' : 'ack'
let s:ack .= ' -H --nocolor --nogroup --column '

let s:name = "--Bck-search--"
let s:output = []
let s:types = ["path", "line_no", "col_no", "text"]
let s:keystr = g:BckKeys
let s:keys = split(s:keystr, '\zs')
let s:local_bufnr = -1
let s:current_result = -1
let s:options_visible = 1
let s:bcko = g:BckOptions

function s:blank(str)
  if match(a:str, '^\s*$') == -1
    return 0
  endif
  return 1
endfunction

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
    syn match BckOptionsParen /\v\<|\>/ contained
    syn match BckOptionsKey /\vF\d\d*/ contained
    syn match BckOptionsName /\v\:.{-}\>/ contained contains=BckOptionsParen
    syn match BckOptions /\v^\s*\<.*/ contains=BckOptionsKey,BckOptionsName,BckOptionsParen
    syn match BckKey /\v^\s\s(\d|\a|\s)/ contained
    syn match BckName /\v^\s\s(\d|\a|\s)\s+.+\s\s/ contains=BckKey
   
    hi def link BckKey String
    hi def link BckName Type
    hi def link BckOptionsName Directory
    hi def link BckOptionsKey BckKey
    hi def link BckOptionsParen NonText
  endif
endfunction

function! s:BckSelectBuffer(k)
  let keyno = strridx(s:keystr, a:k)
  let result_file = ''
  let line = -1 
  let idx = -1

  " the offset caused by the help line
  let offset = 0
  if s:options_visible 
    let offset += 2
  endif

  if (keyno >= 0)
    for b in s:allresults
      if b.key ==# a:k
        let result_file = b.path
        let line = b.line_no
        let idx = b.index
        break
      endif
    endfor
    " move cursor on the selected line
    exe keyno + 1 + offset
    let s:current_result = keyno
  else
    let idx = line('.') - 1 - offset
    let result_file = s:allresults[idx].path
    let line = s:allresults[idx].line_no
    let s:current_result = idx
  endif

  if idx < 0
    return
  endif

  exe "wincmd p"
  setlocal nocursorline
  exe "cc" . (idx+1)
  exe "normal zz"
  setlocal cursorline
  exe "wincmd p"
endfunction

function! s:BckQuit()
  exec 'q'
  exec 'wincmd p'
  exec 'setlocal nocursorline'
endfunction

function! s:GetStrFromOpts()
  let output = ''
  let output = ' <F5:' 
  if s:bcko[0] ==# 'p'
    let output .= 'project>'
  elseif s:bcko[0] ==# 'd' 
    let output .= 'parent dir>'
  elseif s:bcko[0] ==# 'f'
    let output .= 'file>'
  elseif s:bcko[0] ==# 'c'
    let output .= 'current dir>'
  elseif s:bcko[0] ==# 'b'
    let output .= 'buffers>'
  endif

  let output .= ' <F6:'
  if s:bcko[1] ==# 'i'
    let output .= 'ingore case>' 
  else
    let output .= 'match case>'
  endif

  let output .= ' <F7:'
  if s:bcko[2] ==# 'r'
    let output .= 'recursive>'
  else
    let output .= 'non-recursive>'
  endif

  let output .= ' <F8:'
  if s:bcko[3] ==# 'w'
    let output .= 'whole word>'
  else
    let output .= 'substring>'
  endif

  return output
endfunction


" display or hide the search options at the top of the buffer
" onoff is either 'on' or 'off' 
function! s:BckOptLine(onoff)
  setlocal modifiable
  if a:onoff ==? "on"
    let opt_str = s:GetStrFromOpts()
    let opt_str .= "\n\n"
    let old_o = @o
    let @o = opt_str
    exe 'goto'
    exe 'normal! "oP'
    let @o = old_o
    let s:options_visible = 1
  else
    exe 'goto'
    exe 'normal! 2dd'
    let s:options_visible = 0
  endif
  setlocal nomodifiable
endfunction

" toggle the display of the search options at the top of the buffer
function! s:BckToggleOpts()
  if !s:options_visible
    call s:BckOptLine("on")
  else
    call s:BckOptLine("off")
  endif
endfunction

" toggle the option on position pos in s:bcko
function! s:BckOption(pos)
  if a:pos < 0 || a:pos >= len(s:bcko) 
    return
  endif

  if a:pos == 0
    if s:bcko[0] ==# 'p'
      let s:bcko = printf("%s%s%s%s", 'd', s:bcko[1], s:bcko[2], s:bcko[3])
    elseif s:bcko[0] ==# 'd'
      let s:bcko = printf("%s%s%s%s", 'f', s:bcko[1], s:bcko[2], s:bcko[3])
    elseif s:bcko[0] ==# 'f'
      let s:bcko = printf("%s%s%s%s", 'c', s:bcko[1], s:bcko[2], s:bcko[3])
    elseif s:bcko[0] ==# 'c'
      let s:bcko = printf("%s%s%s%s", 'b', s:bcko[1], s:bcko[2], s:bcko[3])
    elseif s:bcko[0] ==# 'b'
      let s:bcko = printf("%s%s%s%s", 'p', s:bcko[1], s:bcko[2], s:bcko[3])
    endif
  endif

  if a:pos == 1
    if s:bcko[1] ==# 'i'
      let s:bcko = printf("%s%s%s%s", s:bcko[0], 'm', s:bcko[2], s:bcko[3])
    else
      let s:bcko = printf("%s%s%s%s", s:bcko[0], 'i', s:bcko[2], s:bcko[3])
    end
  endif

  if a:pos == 2
    if s:bcko[2] ==# 'r'
      let s:bcko = printf("%s%s%s%s", s:bcko[0], s:bcko[1], 'n', s:bcko[3])
    else
      let s:bcko = printf("%s%s%s%s", s:bcko[0], s:bcko[1], 'r', s:bcko[3])
    endif
  endif

  if a:pos == 3
    if s:bcko[3] ==# 'w'
      let s:bcko = printf("%s%s%s%s", s:bcko[0], s:bcko[1], s:bcko[2], 'x')
    else
      let s:bcko = printf("%s%s%s%s", s:bcko[0], s:bcko[1], s:bcko[2], 'w')
    endif
  endif

  let g:BckOptions = s:bcko

  if s:options_visible 
    call s:BckToggleOpts()
    call s:BckToggleOpts()
  endif
endfunction

function! s:MapKeys()
  nnoremap <buffer> <silent> <Esc>   :call <SID>BckQuit()<cr>
  nnoremap <buffer> <silent> <cr>    :call <SID>BckSelectBuffer('cr')<cr>
  nnoremap <buffer> <silent> <2-LeftMouse> :call <SID>BckSelectBuffer('cr')<cr>
  nnoremap <buffer> <silent> <space> :call <SID>BckToggleOpts()<cr>
  nnoremap <buffer> <silent> <F5>    :call <SID>BckOption(0)<cr> 
  nnoremap <buffer> <silent> <F6>    :call <SID>BckOption(1)<cr> 
  nnoremap <buffer> <silent> <F7>    :call <SID>BckOption(2)<cr> 
  nnoremap <buffer> <silent> <F8>    :call <SID>BckOption(3)<cr> 

  for buf in s:allresults
    exe "nnoremap <buffer> <silent> ". buf.key . "   :call <SID>BckSelectBuffer('" . buf.key . "')<cr>"
  endfor
endfunction

function! s:GetResultsInfo()
  let s:allresults = []
  let [s:allresults, allwidths] = [[], {}]

  for n in s:types
    let allwidths[n] = []
  endfor
 
  let k = 0

  let bu_li = s:output

  for line in bu_li
    let b = {}
    let [full_match, path, line_no, col_no, text; rest] = matchlist(line, '\(.\{-}\):\(.\{-}\):\(.\{-}\):\(.*\)') 
    let b.path = path
    let b.line_no = line_no
    let b.col_no = col_no
    " strip spaces
    let text = substitute(text, '^\s\+\|\s\+$', '', 'g')
    let b.text = text
    let b.index = k

    if (k < len(s:keys))
      let b.key = s:keys[k]
    else
      let b.key = 'J'
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

function! s:BckOpen()
  if !exists("s:lines")
    call Bck("blank", '')
    return
  endif

  exe g:BckSplit . " " . s:GetWindowHeight() . " split"

  if s:local_bufnr < 0
    exe "silent e " . s:name
    let s:local_bufnr = bufnr(s:name)
  else
    exe "b " . s:local_bufnr
    exe s:current_result + 1
  endif
endfunction

" calculate the height of the Bck window
function! s:GetWindowHeight()
  let offset = 2
  return min([len(s:lines) + offset, 20])
endfunction

function! s:BufferPaths()
  let output = []

  redir => lsoutput 
  exe "silent ls"
  redir END

  let bu_li = split(lsoutput, '\n')

  for buf in bu_li
    let bits = split(buf, '"')
    let path = bits[1]
    call add(output, expand(path))
  endfor

  return output
endfunction

"""""""""""""""""""""""""
" Bck - main entry point

function! Bck(cmd, args)
  let args = ''
  if empty(a:args)
    let args = expand('<cword>')
  else
    let args = a:args . join(a:000, ' ')
  endif

  let s:bcko = g:BckOptions

  let cmd = "ack -H --nocolor --nogroup --column"

  if s:bcko[0] ==# 'f'
    let cmd .= " -G " . expand("%:t")
  endif
  if s:bcko[1] ==# 'i'
    let cmd .= " -i"
  endif
  if s:bcko[2] ==# 'r' && s:bcko[0] !=# 'f'
    let cmd .= " -r"
  else
    let cmd .= " -n"
  endif
  if s:bcko[3] ==# 'w'
    let cmd .= " -w"
  endif

  let cmd .= " " . escape(args, '|')

  if s:bcko[0] ==# 'b'
    let cmd .= " " . join(s:BufferPaths(), " ")
  endif

  if (a:cmd ==# 'blank')
    let s:output = []
    let cmd = ''
  else
    if s:bcko[0] !=# 'c' && s:bcko[0] !=# 'b'
      call s:ChangeToRootDirectory()
    endif

    echomsg "running: " . cmd
    redraw

    if exists("g:xolox#shell#version")
      " use vim-shell when available
      let s:output = xolox#shell#execute(cmd, 1)
    else
      let s:output = split(system(cmd), "\n")
    end

    call filter(s:output, "v:val !~# '^ack.pl:'")

    " put the results in the quickfix window as well
    exe "cgete s:output" 

    if g:BckPreserveCWD && s:bcko[0] !=# 'c' && s:bcko[0] !=# 'b'
      exe "cd-"
    endif
  endif

  let s:lines = []
  let searchdata = s:GetResultsInfo()

  for buf in searchdata
    let line = ''
    if buf.key ==# 'J'
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

  if g:BckHidden && a:cmd !=# 'blank'
    unlet s:lines
    echo "done"
    return
  endif
  
  exe g:BckSplit . " " . s:GetWindowHeight() . " split"

  if s:local_bufnr < 0
    exe "silent e ".s:name
    let s:local_bufnr = bufnr(s:name)
  else
    exe "b ". s:local_bufnr
  endif
  
  setlocal modifiable
  let last_query = cmd
  if s:bcko[0] ==# 'b'
    let last_query = args
  endif
  let last_query = escape(last_query, " ")

  exe 'setlocal statusline=Bck:\ ' . len(s:lines) . '\ results,' . '\ last\ query:\ ' . last_query 
  exe 'goto'
  exe '%delete'
  call setline(1, s:lines)
  setlocal nomodifiable

  call s:SetProperties()

  call s:MapKeys()
  call s:BckOptLine("on")
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
  for pattern in g:BckRoots
    let result = s:FindInCurrentPath(pattern)
    if !empty(result)
      return result
    endif
  endfor
endfunction

" Changes the current working directory to the current file's root directory.
function! s:ChangeToRootDirectory()
  if s:bcko[0] ==# 'd' || s:bcko[0] ==# 'f'
    exe 'cd %:p:h'
    return
  endif

  let root_dir = s:FindRootDirectory()
  if !empty(root_dir)
    if exists('+autochdir')
      set noautochdir
    endif
    exe "cd " . fnameescape(root_dir)
  else
    exe 'cd %:p:h'
  endif
endfunction

""""""""""""""""""
" create commands

command! ChangeToRoot call <SID>ChangeToRootDirectory()
command! -bang -nargs=* -complete=file Bck call Bck('grep<bang>', <q-args>)
command! BckOpen call <SID>BckOpen()

