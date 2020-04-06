" Name: jupytext.vim
" Last Change: Nov 10, 2019
" Author:  Michael Goerz <https://michaelgoerz.net>
" Plugin Website: https://github.com/goerz/jupytext.vim
" Summary: Vim plugin for editing Jupyter ipynb files via jupytext
" Version: 0.1.2+dev
" License:
"    MIT License
"
"    Copyright (c) 2019 Michael Goerz
"
"    Permission is hereby granted, free of charge, to any person obtaining a
"    copy of this software and associated documentation files (the
"    "Software"), to deal in the Software without restriction, including
"    without limitation the rights to use, copy, modify, merge, publish,
"    distribute, sublicense, and/or sell copies of the Software, and to permit
"    persons to whom the Software is furnished to do so, subject to the
"    following conditions:
"
"    The above copyright notice and this permission notice shall be included
"    in all copies or substantial portions of the Software.
"
"    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN
"    NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
"    DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
"    OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
"    USE OR OTHER DEALINGS IN THE SOFTWARE.
"

" for all the formates that jupytext takes for --to, the file extension that
" should be used for the linked file
let s:jupytext_extension_map = {
\   'rmarkdown': 'Rmd',
\   'markdown': 'md',
\   'python': 'py',
\   'julia': 'jl',
\   'c++': 'cpp',
\   'scheme': 'ss',
\   'bash': 'sh',
\   'md': 'md',
\   'Rmd': 'Rmd',
\   'r': 'r',
\   'R': 'r',
\   'py': 'py',
\   'jl': 'jl',
\   'cpp': 'cpp',
\   'ss': 'ss',
\   'sh': 'sh',
\   'md:markdown': 'md',
\   'Rmd:rmarkdown': 'Rmd',
\   'r:spin': 'r',
\   'R:spin': 'r',
\   'py:light': 'py',
\   'R:light': 'r',
\   'r:light': 'r',
\   'jl:light': 'jl',
\   'cpp:light': 'cpp',
\   'ss:light': 'ss',
\   'sh:light': 'sh',
\   'py:percent': 'py',
\   'R:percent': 'R',
\   'r:percent': 'r',
\   'jl:percent': 'jl',
\   'cpp:percent': 'cpp',
\   'ss:percent': 'ss',
\   'sh:percent': 'sh',
\   'py:sphinx': 'py',
\   'py:sphinx-rst2md': 'py',
\ }



function s:debugmsg(msg)
    if g:jupytext_print_debug_msgs
        echomsg("DBG: ".a:msg)
    endif
endfunction

function jupytext#read_from_ipynb()
    au! jupytext_ipynb * <buffer>
    let l:filename = resolve(expand("<afile>:p"))
    let l:fileroot = fnamemodify(l:filename, ':r')
    if get(s:jupytext_extension_map, g:jupytext_fmt, 'none') == 'none'
        echoerr "Invalid jupytext_fmt: ".g:jupytext_fmt
        return
    endif
    let b:jupytext_file = s:get_jupytext_file(l:filename, g:jupytext_fmt)
    let b:jupytext_file_exists = filereadable(b:jupytext_file)
    let l:filename_exists = filereadable(l:filename)
    call s:debugmsg("filename: ".l:filename)
    call s:debugmsg("filename exists: ".l:filename_exists)
    call s:debugmsg("jupytext_file: ".b:jupytext_file)
    call s:debugmsg("jupytext_file exists: ".b:jupytext_file_exists)
    if (l:filename_exists && !b:jupytext_file_exists)
        call s:debugmsg("Generate file ".b:jupytext_file)
        let l:cmd = g:jupytext_command." --to=".g:jupytext_fmt
        \         . " --output=".shellescape(b:jupytext_file) . " "
        \         . shellescape(l:filename)
        call s:debugmsg("cmd: ".l:cmd)
        let l:output=system(l:cmd)
        call s:debugmsg(l:output)
        if v:shell_error
            echoerr l:cmd.": ".v:shell_error
            return
        endif
    endif
    if filereadable(b:jupytext_file)
        " jupytext_file does not exist if filename_exists was false, e.g. when
        " we edit a new file (vim new.ipynb)
        call s:debugmsg("read ".fnameescape(b:jupytext_file))
        silent execute "read ++enc=utf-8 ".fnameescape(b:jupytext_file)
    endif
    if b:jupytext_file_exists
        let l:register_unload_cmd = "autocmd jupytext_ipynb BufUnload <buffer> call s:cleanup(\"".fnameescape(b:jupytext_file)."\", 0)"
    else
        let l:register_unload_cmd = "autocmd jupytext_ipynb BufUnload <buffer> call s:cleanup(\"".fnameescape(b:jupytext_file)."\", 1)"
    endif
    call s:debugmsg(l:register_unload_cmd)
    silent execute l:register_unload_cmd

    let l:register_write_cmd = "autocmd jupytext_ipynb BufWriteCmd,FileWriteCmd <buffer> call s:write_to_ipynb()"
    call s:debugmsg(l:register_write_cmd)
    silent execute l:register_write_cmd

    let l:ft = get(g:jupytext_filetype_map, g:jupytext_fmt,
    \              g:jupytext_filetype_map_default[g:jupytext_fmt])
    call s:debugmsg("filetype: ".l:ft)
    silent execute "setl fenc=utf-8 ft=".l:ft
    " In order to make :undo a no-op immediately after the buffer is read,
    " we need to do this dance with 'undolevels'.  Actually discarding the
    " undo history requires performing a change after setting 'undolevels'
    " to -1 and, luckily, we have one we need to do (delete the extra line
    " from the :r command)
    let levels = &undolevels
    set undolevels=-1
    silent 1delete
    let &undolevels = levels
    if has("patch-8.1.1113")
        silent execute "autocmd jupytext_ipynb BufEnter <buffer> ++once redraw | echo fnamemodify(b:jupytext_file, ':.').' via jupytext.'"
    else
        silent execute "autocmd jupytext_ipynb BufEnter <buffer> redraw | echo fnamemodify(b:jupytext_file, ':.').' via jupytext.'"
    endif

