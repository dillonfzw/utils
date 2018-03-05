syntax on
set hlsearch

" activate Pathogen manager
execute pathogen#infect()
filetype plugin indent on

" Recommended Syntastic setting for new user
set statusline+=%#warningmsg#
set statusline+=%{SyntasticStatuslineFlag()}
set statusline+=%*

let g:syntastic_always_populate_loc_list = 1
let g:syntastic_auto_loc_list = 1
let g:syntastic_check_on_open = 1
let g:syntastic_check_on_wq = 0
if $CONDA_PREFIX != ""
    let conda_include = expand($CONDA_PREFIX) . "/include"
    "echomsg conda_include
    let g:syntastic_cpp_include_dirs = [conda_include]
endif
let g:syntastic_cpp_check_header = 1
let g:syntastic_cpp_remove_include_errors = 1


" copied from VIM's cscope help
        if has("cscope")
                set csprg=cscope
                set csto=0
                set cst
                set nocsverb
                " add any database in current directory
                if filereadable("cscope.out")
                    cs add cscope.out
                " else add database pointed to by environment
                elseif $CSCOPE_DB != ""
                    cs add $CSCOPE_DB
                endif
                set csverb
        endif

" If use cst(ags), ctags is not necessary.
"set tags=tags
