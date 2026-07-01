import std/algorithm
import std/enumerate
import std/sequtils
import std/strformat
import std/strutils
import nim_wordle/word_list as wl
import nim_wordle/valid_word_list as vwl

type PossibleLetter = tuple[chr: char, pos: int]

proc parsePossible(s: string): seq[PossibleLetter] =
  var i = 0
  while i + 1 < s.len:
    result.add((chr: s[i], pos: parseInt($s[i+1]) - 1))
    i += 2

proc findCandidates(correct: seq[char], possible: seq[PossibleLetter], excluded: seq[char]) =
  var candidates: seq[string] = @[]
  for word in wl.wordList.concat(vwl.validWordList):
    block inner:
      for chr in excluded:
        if chr in word:
          break inner
      for i, chr in enumerate(correct):
        if chr == '_':
          continue
        if word[i] != chr:
          break inner
      for p in possible:
        if p.chr notin word:
          break inner
        if word[p.pos] == p.chr:
          break inner
      candidates.add(word)
  candidates.sort()
  echo "Possible candidates:"
  for word in candidates:
    stdout.write(&"{word.toUpper} ")
  echo ""

if isMainModule:
  var correct, possible, excluded: string = ""
  stdout.write("Enter correct letters (e.g. _e___): ")
  if not stdin.readLine(correct):
    stderr.writeLine("Correct list is needed")
    quit(1)
  if correct.len != 5:
    stderr.writeLine("Correct must be exactly 5 characters")
    quit(1)
  stdout.write("Enter possible letters with positions (e.g. e2a4): ")
  if not stdin.readLine(possible):
    stderr.writeLine("Possible list is needed")
    quit(1)
  stdout.write("Enter excluded letters: ")
  if not stdin.readLine(excluded):
    stderr.writeLine("Excluded list is needed")
    quit(1)
  findCandidates(correct.toLower.toSeq, parsePossible(possible.toLower), excluded.toLower.toSeq)
