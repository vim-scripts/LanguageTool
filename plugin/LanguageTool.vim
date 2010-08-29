" LanguageTool: Grammar checker for Vim using LanguageTool.
" Maintainer:   Dominique Pellé <dominique.pelle@gmail.com>
" Screenshots:  http://dominique.pelle.free.fr/pic/LanguageToolVimPlugin_en.png
"               http://dominique.pelle.free.fr/pic/LanguageToolVimPlugin_fr.png
" Last Change:  2010/08/29
" Version:      1.2
" 
" Long Description:
"
" This plugin integrates the LanguageTool grammar checker into Vim.
" Current version of LanguageTool can check grammar in many languages: 
" en, de, pl, fr, es, it, nl, lt, uk, ru, sk, sl, sv, ro, is, gl, ca, da,
" ml, be. See http://www.languagetool.org/ for more information about 
" LanguageTool.
"
" The script defines 2 commands:
"
" * Use  :LanguageToolCheck  to check grammar in current buffer.
"   This will check for grammar mistakes in text of current buffer 
"   and highlight the errors.  It also opens a new scratch window with the
"   list of grammar errors with further explanations for each error.
"   Pressing <Enter> or click on an error in scratch buffer will jump 
"   to that error.
"
" * Use  :LanguageToolClear  to remove highlighting of grammar mistakes
"   and close the scratch window containing the list of errors.
"
" See screenshots of grammar checking in English and French at:
"   http://dominique.pelle.free.fr/pic/LanguageToolVimPlugin_en.png
"   http://dominique.pelle.free.fr/pic/LanguageToolVimPlugin_fr.png
"
" You can customize this plugin by setting the following variables in 
" your ~/.vimrc (plugin sets some default values).
"
"   g:languagetool_jar  
"       This variable specifies the location of the LanguageTool java
"       grammar checker program.
"       Default is: $HOME/JLanguageTool/dist/LanguageTool.jar
"
"   g:languagetool_disable_rules
"       This variable specifies checker rules which are disabled.
"       Each disabled rule must be comma separated
"       Default is: WHITESPACE_RULE,EN_QUOTES
"
"   g:languagetool_win_height
"       This variable specifies the height of the scratch window which 
"       contains all grammatical mistakes with some explanations. You 
"       can use a negative value to disable opening the scratch window.
"       Default is: 14
"
" You can also customize the following syntax highlighting groups:
"   LanguageToolError
"   LanguageToolCmd
"   LanguageToolLabel
"   LanguageToolErrorCount
"
" Language is selected automatically from the 'spelllang' option.
" Character encoding is selected automatically from the 'fenc' option
" or from 'enc' option if 'fenc' is empty.
"
" Being able to click on errors in scratch buffer to jump to error
" requires the mouse to be enabled. You can enable the mouse with
" with 'set mouse=a' in your ~/.vimrc.
"
" Bugs: 
"
" * Column number reported by LanguageTool indicating the location of the
"   error is sometimes incorrect. There is an opened ticket about this bug:
"   http://sourceforge.net/tracker/?func=detail&aid=3054895&group_id=110216&atid=655717
"   The script currently works around it by doing patten matching with 
"   information context but it's not a perfect workaround: it can cause
"   spurious highlighting of errors in rare cases.
"
" ToDo:
"
" * Help page
" * Should use location list (not sure yet how this works).
" * Implement checking of text limited to visual selection
" * Use balloons to show info about errors (for gvim only)
"
" Install Details:
"
" Copy this plugin script LanguageTool.vim in $HOME/.vim/plugin/.
"
" You also need to install the Java LanguageTool program in order to use
" this plugin.  On Ubuntu, you need to install the ant, sun-java6-jdk, and cvs
" packages:
"
" $ sudo apt-get install sun-java6-jdk ant cvs
"
" LanguageTool can then be downloaded and built as follows:
"
" $ cvs -z3 \
" -d:pserver:anonymous@languagetool.cvs.sourceforge.net:/cvsroot/languagetool \
" co -P JLanguageTool
" $ cd JLanguageTool
" $ ant
"
" This should build JLanguageTool/dist/LanguageTool.jar.
"
" Downloading LanguageTool from CVS ensures you get the latest version.
" Alternatively, rather than building LanguageTool.jar from CVS, you
" can download the openoffice extension oxt and unzip it.
"
" You then need to set up g:languagetool_jar in your ~/.vimrc with
" the location of the LanguageTool.jar file.
"
" License: The VIM LICENSE applies to LanguageTool.vim plugin
" (see ":help copyright" except use "LanguageTool.vim" instead of "Vim").
"
if &cp || exists("g:loaded_languagetool")
 finish
