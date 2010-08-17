" let users override curl command. Reuse netrw setting
let s:curl = exists('g:netrw_http_cmd') ? g:netrw_http_cmd : 'curl -o'

" cmds = list of {'d':  dir to run command in, 'c': the command line to be run }
fun! s:exec_in_dir(cmds)
  call vcs_checkouts#ExecIndir(a:cmds)
endf

" insert arguments at placeholders $ shell escaping the value
" usage: s:shellescape("rm -fr $ $ $", [file1, file2, file3])
fun! s:shellescape(cmd, ...)
  let list = copy(a:000)
  let r = ''
  let l = split(a:cmd, '\$', 1)
  let r = l[0]
  for x in l[1:]
    let r .= shellescape(remove(list, 0),1).x
  endfor
  return r
endf

fun! s:EndsWith(name, ...)
  return  a:name =~? '\%('.substitute(join(a:000,'\|'),'\.','\\.','g').'\)$'
endf



" may throw EXCEPTION_UNPACK.*
" most packages are shipped in a directory. Eg ADDON/plugin/*
" strip_components=1 strips of this ADDON directory (implemented for tar.* " archives only)

" !! If you change this run the test, please: call vim_addon_manager_tests#Tests('.')
fun! scriptmanager_util#Unpack(archive, targetdir, strip_components)

  let esc_archive = s:shellescape('$', a:archive)
  let tgt = [{'d': a:targetdir}]

  let gzbzip2 = {
        \ '.gz':   [-4, '','gzip -d'],
        \ '.tgz':   [-3,'ar','gzip -d'],
        \ '.bz2':   [-5, '', 'bzip2 -d'],
        \ '.tbz2':  [-4,'ar','bzip2 -d'],
        \ }

  " .vim file and type syntax?
  if a:archive =~? '\.vim$'
    call writefile(readfile(a:archive,'b'), a:targetdir.'/'.fnamemodify(a:archive, ':t'),'b')

  " .gz .bzip2 (or .vba.* or .tar.*)
  elseif s:EndsWith(a:archive, keys(gzbzip2) )
    " I was told tar on Windows is buggy and can't handle xj or xz correctly
    " so unpack in two phases:

    for [k,z] in items(gzbzip2)
      if s:EndsWith(a:archive, k)
        let unpacked = a:archive[:z[0]]
        let renameTo = unpacked.z[1]
        call s:exec_in_dir([{'c': z[2].' '.esc_archive }])
        if !filereadable(renameTo)
          " windows tar does not rename .tgz to .tar ?
          call rename(unpacked, renameTo)
        endif
        " now unpack .tar or .vba file and tidy up temp file:
        call scriptmanager_util#Unpack(renameTo, a:targetdir, a:strip_components)
        call delete(renameTo)
      endif
      unlet k z
    endfor

    " execute in target dir:

    " .tar
  elseif s:EndsWith(a:archive, '.tar')
    call s:exec_in_dir(tgt + [{'c': 'tar '.'--strip-components='.a:strip_components.' -xf '.esc_archive }])

    " .zip
  elseif s:EndsWith(a:archive, '.zip')
    call s:exec_in_dir(tgt + [{'c': 'unzip '.esc_archive }])

    " .7z, .cab, .rar, .arj, .jar
    " (I have actually seen only .7z and .rar, but 7z supports other formats 
    " too)
  elseif s:EndsWith(a:archive,  '.7z','.cab','.arj','.rar','.jar')
    call s:exec_in_dir(tgt + [{'c': '7z x '.esc_archive }])


  elseif s:EndsWith(a:archive, '.vba')
    " .vba reuse vimball#Vimball() function
    exec 'sp '.fnameescape(a:archive)
    call vimball#Vimball(1,a:targetdir)
  else
    throw "EXCEPTION_UNPACK: don't know how to unpack ". a:archive
  endif

endf

fun! scriptmanager_util#Download(url, targetFile)
  call s:exec_in_dir([{'c': s:shellescape(s:curl.' $ $', a:targetFile, a:url)}])
endf

fun! scriptmanager_util#RmFR(dir_or_file)
  " TODO windows implementation
  exec '!'.s:shellescape('rm -fr $',a:dir_or_file)
endf


" a "direct link" (found on the downrload page)
" such as "http://downloads.sourceforge.net/project/gnuwin32/gzip/1.3.12-1/gzip-1.3.12-1-bin.zip"
" can be downloaded this way:
" call scriptmanager_util#DownloadFromMirrors("mirror://sourceforge/gnuwin32/gzip/1.3.12-1/gzip-1.3.12-1-bin.zip","/tmp")
fun! scriptmanager_util#DownloadFromMirrors(url, targetDir)
  let mirrors_sourceforge = [
        \   'http://heanet.dl.sourceforge.net/sourceforge/',
        \   'http://surfnet.dl.sourceforge.net/sourceforge/',
        \ ]

  let m = matchlist(a:url, '^mirror:\/\/\([^/\\]\+\)\/\(.*\)')

  if len(m) > 3
    let url =  mirrors_{m[1]}[0].m[2]
  endif
  " if target is a directory append basename of url
  let t = a:targetDir
  if isdirectory(t)
    let t = t .'/'.fnamemodify(url,':t')
  endif
  call scriptmanager_util#Download(url, t)
endf
