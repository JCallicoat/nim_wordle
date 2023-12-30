import std/enumerate
import std/sequtils
import std/strformat
import std/strutils

import nim_wordle/word_list as wl
import nim_wordle/valid_word_list as vwl


proc findCandidates(correct, possible, excluded: seq[char]) =
  # echo &"correct: {correct}, possible: {possible}, excluded: {excluded}"
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
      for chr in possible:
        if not (chr in word):
          break inner
      candidates.add(word)
  echo "Possible candidates:"
  for word in candidates:
    stdout.write(&"{word.toUpper} ")
  echo ""


if isMainModule:
  var correct, possible, excluded: string = ""
  stdout.write("Enter correct letters: ")
  if not stdin.readLine(correct):
    stderr.writeLine("Correct list is needed")
    quit(1)

  stdout.write("Enter possible letters: ")
  if not stdin.readLine(possible):
    stderr.writeLine("Possible list is needed")
    quit(1)

  stdout.write("Enter excluded letters: ")
  if not stdin.readLine(excluded):
    stderr.writeLine("Excluded list is needed")
    quit(1)

  findCandidates(correct.toLower.toSeq, possible.toLower.toSeq, excluded.toLower.toSeq)

