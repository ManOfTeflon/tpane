let g:tpane_dir = expand('<sfile>:p:h:h')

function! s:start_debugging(dbg_args, cmd)
    if GdbIsAttached()
        let exe = split(a:cmd)[0]
        let args = a:cmd[len(exe):]
        exec "GdbExec python (gdb.execute('file " . exe . "'), gdb.execute('set args " . args . "'), gdb.execute('run'))"
    endif
    if ! GdbIsAttached()
        exec "cd " . g:WORK_DIRECTORY
        call TPaneExec('', 'exit')
        exec 'GdbStartDebugger --lock=$HOME/.tmux/lock ' . a:dbg_args . ' -args ' . a:cmd
        wincmd =
    endif
endfunction

function! s:Test(cmd)
    if a:cmd == ""
        let curfile = expand("%")
        let curfile_is_test = (curfile =~ "\.sql$" || curfile =~ "\.py$")

        if exists("g:LAST_TEST") && g:LAST_TEST != "" && ! curfile_is_test
            let cmd = g:LAST_TEST
        else
            let cmd = curfile
        endif
    else
        let cmd = a:cmd
    endif

    let g:LAST_TEST = cmd

    call TPaneExec(g:TEST_RUNNER . " " . cmd, 'test')
endfunction

function! TPaneExec(cmd, log)
    return system(g:tpane_dir . "/bin/run_pane.sh '" . a:log . "' " . a:cmd)
endfunction

function! s:DefaultSettings(settings)
    for [name, value] in items(a:settings)
        if !exists('g:' . name)
            let g:{name}=value
        endif
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

function! s:Workflow()
    NERDTreeClose
    let outfile = TPaneExec(g:BUILD_COMMAND, "build")
    call system("bash " . g:tpane_dir . "/bin/workflow.sh " . outfile . " &")
endfunction

comm! -nargs=0 BuildSuccess exec g:ON_BUILD_SUCCESS
comm! -nargs=0 BuildFailure exec g:ON_BUILD_FAILURE

let s:TestPlugin = {}

function! s:TestPlugin.Activate(path)
    exec "Test " . (a:path.str({'format': 'Edit'}))
    call nerdtree#closeTreeIfOpen()
endfunction

command! -nargs=0 -bar           TPaneExit      call TPaneExec("", "exit")
command! -nargs=1 -complete=shellcmd TPaneExec  call TPaneExec(<q-args>, 'interactive')
command! -nargs=0 -bar           Build          call TPaneExec(g:BUILD_COMMAND, 'build')
command! -nargs=0 -bar           Workflow       call s:Workflow()
command! -nargs=?                Prepare        call s:start_debugging('-iex wait-or-exit', len(<q-args>) ? <q-args> : g:EXECUTABLE)
command! -nargs=? -bar           Launch         call s:start_debugging('-iex wait-or-exit -ex run', len(<q-args>) ? <q-args> : g:EXECUTABLE)
command! -nargs=* -complete=file Test           call s:Test(<q-args>)
command! -nargs=*                LaunchAndTest  Launch | Test <f-args>
command! -nargs=0 -bar           TestTree       call g:NERDTreeCreator.CreatePrimary(g:TEST_DIRECTORY, s:TestPlugin)

if exists("g:TPANE_SETTINGS")
    let s:settings = g:TPANE_SETTINGS
else
    let s:settings = {
        \ 'BUILD_COMMAND': 'make all',
        \ 'EXECUTABLE': '',
        \ 'TEST_DIRECTORY': '.',
        \ 'TEST_RUNNER': '',
        \ 'WORK_DIRECTORY': '.',
        \ 'LAST_TEST': '',
        \ 'ON_BUILD_SUCCESS': 'LaunchAndTest',
        \ 'ON_BUILD_FAILURE': '',
     \ }
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

