" LanguageTool: Grammar checker in Vim for English, French, German, etc.
" Maintainer:   Dominique Pellé <dominique.pelle@gmail.com>
" Screenshots:  http://dominique.pelle.free.fr/pic/LanguageToolVimPlugin_en.png
"               http://dominique.pelle.free.fr/pic/LanguageToolVimPlugin_fr.png
" Last Change:  2012/07/01
" Version:      1.21
"
" Long Description:
"
" This plugin integrates the LanguageTool grammar checker into Vim.
" Current version of LanguageTool can check grammar in many languages:
" ast, be, br, ca, da, de, el, en, eo, es, fr, gl, is, it, km, lt, ml, nl,
" pl, pt, ro, ru, sk, sl, sv, tl, uk, zh. See http://www.languagetool.org/
" for more information about LanguageTool.
"
" The script defines 2 Ex commands:
"
" * Use  :LanguageToolCheck  to check grammar in current buffer.
"   This will check for grammar mistakes in text of current buffer
"   and highlight the errors. It also opens a new scratch window with the
"   list of grammar errors with further explanations for each error.
"   Pressing <Enter> in scratch buffer will jump to that error. The
"   location list for the buffer being checked is also populated.
"   So you can use location commands such as :lopen to open the location
"   list window, :lne to jump to the next error, etc.
"
" * Use  :LanguageToolClear  to remove highlighting of grammar mistakes,
"   close the scratch window containing the list of errors, clear and
"   close the location list.
"
" See screenshots of grammar checking in English and French at:
"   http://dominique.pelle.free.fr/pic/LanguageToolVimPlugin_en.png
"   http://dominique.pelle.free.fr/pic/LanguageToolVimPlugin_fr.png
"
" See also screencast demo at:
"    http://shelr.tv/records/4fba8ef99660803e4f00001f
"
" See  :help LanguageTool  for more details
"
" Install Details:
"
" Install the plugin with:
"
"   $ mkdir ~/.vim
"   $ cd ~/.vim
"   $ unzip /path-to/LanguageTool.zip
"   $ vim -c 'helptags ~/.vim/doc'
"
" You also need to install the Java LanguageTool program in order to use
" this plugin. There are 3 possibilities:
"
" 1/ Download the latest official OpenOffice/LibreOffice LanguageTool plugin
"    file LanguageTool-*.oxt from http://www.languagetool.org/
"    Unzip it. This should extract LanguageTool.jar among several other files
"
" 2/ Or download an unofficial nightly build available at:
"    http://www.languagetool.org/download/snapshots/
"
" 3/ Or download the latest LanguageTool from subversion and build
"    it. This ensures that you get the latest version. On Ubuntu, you need
"    to install the ant, openjdk-6-jdk and subversion packages as a
"    prerequisite:
"
"    $ sudo apt-get install openjdk-6-jdk ant subversion
"
"    LanguageTool can then be downloaded and built as follows:
"
"    $ svn co https://languagetool.svn.sourceforge.net/svnroot/languagetool/trunk/JLanguageTool languagetool
"    $ cd languagetool
"    $ ant
"
"    This should build languagetool/dist/LanguageTool.jar.
"
" You then need to set up g:languagetool_jar in your ~/.vimrc with
" the location of this LanguageTool.jar file. For example:
"
"   let g:languagetool_jar=$HOME . '/languagetool/LanguageTool.jar'
"
" License:
"
" The VIM LICENSE applies to LanguageTool.vim plugin
" (see ":help copyright" except use "LanguageTool.vim" instead of "Vim").
"
if &cp || exists("g:loaded_languagetool")
 finish
endif
let g:loaded_languagetool = "1"

