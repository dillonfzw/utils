
"
"mkdir -p ~/.vim/autolscrooloose/syntasticoad ~/.vim/bundle && \
"curl -LSso ~/.vim/autoload/pathogen.vim https://tpo.pe/pathogen.vim
"
"cd ~/.vim/bundle && \
"git clone https://github.com/scrooloose/syntastic.git
"
" activate Pathogen manager
execute pathogen#infect()
filetype plugin indent on
" show existing tab with 4 spaces width
set tabstop=4
" when indenting with '>', use 4 spaces width
set shiftwidth=4
" On pressing tab, insert 4 spaces
set expandtab

syntax on
set hlsearch

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
"let g:syntastic_cpp_remove_include_errors = 1


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

" https://vi.stackexchange.com/a/505
" Carpetsmoker answered Feb 6 '15 at 9:41
" TODO: paste here..
