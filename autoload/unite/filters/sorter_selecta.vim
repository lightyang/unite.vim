"=============================================================================
" FILE: sorter_selecta.vim
" AUTHOR:  David Lee
" CONTRIBUTOR:  Jean Cavallo
" DESCRIPTION: Scoring code by Gary Bernhardt
"     https://github.com/garybernhardt/selecta
" License: MIT license
"     Permission is hereby granted, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditions:
"
"     The above copyright notice and this permission notice shall be included
"     in all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" 
"=============================================================================

let s:save_cpo = &cpo
set cpo&vim

function! unite#filters#sorter_selecta#define() abort
  if has('python') || has('python3')
    return s:sorter
  else
    return {}
  endif
endfunction

let s:root = expand('<sfile>:p:h')
let s:sorter = {
      \ 'name' : 'sorter_selecta',
      \ 'description' : 'sort by selecta algorithm',
      \}

if exists(':Python2or3') != 2
  if has('python3') && get(g:, 'pymode_python', '') !=# 'python'
    command! -nargs=1 Python2or3 python3 <args>
  else
    command! -nargs=1 Python2or3 python <args>
  endif
endif

function! s:sorter.filter(candidates, context) abort
  if a:context.input == '' || !has('float') || empty(a:candidates)
    return a:candidates
  endif

  return unite#filters#sorter_selecta#_sort(
        \ a:candidates, a:context.input)
endfunction

function! unite#filters#sorter_selecta#_sort(candidates, input) abort
  let candidates = []
  python << PYTHONEOF
import vim
import re
candidates = vim.bindeval('a:candidates')
words = [c.get('word') for c in candidates]
ainput = vim.bindeval('a:input')

def unescape_input(i):
  return re.sub(r'\\*', '', re.sub(r'\\ ', ' ', i)).strip().lower()
inputs = map(unescape_input, re.split(r'(?!\\) ', ainput))
inputs = [(i, i[1:]) for i in inputs if i]

ranks = []
for i, word in enumerate(words):
  rank = 0
  failed = False
  for (pattern, tail) in inputs:
    score = get_score(word, pattern, tail)
    if score is None:
      failed = True
      break
    rank += score
  if failed:
    continue
  ranks.append((rank, i))
order = map(lambda a: a[1], sorted(ranks))
for o in order:
  vim.command('call add(candidates, a:candidates[%d])' % o)
PYTHONEOF

  return candidates
endfunction

" @vimlint(EVL102, 1, l:root)
function! s:def_python() abort
python << PYTHONEOF
import string

BOUNDARY_CHARS = set(string.punctuation + string.whitespace)
NORMAL = 0
SEQUENTIAL = 1
BOUNDARY = 2

def get_score(str, query_chars, tail):
  # Highest possible score is the string length
  best_score = len(str)
  best_range = None
  rlimit = str.rfind(query_chars[-1])
  if rlimit == -1:
    return None
  rlimit += 1

  # For each occurence of the first character of the query in the string
  first_index = -1
  while True:
    first_index = str.find(query_chars[0], first_index + 1)
    if first_index == -1:
      break
    # Get the score for the rest
    score, last_index = find_end_of_match(str, tail, first_index, best_score)

    # won't be able to find more matches
    if score is None:
      break

    if score < best_score:
      best_score = score
      best_range = (first_index, last_index)

  if best_range is None:
    return None
  return best_score

def find_end_of_match(to_match, chars, first_index, best_score):
  if first_index == 0 or to_match[first_index - 1] in BOUNDARY_CHARS:
    score = 0
  else:
    score = 1
  last_index = first_index
  last_type = NORMAL

  for char in chars:
    index = to_match.find(char, last_index + 1)
    if index == -1:
      return (None, None)

    # Do not count sequential characters more than once
    if index == last_index + 1:
      if last_type != SEQUENTIAL:
        last_type = SEQUENTIAL
        score += 1
    # Same for first characters of words
    elif to_match[index - 1] in BOUNDARY_CHARS:
      if last_type != BOUNDARY:
        last_type = BOUNDARY
        score += 1
    else:
      last_type = NORMAL
      score += index - last_index
    if score >= best_score:
      return (None, None)
    last_index = index

  return (score, last_index)
PYTHONEOF
endfunction
" @vimlint(EVL102, 0, l:root)

call s:def_python()

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
