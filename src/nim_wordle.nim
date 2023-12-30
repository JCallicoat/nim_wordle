import std/algorithm
import std/exitprocs
import std/random
import std/sequtils
import std/strformat
import std/strutils
import std/tables
from std/terminal import ansiResetCode, ansiStyleCode, BackgroundColor, cursorBackward,
    eraseLine, eraseScreen, ForegroundColor, getch, resetAttributes, setCursorPos,
        styledWrite, styledWriteLine, terminalSize

import nim_wordle/word_list as wl
import nim_wordle/valid_word_list as vwl

# clean up after ourselves
proc cleanup() =
  eraseScreen()
  setCursorPos(0, 0)
  resetAttributes()

exitprocs.addExitProc(cleanup)
setControlCHook(proc {.noconv.} = quit())


# types
type LetterState = enum
  Default,
  Unused,
  Possible,
  Correct

type Letter = object
  chr: char
  state: LetterState

type GameState = object
  w: int
  h: int
  cursorPos: tuple[w: int, h: int]
  letters: OrderedTable[char, Letter]
  guesses: seq[seq[Letter]]
  wordle: string
  chrMaxTotal: Table[char, int]


# writing stuff
proc write(self: var GameState, c: ForegroundColor, s: string) =
  let w = int(self.w / 2) - int(s.len / 2)
  setCursorPos(w, self.cursorPos.h)
  stdout.styledWrite(c, s)

proc writeLine(self: var GameState, c: ForegroundColor, s: string) =
  self.write(c, s & "\n")
  self.cursorPos.h += 1

proc writeLetter(self: GameState, letter: Letter) =
  case letter.state:
  of Default:
    stdout.write(&"{ansiStyleCode(ord(fgDefault)+60)}{letter.chr}{ansiResetCode}")
  of Unused:
    stdout.write(&"{ansiStyleCode(ord(fgBlack)+60)}{letter.chr}{ansiResetCode}")
  of Possible:
    stdout.write(&"{ansiStyleCode(ord(fgYellow)+60)}{letter.chr}{ansiResetCode}")
  of Correct:
    stdout.write(&"{ansiStyleCode(ord(fgGreen)+60)}{letter.chr}{ansiResetCode}")
  stdout.write(" ")

proc writeLetters(self: var GameState) =
  var values = self.letters.values.toSeq()
  # top row
  var w = int(self.w / 2) - 10
  setCursorPos(w, self.cursorPos.h)
  for letter in values[0..<10]:
    self.writeLetter(letter)
  self.cursorPos.h += 1
  # middle row
  w = int(self.w / 2) - 9 
  setCursorPos(w, self.cursorPos.h)
  for letter in values[10..<19]:
    self.writeLetter(letter)
  self.cursorPos.h += 1
  # bottom row
  w = int(self.w / 2) - 7
  setCursorPos(w, self.cursorPos.h)
  for letter in values[19..<26]:
    self.writeLetter(letter)
  self.cursorPos.h += 1

proc writeGuesses(self: var GameState) =
  let w = int(self.w / 2) - 6
  for i, guess in self.guesses.pairs:
    setCursorPos(w, self.cursorPos.h)
    stdout.write(&"{i + 1}. ")
    for letter in guess:
      self.writeLetter(letter)
    self.cursorPos.h += 1

proc writePrompt(self: var GameState) =
  eraseScreen()
  self.cursorPos.h = int(self.h / 2)
  self.writeLine(fgRed, "Nim Wordle!")
  self.writeLine(fgDefault, "")
  self.writeLetters()
  self.writeLine(fgDefault, "")
  if self.guesses.len > 0:
    self.writeGuesses()
    self.writeLine(fgDefault, "")

proc writeWon(self: var GameState) =
  self.writePrompt()
  self.writeLine(fgGreen, "A winrar is you!")
  self.writeLine(fgDefault, &"Won in {self.guesses.len} guesses")

proc writeLost(self: var GameState) =
  self.writePrompt()
  self.writeLine(fgGreen, "Better luck next time, kid!")
  self.writeLine(fgDefault, &"Word was {self.wordle}")


# guess stuff
proc guessValid(self: var GameState, guess: string): bool =
  return binarySearch(wl.wordList, guess.toLower()) > -1 or
    binarySearch(vwl.validWordList, guess.toLower()) > -1

proc getGuess(self: var GameState): string =
  self.write(fgDefault, "Enter a guess: ")
  var guess = ""
  var res = stdin.readLine(guess)
  while not res or guess.len != 5 or not self.guessValid(guess):
    self.write(fgDefault, "Enter a guess: ")
    if guess.len > 0:
      stdout.write(" ".repeat(guess.len))
      cursorBackward(guess.len)
    res = stdin.readLine(guess)
  return guess.toUpper()

proc checkLetter(self: var GameState, chr: char, i: int): Letter =
  var state = Unused
  if self.wordle[i] == chr:
    state = Correct
  elif chr in self.wordle:
    state = Possible
  return Letter(chr: chr, state: state)

proc checkGuess(self: var GameState): bool =
  let guess = self.getGuess()
  var guessLetters: seq[Letter] = @[]

  var correctTotal = 0
  var chrCorrectTotal = initTable[char, int]()
  var chrPossibleTotal = initTable[char, int]()

  for i, chr in guess.pairs:
    var letter = self.checkLetter(chr, i)
    guessLetters.add(letter)
    if letter.state == Correct:
      correctTotal += 1
      chrCorrectTotal[chr] = chrCorrectTotal.getOrDefault(chr) + 1
    elif letter.state == Possible:
      chrPossibleTotal[chr] = chrPossibleTotal.getOrDefault(chr) + 1

  # this feels hacky 
  for i in countdown(4, 0):
    let letter = guessLetters[i]
    if letter.state == Possible:
      let correctCount = chrCorrectTotal.getOrDefault(letter.chr)
      let possibleCount = chrPossibleTotal[letter.chr]
      if possibleCount > self.chrMaxTotal.getOrDefault(letter.chr) or
         (correctCount > 0 and possibleCount >= correctCount):
        chrPossibleTotal[letter.chr] -= 1
        guessLetters[i].state = Unused

    if self.letters[letter.chr].state != Correct:
      self.letters[letter.chr].state = letter.state

  self.guesses.add(guessLetters)
  return correctTotal == 5

proc run(self: var GameState): bool =
  var won = false
  var again: char
  while not won and self.guesses.len < 6:
    self.writePrompt()
    won = self.checkGuess()
  if won:
    self.writeWon()
  else:
    self.writeLost()
  self.write(fgDefault, "Play again? [Y/n] ")
  again = getch()
  return again.toLowerAscii() in ['\r', 'y']


proc newGame: GameState =
  let size = terminalSize()
  let w = int(size.w / 2)
  let h = int(size.h / 2)

  var letters = initOrderedTable[char, Letter]()
  for letter in ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P',
                 'A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L',
                 'Z', 'X', 'C', 'V', 'B', 'N', 'M']:
    letters[letter] = Letter(chr: letter, state: Default)

  randomize() # seed the rng
  # let wordle = wl.wordList[2003].toUpper()
  let wordle = sample(wl.wordList).toUpper()
  var chrMaxTotal = initTable[char, int]()
  for chr in wordle:
    discard chrMaxTotal.hasKeyOrPut(chr, wordle.count(chr))
  
  return GameState(w: size.w, h: size.h, cursorPos: (w, h),
                   letters: letters, guesses: @[], wordle: wordle,
                   chrMaxTotal: chrMaxTotal)


if isMainModule:
  var playAgain = true
  while playAgain:
    var game = newGame()
    playAgain = game.run()