" Guess language from 'a:lang' (either 'spelllang' or 'v:lang')
function s:FindLanguage(lang)
  " This replaces things like en_gb en-GB as expected by LanguageTool,
  " only for languages that support variants in LanguageTool.
  let l:language = substitute(substitute(a:lang,
  \  '\(\a\{2,3}\)\(_\a\a\)\?.*',
  \  '\=tolower(submatch(1)) . toupper(submatch(2))', ''),
  \  '_', '-', '')

  " All supported languages by LanguageTool-1.8.
  let l:supportedLanguages =  {
  \  'ast'   : 1,
  \  'be'    : 1,
  \  'br'    : 1,
  \  'ca'    : 1,
  \  'cs'    : 1,
  \  'da'    : 1,
  \  'de'    : 1,
  \  'de-AT' : 1,
  \  'de-CH' : 1,
  \  'de-DE' : 1,
  \  'el'    : 1,
  \  'en'    : 1,
  \  'en-AU' : 1,
  \  'en-CA' : 1,
  \  'en-GB' : 1,
  \  'en-NZ' : 1,
  \  'en-US' : 1,
  \  'en-ZA' : 1,
  \  'eo'    : 1,
  \  'es'    : 1,
  \  'fr'    : 1,
  \  'gl'    : 1,
  \  'is'    : 1,
  \  'it'    : 1,
  \  'km'    : 1,
  \  'lt'    : 1,
  \  'ml'    : 1,
  \  'nl'    : 1,
  \  'pl'    : 1,
  \  'pt'    : 1,
  \  'ro'    : 1,
  \  'ru'    : 1,
  \  'sk'    : 1,
  \  'sl'    : 1,
  \  'sv'    : 1,
  \  'tl'    : 1,
  \  'uk'    : 1,
  \  'zh'    : 1
  \}

  if has_key(l:supportedLanguages, l:language)
    return l:language
  endif

  " Removing the region (if any) and trying again.
  let l:language = substitute(l:language, '-.*', '', '')
  return has_key(l:supportedLanguages, l:language) ? l:language : ''
endfunction

" Return a regular expression used to highlight a grammatical error
" at line a:line in text.  The error starts at character a:start in
" context a:context and its length in context is a:len.
function s:LanguageToolHighlightRegex(line, context, start, len)
  let l:start_idx     = byteidx(a:context, a:start)
  let l:end_idx       = byteidx(a:context, a:start + a:len) - 1
  let l:start_ctx_idx = byteidx(a:context, a:start + a:len)
  let l:end_ctx_idx   = byteidx(a:context, a:start + a:len + 5) - 1

  " The substitute allows to match errors which span multiple lines.
  " The part after \ze gives a bit of context to avoid spurious
  " highlighting when the text of the error is present multiple
  " times in the line.
  return '\V'
  \     . '\%' . a:line . 'l'
  \     . substitute(escape(a:context[l:start_idx : l:end_idx], "'\\"), ' ', '\\_\\s', 'g')
  \     . '\ze'
  \     . substitute(escape(a:context[l:start_ctx_idx : l:end_ctx_idx], "'\\"), ' ', '\\_\\s', 'g')
endfunction

" Unescape XML special characters in a:text.
function s:XmlUnescape(text)
  " Change XML escape char such as &quot; into "
  " Substitution of &amp; must be done last or else something
  " like &amp;quot; would get first transformed into &quot;
  " and then wrongly transformed into "  (correct is &quot;)
  let l:escaped = substitute(a:text,    '&quot;', '"',  'g')
  let l:escaped = substitute(l:escaped, '&apos;', "'",  'g')
  let l:escaped = substitute(l:escaped, '&gt;',   '>',  'g')
  let l:escaped = substitute(l:escaped, '&lt;',   '<',  'g')
  return          substitute(l:escaped, '&amp;',  '\&', 'g')
endfunction

" Set up configuration.
" Returns 0 if success, < 0 in case of error.
function s:LanguageToolSetUp()
  let s:languagetool_disable_rules = exists("g:languagetool_disable_rules")
  \ ? g:languagetool_disable_rules
  \ : 'WHITESPACE_RULE,EN_QUOTES'
  let s:languagetool_win_height = exists("g:languagetool_win_height")
  \ ? g:languagetool_win_height
  \ : 14
  let s:languagetool_encoding = &fenc ? &fenc : &enc

  " Setting up language...
  if exists("g:languagetool_lang")
    let s:languagetool_lang = g:languagetool_lang
  else
    " Trying to guess language from 'spelllang' or 'v:lang'.
    let s:languagetool_lang = s:FindLanguage(&spelllang)
    if s:languagetool_lang == ''
      let s:languagetool_lang = s:FindLanguage(v:lang)
      if s:languagetool_lang == ''
        echoerr 'Failed to guess language from spelllang=['
        \ . &spelllang . '] or from v:lang=[' . v:lang . ']. '
        \ . 'Defauling to English (en). '
        \ . 'See ":help LanguageTool" regarding setting g:languagetool_lang.'
        let s:languagetool_lang = 'en'
      endif
    endif
  endif

  let s:languagetool_jar = exists("g:languagetool_jar")
  \ ? g:languagetool_jar
  \ : $HOME . '/languagetool/dist/LanguageTool.jar'

  if !filereadable(s:languagetool_jar)
    " Hmmm, can't find the jar file.  Try again with expand() in case user
    " set it up as: let g:languagetool_jar = '$HOME/LanguageTool.jar'
    let l:languagetool_jar = expand(s:languagetool_jar)
    if !filereadable(expand(l:languagetool_jar))
      echomsg "LanguageTool cannot be found at: " . s:languagetool_jar
      echomsg "You need to install LanguageTool and/or set up g:languagetool_jar"
      return -1
    endif
    let s:languagetool_jar = l:languagetool_jar
  endif
  return 0
