let g:tpane_dir = expand('<sfile>:p:h:h')

" function! s:Test(cmd)
"     if a:cmd == ""
"         let curfile = expand("%")
"         let curfile_is_test = (curfile =~ "_test\.go$")
" 
"         if exists("g:LAST_TEST") && g:LAST_TEST != "" && ! curfile_is_test
"             let cmd = g:LAST_TEST
"         else
"             let cmd = curfile
"         endif
"     else
"         let cmd = a:cmd
"     endif
" 
"     let g:LAST_TEST = cmd
" 
"     call TPaneExec(g:TEST_RUNNER . " " . cmd, 'test', 0)
" endfunction

function! s:Run(cmd)
    call TPaneExec(0, 'run', len(a:cmd) ? a:cmd : g:EXECUTABLE)
endfunction

function! s:Build(cmd)
    call TPaneExec(0, 'build', len(a:cmd) ? a:cmd : g:BUILD_COMMAND)
endfunction

function! s:Test(cmd)
    call TPaneExec(0, 'test', len(a:cmd) ? a:cmd : g:TEST_RUNNER)
endfunction

function! s:Term(cmd)
    call TPaneExec(1, 'terminal', a:cmd)
endfunction

function! TPaneExec(interactive, log, ...)
    if len(a:000) > 1
        echoerr 'too many arguments to exec'
        return
    endif

    let cmd = len(a:000) ? a:000[0] : ''
    let flags = '-t '
    if a:interactive
        let flags = flags . '-i '
    endif
    return system(g:tpane_dir . "/bin/run_pane.sh " . flags . "'" . a:log . "' " . cmd)
endfunction

function! s:DefaultSettings(settings)
    for [name, value] in items(a:settings)
        let g:{name}=value
    endfor
endfunction

function! s:GetSettings(settings)
    let buf = ''
    for setting in keys(a:settings)
        if !exists('g:' . setting)
            echoerr "g:" . setting . " is unset"
            throw "g:" . setting . " is unset"
        endif
        let name = "g:" . setting
        let buf = buf . 'let ' . name . "='" . eval(name) . "'\n"
    endfor
    return buf
endfunction

function! s:SetSettings()
    norm ggyG
    @"
endfunction

function! s:EditSettings(settings)
    tabnew
    setlocal buftype=nofile bufhidden=wipe
    let old_o = @o
    let @o = s:GetSettings(a:settings)
    silent put o
    let @o = old_o
    au BufLeave <buffer> call s:SetSettings()
endfunction

let s:TestPlugin = {}

function! s:TestPlugin.Activate(path)
    exec "Test " . (a:path.str({'format': 'Edit'}))
    call nerdtree#closeTreeIfOpen()
endfunction

command! -nargs=0 -bar -complete=shellcmd TPaneExit call TPaneExec(0, "exit")
command! -nargs=? -bar -complete=shellcmd Build     call s:Build(<q-args>)
command! -nargs=? -bar -complete=shellcmd Run       call s:Run(<q-args>)
command! -nargs=? -bar -complete=shellcmd Test      call s:Test(<q-args>)
command! -nargs=1 -bar -complete=shellcmd Term      call s:Term(<q-args>)
command! -nargs=1 -bar -complete=shellcmd System    call system(<q-args>)

let s:settings = {
    \ 'BUILD_COMMAND': 'make all',
    \ 'EXECUTABLE': '',
    \ 'TEST_DIRECTORY': '.',
    \ 'TEST_RUNNER': '',
    \ 'WORK_DIRECTORY': '.',
    \ 'LAST_TEST': '',
 \ }
if exists("g:TPANE_SETTINGS")
    for [name, value] in items(g:TPANE_SETTINGS)
        let s:settings[name]=value
    endfor
endif

command! -nargs=0 Settings call s:EditSettings(s:settings)
command! -nargs=0 DefaultSettings call s:DefaultSettings(s:settings)

DefaultSettings

function! WindowMotion(dir) "{{{
    let dir = a:dir
 
    let old_winnr = winnr()
    execute "wincmd " . dir
    if old_winnr != winnr()
        return
    endif
 
    if dir == 'h'
        let dir = '-L'
    elseif dir == 'j'
        let dir = '-D'
    elseif dir == 'k'
        let dir = '-U'
    elseif dir == 'l'
        let dir = '-R'
    endif
    call system('tmux select-pane ' . dir)
endfunction

nnoremap <silent> <C-h> :call WindowMotion('h')<cr>
nnoremap <silent> <C-j> :call WindowMotion('j')<cr>
nnoremap <silent> <C-k> :call WindowMotion('k')<cr>
nnoremap <silent> <C-l> :call WindowMotion('l')<cr>

au! VimLeave TPaneExit

