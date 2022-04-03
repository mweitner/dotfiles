function! mwengspacevim#before() abort
  " you can define mappings in bootstrap function
  " for example, use kj to exit insert mode
  inoremap kj <Esc>
  " disable mouse
  "set mouse=
endfunction

function! mwengspacevim#after() abort
  " you can remove key binding in bootstrap_after function
  " iunmap kj
endfunction