endfunction

" Jump to a grammar mistake (called when pressing <Enter>
" on a particular error in scratch buffer).
function <sid>JumpToCurrentError()
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
    " So finding the column is done using pattern matching with information
    " in error context.
    let l:context = l:error[7][byteidx(l:error[7], l:error[8])
    \                         :byteidx(l:error[7], l:error[8] + l:error[9]) - 1]
    let l:re = s:LanguageToolHighlightRegex(l:error[0], l:error[7], l:error[8], l:error[9])
    echon 'Jump to error ' . l:error_idx . '/' . len(s:errors)
    \ . ' (' . l:rule . ') ...' . l:context . '... @ '
    \ . l:line . 'L ' . l:col . 'C'
    call search(l:re)
    norm zz
  else
    call setpos('.', l:save_cursor)
  endif
endfunction

" This function performs grammar checking of text in the current buffer.
" It highlights grammar mistakes in current buffer and opens a scratch
" window with all errors found.  It also populates the location-list of
" the window with all errors.
" a:line1 and a:line2 parameters are the first and last line number of
" the range of line to check.
" Returns 0 if success, < 0 in case of error.
function s:LanguageToolCheck(line1, line2)
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

  let l:range = a:line1 . ',' . a:line2
  silent exe l:range . 'w!' . l:tmpfilename

  let l:languagetool_cmd = 'java'
  \ . ' -jar '  . s:languagetool_jar
  \ . ' -c '    . s:languagetool_encoding
  \ . ' -d '    . s:languagetool_disable_rules
  \ . ' -l '    . s:languagetool_lang
  \ . ' --api ' . l:tmpfilename

  sil exe '%!' . l:languagetool_cmd
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
    " The fromx and tox given by LanguageTool are not reliable.
    " They are even sometimes negative!
    let l:l1 = matchlist(l:l, 'fromy=\"\(\d\+\)\"\s\+'
    \ .                       'fromx=\"\(-\?\d\+\)\"\s\+'
    \ .                         'toy=\"\(\d\+\)\"\s\+'
    \ .                         'tox=\"\(-\?\d\+\)\"\s\+'
    \ .                      'ruleId=\"\([^"]*\)\"')

    " From LanguageTool-1.0 to LanguageTool-1.1, subId=(...) was
    " introduced in XML output.
    let l:l2 = matchlist(l:l, 'subId=\"\(\d\+\)\"')
    let l:l3 = matchlist(l:l, 'msg=\"\([^"]*\)\"\s\+'
    \ .              'replacements=\"\([^"]*\)\"\s\+'
    \ .                   'context=\"\([^"]*\)\"\s\+'
    \ .             'contextoffset=\"\(\d\+\)\"\s\+'
    \ .               'errorlength=\"\(\d\+\)\"')

    " From LanguageTool-1.7 to LanguageTool-1.8 and optional
    " url="..." was introduced in XML output.
    let l:l4 = matchlist(l:l, 'url=\"\([^"]*\)\"')

    " l:error[0] ... fromy
    " l:error[1] ... fromx
    " l:error[2] ... toy
    " l:error[3] ... tox
    " l:error[4] ... ruleId
    " l:error[5] ... subId
    " l:error[6] ... msg
    " l:error[7] ... replacement
    " l:error[8] ... context
    " l:error[9] ... contextoffset
    " l:error[10] .. errorlength
    " l:error[11] .. url
    let l:error = l:l1[1:5]
    \           + (len(l:l2) > 0 ? ([':' . l:l2[1]]) : [''])
    \           + l:l3[1:5]
    \           + (len(l:l4) > 0 ? ([l:l4[1]]) : [''])

    " Make line/column number start at 1 rather than 0.
    " Make also line number absolute as in buffer.
    let l:error[0] += a:line1
    let l:error[1] += 1
    let l:error[2] += a:line1
    let l:error[3] += 1

    let l:error[6]  = s:XmlUnescape(l:error[6])
    let l:error[8]  = s:XmlUnescape(l:error[8])
    let l:error[7]  = s:XmlUnescape(l:error[7])
    let l:error[11] = s:XmlUnescape(l:error[11])
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
    syn match LanguageToolLabelMoreInfo '^More info:.*' contains=LanguageToolUrl
    syn match LanguageToolErrorCount '^Error:\s\+\d\+.\d\+'
    syn match LanguageToolUrl '^More info:\s*\zs.*' contained
    let l:i = 0
    for l:error in s:errors
      call append('$', 'Error:      '
      \ . (l:i + 1) . '/' . len(s:errors)
      \ . ' ('  . l:error[4] . l:error[5] . ')'
      \ . ' @ ' . l:error[0] . 'L ' . l:error[1] . 'C')
      call append('$', 'Message:    ' . l:error[6])
      call append('$', 'Context:    ' . l:error[8])

      if l:error[4] =~ 'HUNSPELL_RULE\|HUNSPELL_NO_SUGGEST_RULE\|MORFOLOGIK_RULE_.*'
        exe "syn match LanguageToolSpellingError '"
        \ . '\%'  . line('$') . 'l\%9c'
        \ . '.\{' . (4 + l:error[9]) . '}\zs'
        \ . '.\{' .     (l:error[10]) . "}'"
      else
        exe "syn match LanguageToolGrammarError '"
        \ . '\%'  . line('$') . 'l\%9c'
        \ . '.\{' . (4 + l:error[9]) . '}\zs'
        \ . '.\{' .     (l:error[10]) . "}'"
      endif
      if len(l:error[7]) > 0
        call append('$', 'Correction: ' . l:error[7])
      endif
      if len(l:error[11]) > 0
        call append('$', 'More info:  ' . l:error[11])
      endif
      call append('$', '')
      let l:i += 1
    endfor
    exe "norm z" . s:languagetool_win_height . "\<CR>"
    0
    map <silent> <buffer> <CR>          :call <sid>JumpToCurrentError()<CR>
    redraw
    echon 'Press <Enter> on error in scratch buffer to jump its location'
    exe "norm \<C-W>\<C-P>"
  else
    " Negative s:languagetool_win_height -> no scratch window.
    bd!
    unlet! s:languagetool_error_buffer
  endif
  let s:languagetool_text_win = winnr()

  " Also highlight errors in original buffer and populate location list.
  setlocal errorformat=%f:%l:%c:%m
  for l:error in s:errors
    let l:re = s:LanguageToolHighlightRegex(l:error[0], l:error[8], l:error[9], l:error[10])
    if l:error[4] =~ 'HUNSPELL_RULE\|HUNSPELL_NO_SUGGEST_RULE\|MORFOLOGIK_RULE_.*'
      exe "syn match LanguageToolSpellingError '" . l:re . "'"
      laddexpr expand('%') . ':'
      \ . l:error[0] . ':' . l:error[1] . ':'
      \ . l:error[4] . ' ' . l:error[6]
    else
      exe "syn match LanguageToolGrammarError '" . l:re . "'"
      laddexpr expand('%') . ':'
      \ . l:error[0] . ':' . l:error[1] . ':'
      \ . l:error[4] . ' ' . l:error[6]
    endif
  endfor
  return 0
