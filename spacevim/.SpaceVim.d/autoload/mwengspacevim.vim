function! mwengspacevim#before() abort
  " you can define mappings in bootstrap function
  " for example, use kj to exit insert mode
  inoremap kj <Esc>
  " disable mouse
  "set mouse=
  " make sure cursor indicates insert and normal mode
  " Reference chart of values:
  "   Ps = 0  -> blinking block.
  "   Ps = 1  -> blinking block (default).
  "   Ps = 2  -> steady block.
  "   Ps = 3  -> blinking underline.
  "   Ps = 4  -> steady underline.
  "   Ps = 5  -> blinking bar (xterm).
  "   Ps = 6  -> steady bar (xterm).
  let &t_SI = "\e[6 q"
  let &t_EI = "\e[2 q"
endfunction

function! mwengspacevim#after() abort
  " you can remove key binding in bootstrap_after function
  " iunmap kj
endfunction