endif
let g:loaded_languagetool = "1"

" Set up configuration.
" Returns 0 if success, < 0 in case of error.
function s:LanguageToolSetUp()
  let s:languagetool_jar = exists("g:languagetool_jar")
  \ ? g:languagetool_jar
  \ : $HOME . '/JLanguageTool/dist/LanguageTool.jar'
  let s:languagetool_disable_rules = exists("g:languagetool_disable_rules")
  \ ? g:languagetool_disable_rules
  \ : 'WHITESPACE_RULE,EN_QUOTES'
  let s:languagetool_win_height = exists("g:languagetool_win_height")
  \ ? g:languagetool_win_height
  \ : 14
  let s:languagetool_encoding = &fenc ? &fenc : &enc

  " Only pick the first 2 letters of spelllang, so "en_us" for example
  " is transformed into "en".
  let s:languagetool_lang = (&spelllang)[:1]
  if !filereadable(s:languagetool_jar)
    echomsg "LanguageTool cannot be found at: " . s:languagetool_jar
    echomsg "You need to install LanguageTool and/or set up g:languagetool_jar"
    return -1
  endif
  return 0
endfunction

" Jump to a grammar mistake (called when pressing <Enter> or clicking
" on a particular error in scratch buffer).
" mouse parameter is 1 if called from a mouse event, 0 otherwise.
function <sid>JumpToCurrentError(mouse)
  if a:mouse
    call feedkeys("\<LeftMouse>")
    let l:c = getchar()
    if l:c == "\<LeftMouse>" && v:mouse_win == s:languagetool_error_win
      exe v:mouse_win . 'wincmd w'
      exe v:mouse_lnum
      exe 'norm ' . v:mouse_col . '|'
    endif
  endif
  let l:save_cursor = getpos('.')
  norm $
  if search('^Error:\s\+', 'beW') > 0
    let l:error_idx = expand('<cword>')
    let l:error = s:errors[l:error_idx - 1]
    let l:line = l:error[0]
    let l:col  = l:error[1]
    let l:rule = l:error[4]
    call setpos('.', l:save_cursor)
    exe s:languagetool_text_win . 'wincmd w'
    exe 'norm ' . l:line . 'G0'

    " The line number is correct but the column number given by LanguageTool is
    " sometimes incorrect. See opened ticket:
    " http://sourceforge.net/tracker/?func=detail&aid=3054895&group_id=110216&atid=655717
    " So finding the column is done using patten matching with information
    " in error context.
    let l:context = l:error[7][byteidx(l:error[7], l:error[8])
    \                         :byteidx(l:error[7], l:error[8] + l:error[9] - 1)]

    " This substitute allows matching when error spans multiple lines.
    let l:re = '\V' . substitute(escape(l:context, "\'"), ' ', '\\_\\s', 'g')

    echo 'Jump to error ' . l:error_idx . '/' . len(s:errors)
    \ . ' (' . l:rule . ') ...' . l:context . '... @ ' 
    \ . l:line . 'L ' . l:col . 'C'
    call search(l:re)
    norm zz
  else
    echo "No error under cursor"
    call setpos('.', l:save_cursor)
  endif
endfunction

