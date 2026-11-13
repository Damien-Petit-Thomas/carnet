" carnet — chargé automatiquement quand carnet ouvre vim (vim -S).
" Pour l'avoir dans tout vim : source <chemin>/share/vim/carnet.vim dans ~/.vimrc
"   <leader>nl  insérer un lien vers une note        :CarnetLink
"   <leader>nb  backlinks de la note courante         :CarnetBacklinks
"   <leader>ni  coller l'image du presse-papier      :CarnetImage
"   <leader>nf  ajouter/retirer des favoris          :CarnetFav
if exists('g:loaded_carnet') | finish | endif
let g:loaded_carnet = 1

let s:carnet = !empty($CARNET_BIN) ? $CARNET_BIN : expand('<sfile>:p:h:h:h') . '/bin/carnet'

" Lance carnet avec un terminal (fzf) et renvoie sa sortie standard.
function! s:Run(args) abort
  let tmp = tempname()
  execute 'silent !' . shellescape(s:carnet, 1) . ' ' . a:args
        \ . ' > ' . shellescape(tmp, 1)
  redraw!
  let out = filereadable(tmp) ? join(readfile(tmp), "\n") : ''
  call delete(tmp)
  return out
endfunction

function! s:Current() abort
  return shellescape(expand('%:p'), 1)
endfunction

" Insère TEXT après le curseur.
function! s:Insert(text) abort
  if a:text ==# '' | return | endif
  let l = getline('.')
  let c = col('.')
  call setline('.', strpart(l, 0, c) . a:text . strpart(l, c))
  call cursor(line('.'), c + len(a:text))
endfunction

function! s:Backlinks() abort
  let res = s:Run('_backlinks ' . s:Current())
  if res ==# '' | return | endif
  let parts = matchlist(res, '^\(.*\):\(\d\+\)$')
  if empty(parts) | return | endif
  execute 'edit +' . parts[2] . ' ' . fnameescape(parts[1])
endfunction

command! CarnetLink      call s:Insert(s:Run('_link ' . s:Current()))
command! CarnetImage     call s:Insert(s:Run('_image ' . s:Current()))
command! CarnetBacklinks call s:Backlinks()
command! CarnetFav       echo substitute(system(shellescape(s:carnet) . ' _fav ' . shellescape(expand('%:p'))), '\n\+$', '', '')

nnoremap <silent> <leader>nl :CarnetLink<CR>
nnoremap <silent> <leader>nb :CarnetBacklinks<CR>
nnoremap <silent> <leader>ni :CarnetImage<CR>
nnoremap <silent> <leader>nf :CarnetFav<CR>