endfunction


function s:get_jupytext_file(filename, fmt)
    " strip file extension
    let l:fileroot = fnamemodify(a:filename, ':r')
    " the folder in which filename is
    let l:head = fnamemodify(l:fileroot, ':h')
    " the fileroot without the folder
    let l:tail = fnamemodify(l:fileroot, ':t')
    " file extension from fmt
    let l:extension = s:jupytext_extension_map[a:fmt]
    let l:jupytext_file = l:fileroot . "." . l:extension
    return l:jupytext_file
endfunction


function s:write_to_ipynb() abort
    let filename = resolve(expand("<afile>:p"))
    call s:debugmsg("overwriting ".fnameescape(b:jupytext_file))
    silent execute "write! ".fnameescape(b:jupytext_file)
    call s:debugmsg("Updating notebook from ".b:jupytext_file)
    let l:cmd = g:jupytext_command." --from=" . g:jupytext_fmt
    \         . " " . g:jupytext_to_ipynb_opts . " "
    \         . shellescape(b:jupytext_file)
    call s:debugmsg("cmd: ".l:cmd)
    if has("job") || has("nvim")
        call s:async_system(l:cmd, "s:jupytext_exit_callback")
    else
        let l:output=system(l:cmd)
        call s:debugmsg(l:output)
        if v:shell_error
            echoerr l:cmd.": ".v:shell_error
        else
            setlocal nomodified
            echo expand("%") . " saved via jupytext."
        endif
    endif
endfunction

function! s:async_system(cmd, callback)
    echom a:cmd
    if has("nvim")
        call jobstart(a:cmd, {"on_exit": function(a:callback)})
    else
        call job_start(a:cmd, {"exit_cb": function(a:callback . "_vim"), "err_io": "out", "out_io": "file", "out_name": "/tmp/jupytext_vim_job_out.txt"})
    endif
endfunction

function s:jupytext_exit_callback_vim(job, exit_status)
    echom a:exit_status
    echom a:job
    call s:jupytext_exit_callback(a:job, a:exit_status, 0)
endfunction

function s:jupytext_exit_callback(id, data, event) abort
    if a:data == 0
        setlocal nomodified
        echohl ModeMsg
        echomsg "jupytext.vim: updated notebook " . expand("%")
        echohl Normal
    else
        echohl ErrorMsg
        echomsg "jupytext.vim: update failed for notbook " . expand("%")
        echohl Normal
    endif
endfunction

function s:cleanup(jupytext_file, delete)
    call s:debugmsg("a:jupytext_file:".a:jupytext_file)
    if a:delete
        call s:debugmsg("deleting ".fnameescape(a:jupytext_file))
        call delete(expand(fnameescape(a:jupytext_file)))
    endif
endfunction
