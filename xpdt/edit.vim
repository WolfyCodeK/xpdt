if has('termguicolors')
  set termguicolors
endif
syntax on
set background=dark

highlight Normal        guifg=#F8F8F2 guibg=NONE
highlight Comment       guifg=#75715E
highlight Constant      guifg=#BE84FF
highlight Number        guifg=#BE84FF
highlight Boolean       guifg=#BE84FF
highlight Float         guifg=#BE84FF
highlight String        guifg=#E6DB74
highlight Character     guifg=#E6DB74
highlight Identifier    guifg=#F8F8F2
highlight Function      guifg=#A6E22E
highlight Statement     guifg=#F92672
highlight Conditional   guifg=#F92672
highlight Repeat        guifg=#F92672
highlight Label         guifg=#F92672
highlight Operator      guifg=#F92672
highlight Keyword       guifg=#F92672
highlight Exception     guifg=#F92672
highlight PreProc       guifg=#F92672
highlight Include       guifg=#F92672
highlight Define        guifg=#F92672
highlight Macro         guifg=#F92672
highlight PreCondit     guifg=#F92672
highlight Type          guifg=#66D9EF
highlight StorageClass  guifg=#66D9EF
highlight Structure     guifg=#66D9EF
highlight Typedef       guifg=#66D9EF
highlight Special       guifg=#FD971F
highlight SpecialChar   guifg=#FD971F
highlight Title         guifg=#A6E22E
highlight Todo          guifg=#272822 guibg=#E6DB74
highlight LineNr        guifg=#75715E
highlight NonText       guifg=#75715E

highlight pythonReplBool  guifg=#BE84FF
highlight pythonReplKwarg guifg=#FD971F
highlight pythonReplClass guifg=#66D9EF gui=underline
function! s:XplrPyHi()
  if &filetype !=# 'python'
    return
  endif
  syntax keyword pythonReplBool True False None
  syntax match pythonReplKwarg "\<\h\w*\ze="
  syntax keyword pythonStatement class
  syntax match pythonReplClass "\%(\<class\s\+\)\@<=\h\w*"
endfunction
augroup xplrpy
  autocmd!
  autocmd Syntax * call s:XplrPyHi()
augroup END
call s:XplrPyHi()

set number
set autoread
set updatetime=1000
autocmd CursorHold,CursorHoldI * silent! checktime
if has('timers')
  call timer_start(1000, {-> execute('silent! checktime')}, {'repeat': -1})
endif
