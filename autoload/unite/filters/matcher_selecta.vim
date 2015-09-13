let s:save_cpo = &cpo
set cpo&vim

function! unite#filters#matcher_selecta#define() "{{{
  return s:matcher
endfunction"}}}

let s:matcher = {
      \ 'name' : 'matcher_selecta',
      \ 'description' : 'selecta matcher',
      \}

function! s:matcher.pattern(input) "{{{
  let chars = map(split(a:input, '\zs'), "escape(v:val, '\\[]^$.*')")
  if empty(chars)
    return ''
  endif

  let pattern =
        \   substitute(join(map(chars[:-2], "
        \       printf('%s[^%s]\\{-}', v:val, v:val)
        \   "), '') . chars[-1], '\*\*', '*', 'g')
  return pattern
endfunction"}}}

function! s:matcher.filter(candidates, context) "{{{
  return a:candidates
endfunction"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
