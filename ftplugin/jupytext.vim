" Since jupytext isn't a proper filetype, this can be triggered by
" `set ft=jupytext | filetype detect`

function! GetJupytextPercentFold(linenum)
    if getline(a:linenum) =~ "^#\\s%%"
        " start fold at # %%
        return ">1"
    elseif getline(a:linenum+1) =~ "^#\\s%%"
        " end fold at the line before the next # %%
        return "<1"
    else
        " keep the previous foldlevel
        return "-1"
    endif
endfunction

if g:jupytext_fmt ==# "py:percent"
    setlocal foldexpr=GetJupytextPercentFold(v:lnum)
endif