" This function performs grammar checking of text in the current buffer.
" It highlights grammar mistakes in current buffer and opens a scratch
" window with all errors found.
" Returns 0 if success, < 0 in case of error.
function s:LanguageToolCheck()
  let l:save_cursor = getpos('.')
  if s:LanguageToolSetUp() < 0
    return -1
  endif
  call s:LanguageToolClear()
  sil %y
  botright new
  let s:languagetool_error_buffer = bufnr('%')
  let s:languagetool_error_win    = winnr()
  sil put!

  " LanguageTool somehow gives incorrect line/column numbers when 
  " reading from stdin so we need to use a temporary file to get 
  " correct results.
  let l:tmpfilename = tempname()
  silent exe "w!" . l:tmpfilename

  let l:languagetool_cmd = 'java'
  \ . ' -jar '  . s:languagetool_jar 
  \ . ' -c '    . s:languagetool_encoding
  \ . ' -d '    . s:languagetool_disable_rules
  \ . ' -l '    . s:languagetool_lang
  \ . ' --api ' . l:tmpfilename

  exe '%!' . l:languagetool_cmd
  call delete(l:tmpfilename)

  if v:shell_error
    echoerr 'Command [' . l:languagetool_cmd . '] failed with error: '
    \      . v:shell_error
    call s:LanguageToolClear()
    return -1
  endif

  " Loop on all errors in XML output of LanguageTool and
  " collect information about all errors in list s:errors
  let s:errors = []
  while search('^<error ', 'eW') > 0
    let l:l  = getline('.')
    let l:l1 = matchlist(l,  'fromy=\"\(\d\+\)\" '
    \ .                      'fromx=\"\(\d\+\)\" '
    \ .                        'toy=\"\(\d\+\)\" '
    \ .                        'tox=\"\(\d\+\)\" ')
    let l:l2 = matchlist(l, 'ruleId=\"\(\w\+\)\" '
    \ .                        'msg=\"\(.*\)\" '
    \ .               'replacements=\"\(.*\)\" '
    \ .                    'context=\"\(.*\)\" '
    \ .              'contextoffset=\"\(\d\+\)\" '
    \ .                'errorlength=\"\(\d\+\)\"')
    let l:error = l:l1[1:4] + l:l2[1:6]

    " Make line/column number start at 1 rather than 0.
    let l:error[0] += 1  
    let l:error[1] += 1  
    let l:error[2] += 1
    let l:error[3] += 1
    call add(s:errors, l:error)
  endwhile

  if s:languagetool_win_height >= 0
    " Reformat the output of LanguageTool (XML is not human friendly) and
    " set up syntax highlighting in the buffer which shows all errors.
    sil %d
    call append(0, '# ' . l:languagetool_cmd)
    set bt=nofile
    setlocal nospell
    syn clear
    syn match LanguageToolCmd   '\%1l.*'
    syn match LanguageToolLabel '^\(Pos\|Rule\|Context\|Message\|Correction\):'
    syn match LanguageToolErrorCount '^Error:\s\+\d\+.\d\+'
    let l:i = 0
    for l:error in s:errors
      call append('$', 'Error:      ' 
      \ . (l:i + 1) . '/' . len(s:errors)
      \ . ' ('  . l:error[4] . ')'
      \ . ' @ ' . l:error[0] . 'L '
      \ .         l:error[1] . 'C')
      call append('$', 'Message:    ' . l:error[5])
      call append('$', 'Context:    ' . l:error[7])

      exe "syn match LanguageToolError '"
      \ . '\%'  . line('$') . 'l\%9c'
      \ . '.\{' . (4 + l:error[8]) . '}\zs'
      \ . '.\{' . (l:error[9]) . "}'"
      call append('$', 'Correction: ' . l:error[6])
      call append('$', '')
      let l:i += 1
    endfor
    exe "norm z" . s:languagetool_win_height . "\<CR>"
    0
    map <silent> <buffer> <CR> :call <sid>JumpToCurrentError(0)<CR>
    map <silent> <LeftMouse>   :call <sid>JumpToCurrentError(1)<CR>
    redraw
    echo 'Press <Enter> or click on an error in scratch buffer '
    \ .  'to jump its location'
    exe "norm \<C-W>\<C-P>"
  else
    " Negative s:languagetool_win_height -> no scratch window.
    bd!
    unlet! s:languagetool_error_buffer
  endif
  let s:languagetool_text_win = winnr()

  " Also highlight errors in original buffer.
  for l:error in s:errors
    let l:re = l:error[7][byteidx(l:error[7], l:error[8])
    \                    :byteidx(l:error[7], l:error[8] + l:error[9] - 1)]
    " This substitute allows matching when error spans multiple lines.
    let l:re = '\%' . l:error[0] . 'l\V' 
    \ . substitute(escape(l:re, "\'"), ' ', '\\_\\s', 'g')
    exe "syn match LanguageToolError '" . l:re . "'"
  endfor
  return 0
endfunction

" This function clears syntax highlighting created by LanguageTool plugin
" and removes the scratch window containing grammatical errors.
function s:LanguageToolClear()
  if exists('s:languagetool_error_buffer') 
    if bufexists(s:languagetool_error_buffer)
      exe "bd! " . s:languagetool_error_buffer
    endif
  endif
  if exists('s:languagetool_text_win') 
    let l:win = winnr()
    exe s:languagetool_text_win . 'wincmd w'
    syn clear LanguageToolError
    exe l:win . 'wincmd w'
  endif
  unlet! s:languagetool_error_buffer
  unlet! s:languagetool_error_win
  unlet! s:languagetool_text_win
  exe "sil! unmap <LeftMouse>"
endfunction

hi def link LanguageToolCmd        Comment
hi def link LanguageToolLabel      Label
hi def link LanguageToolError      Error
hi def link LanguageToolErrorCount Title

com! -nargs=0 LanguageToolCheck :call s:LanguageToolCheck()
com! -nargs=0 LanguageToolClear :call s:LanguageToolClear()
