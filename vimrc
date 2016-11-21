syntax on
set hlsearch

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