endfunction

" This function clears syntax highlighting created by LanguageTool plugin
" and removes the scratch window containing grammar errors.
function s:LanguageToolClear()
  if exists('s:languagetool_error_buffer')
    if bufexists(s:languagetool_error_buffer)
      sil! exe "bd! " . s:languagetool_error_buffer
    endif
  endif
  if exists('s:languagetool_text_win')
    let l:win = winnr()
    exe s:languagetool_text_win . 'wincmd w'
    syn clear LanguageToolGrammarError
    syn clear LanguageToolSpellingError
    lexpr ''
    lclose
    exe l:win . 'wincmd w'
  endif
  unlet! s:languagetool_error_buffer
  unlet! s:languagetool_error_win
  unlet! s:languagetool_text_win
endfunction

hi def link LanguageToolCmd           Comment
hi def link LanguageToolLabel         Label
hi def link LanguageToolLabelMoreInfo Label
hi def link LanguageToolGrammarError  Error
hi def link LanguageToolSpellingError WarningMsg
hi def link LanguageToolErrorCount    Title
hi def link LanguageToolUrl           Underlined

com! -nargs=0          LanguageToolClear :call s:LanguageToolClear()
com! -nargs=0 -range=% LanguageToolCheck :call s:LanguageToolCheck(<line1>,
                                                                 \ <line2>)
