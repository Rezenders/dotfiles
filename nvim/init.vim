set nu
set background=light

" Space Tabs {{{
set tabstop=2       " number of visual spaces per TAB
set softtabstop=2   " number of spaces in tab when editing
set shiftwidth=2   " number of spaces to use for autoindent
set expandtab       " tabs are space
set autoindent
set copyindent      " copy indent from the previous line
" }}} Spaces & Tabs
"

nnoremap <silent> <C-Right> <c-w>l
nnoremap <silent> <C-Left> <c-w>h
nnoremap <silent> <C-Up> <c-w>k
nnoremap <silent> <C-Down> <c-w>j

call plug#begin('~/.vim/plugged')

Plug 'scrooloose/nerdtree'
Plug 'tpope/vim-sensible'
Plug 'ripxorip/aerojump.nvim', { 'do': ':UpdateRemotePlugins' }
"Plug 'arakashic/chromatica.nvim'
Plug 'numirias/semshi', {'do': ':UpdateRemotePlugins'}
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'

if has('nvim')
  Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
else
  Plug 'Shougo/deoplete.nvim'
  Plug 'roxma/nvim-yarp'
  Plug 'roxma/vim-hug-neovim-rpc'
endif
let g:deoplete#enable_at_startup = 1

Plug 'kassio/neoterm'

call plug#end()

let g:airline#extensions#tabline#enabled = 1
" let g:airline_theme='ayu_dark:'

map <f2> :NERDTreeToggle<CR>

"let g:chromatica#libclang_path='/usr/lib/llvm-6.0/lib/libclang-6.0.so' 
"let g:chromatica#enable_at_startup=1
"let g:chromatica#responsive_mode=1

" Create mappings (with leader)
nmap <Leader>as <Plug>(AerojumpSpace)
nmap <Leader>ab <Plug>(AerojumpBolt)
nmap <Leader>aa <Plug>(AerojumpFromCursorBolt)
nmap <Leader>ad <Plug>(AerojumpDefault) " Boring mode
