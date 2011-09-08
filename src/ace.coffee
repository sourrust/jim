# All of Jim's Ace-specific code is in here.  The idea is that an `Adaptor` for
# another editor could be written that implemented the same methods and presto!
# Jim works in that editor, too!  It's probably not that simple, but we'll find
# out...

{UndoManager} = require 'ace/undomanager'
Jim           = require './jim'

# Each instance of `Jim` has an instance of an `Adaptor` on which it invokes
# methods to move the cursor, change some text, etc.
class Adaptor
  # take an instance of Ace's editor
  constructor: (@editor) ->

  # Returns true if the cusor is on or beyond the last character of the line. If
  # `beyond` is true, return true only if the cursor is beyond the last char.
  atLineEnd = (editor, beyond) ->
    selectionLead = editor.selection.getSelectionLead()
    lineLength = editor.selection.doc.getLine(selectionLead.row).length
    selectionLead.column >= lineLength - (if beyond then 0 else 1)

  beyondLineEnd = (editor) -> atLineEnd(editor, true)

  # Whenever Jim's mode changes, update the editor's `className` and push a
  # "bookmark" onto the undo stack, if needed (explained below).
  onModeChange: (prevMode, newMode) ->
    for mode in ['insert', 'normal', 'visual']
      @editor[if mode is newMode.name then 'setStyle' else 'unsetStyle'] "jim-#{mode}-mode"

    @editor[if newMode.name is 'visual' and newMode.linewise then 'setStyle' else 'unsetStyle'] 'jim-visual-linewise-mode'

    if newMode.name is 'insert'
      @markUndoPoint 'jim:insert:start'
    else if prevMode?.name is 'insert'
      @markUndoPoint 'jim:insert:end'

    if newMode.name is 'replace'
      @markUndoPoint 'jim:replace:start'
    else if prevMode?.name is 'replace'
      @markUndoPoint 'jim:replace:end'

  # Vim's undo is particularly useful because it's idea of an atomic edit is
  # clear to the user.  One `Command` is undone each time `u` is pressed.  That
  # means all text entered between hitting `i` and hitting `<esc>` is undone as
  # one atomic edit.
  #
  # To match Vim's undo granularity, Jim pushes "bookmarks" onto the undo stack
  # to indicate when an insert starts or ends, for example.  This helps us avoid
  # having to record all keystrokes made while in insert or replace mode.
  markUndoPoint: (markName) ->
    @editor.session.getUndoManager().execute args: [markName, @editor.session]

  # turns overwrite mode on or off (used for Jim's replace mode)
  setOverwriteMode: (active) -> @editor.setOverwrite active

  # clears the selection, optionally positioning the at its beginning
  clearSelection: (beginning) ->
    if beginning and not @editor.selection.isBackwards()
      {row, column} = @editor.selection.getSelectionAnchor()
      @editor.navigateTo row, column
    else
      @editor.clearSelection()

  # undo the last `Command`
  undo: ->
    undoManager = @editor.session.getUndoManager()
    undoManager.jimUndo()
    @editor.clearSelection()

  # see `JimUndoManager::lastInsert`
  lastInsert: -> @editor.session.getUndoManager().lastInsert()

  ## getting the cursor's position in the document
  column:   -> @editor.selection.selectionLead.column
  row:      -> @editor.selection.selectionLead.row
  position: -> [@row(), @column()]

  ## viewport-related methods
  firstFullyVisibleRow: -> @editor.renderer.getFirstFullyVisibleRow()
  lastFullyVisibleRow:  ->
    # Ace sometimes sees more rows then there are lines, this will
    # keep that in check.
    totalLines = @editor.selection.doc.$lines.length
    lastVisibleRow = @editor.renderer.getLastFullyVisibleRow()
    if totalLines < lastVisibleRow
      totalLines
    else
      lastVisibleRow

  # Jim's block cursor is not considered by Ace to be part of the selection
  # unless the selection is backwards.  This makes the cursor part of the
  # selection.  Used just before the selection is acted upon, while an
  # `Operation` with a non-`exclusive` `Motion` is executing, for example.
  includeCursorInSelection: ->
    if not @editor.selection.isBackwards()
      @editor.selection.selectRight() unless beyondLineEnd(@editor)

  # inserts a new line at a zero-based row number
  insertNewLine: (row) ->
    @editor.session.doc.insertNewLine row: row, column: 0

  # move anchor by `columnOffset` columns (can be negative)
  adjustAnchor: (columnOffset) ->
    {row, column} = @editor.selection.getSelectionAnchor()
    @editor.selection.setSelectionAnchor row, column + columnOffset

  # if the anchor is ahead of the cursor, the selection is backwards
  isSelectionBackwards: -> @editor.selection.isBackwards()

  # the last zero-based row number
  lastRow: -> @editor.session.getDocument().getLength() - 1

  # the text that's on `lineNumber` or the current line
  lineText: (lineNumber) -> @editor.selection.doc.getLine lineNumber ? @row()

  # makes a linewise selection `lines` long if specified or makes the current
  # selection linewise (by pushing the lead and the anchor to the ends of their
  # lines)
  makeLinewise: (lines) ->
    {selectionAnchor: {row: anchorRow}, selectionLead: {row: leadRow}} = @editor.selection
    [firstRow, lastRow] = if lines?
      [leadRow, leadRow + (lines - 1)]
    else
      [Math.min(anchorRow, leadRow), Math.max(anchorRow, leadRow)]
    @editor.selection.setSelectionAnchor firstRow, 0
    @editor.selection.moveCursorTo lastRow + 1, 0

  ## basic motions (won't clear the selection)
  moveUp:   -> @editor.selection.moveCursorBy -1, 0
  moveDown: -> @editor.selection.moveCursorBy 1, 0
  moveLeft: ->
    if @editor.selection.selectionLead.getPosition().column > 0
      @editor.selection.moveCursorLeft()
  moveRight: (beyond) ->
    dontMove = if beyond then beyondLineEnd(@editor) else atLineEnd(@editor)
    @editor.selection.moveCursorRight() unless dontMove

  # move to a zero-based row and column
  moveTo: (row, column) -> @editor.moveCursorTo row, column

  # puts cursor on the last column of the line
  moveToLineEnd: ->
    {row, column} = @editor.selection.selectionLead
    position = @editor.session.getDocumentLastRowColumnPosition row, column
    @moveTo position.row, position.column - 1
  moveToEndOfPreviousLine: ->
    previousRow = @row() - 1
    previousRowLength = @editor.session.doc.getLine(previousRow).length
    @editor.selection.moveCursorTo previousRow, previousRowLength

  # move to first/last line
  navigateFileEnd:   -> @editor.navigateFileEnd()
  navigateLineStart: -> @editor.navigateLineStart()

  # moves the cursor to the fist char of the matching search or doesn't move at
  # all
  search: (backwards, needle, wholeWord) ->
    @editor.$search.set {backwards, needle, wholeWord}

    # move the cursor right so that it won't match what's already under the
    # cursor. move the cursor back afterwards if nothing's found
    @editor.selection.moveCursorRight() unless backwards

    if range = @editor.$search.find @editor.session
      @moveTo range.start.row, range.start.column
    else if not backwards
      @editor.selection.moveCursorLeft()

  # delete selected text and return it as a string
  deleteSelection: ->
    yank = @editor.getCopyText()
    @editor.session.remove @editor.getSelectionRange()
    @editor.clearSelection()
    yank

  indentSelection: ->
    @editor.indent()
    @clearSelection()

  outdentSelection: ->
    @editor.blockOutdent()
    @clearSelection()

  # insert `text` before or `after` the cursor
  insert: (text, after) ->
    @editor.selection.moveCursorRight() if after and not beyondLineEnd(@editor)
    @editor.insert text if text

  emptySelection: -> @editor.selection.isEmpty()

  selectionText: -> @editor.getCopyText()

  # set the selection anchor to the cusor's current position
  setSelectionAnchor: ->
    lead = @editor.selection.selectionLead
    @editor.selection.setSelectionAnchor lead.row, lead.column

  # Jim's linewise selections are really just regular selections with a CSS
  # width of 100%.  Before a visual command is exececuted the selection is
  # actually made linewise.  Because of this, it only matters what line the
  # anchor is on.  Therefore, we "hide" the anchor at the end of the line
  # where Jim's cursor won't go so that Ace doesn't remove the selection
  # elements from the DOM (which happens when the cursor and the anchor are
  # in the same place).  It's a wierd hack, but it works.
  #   https://github.com/misfo/jim/issues/5
  setLinewiseSelectionAnchor: ->
    {selection} = @editor
    {row, column} = selection[if selection.isEmpty() then 'selectionLead' else 'selectionAnchor']
    lastColumn = @editor.session.getDocumentLastRowColumnPosition row, column
    selection.setSelectionAnchor row, lastColumn
    [row, column]


  # Selects the line ending at the end of the current line and any whitespace at
  # the beginning of the next line if `andFollowingWhitespace` is specified.
  # This is used for the line joining commands `gJ` and `J`.
  selectLineEnding: (andFollowingWhitespace) ->
    @editor.selection.moveCursorLineEnd()
    @editor.selection.selectRight()
    if andFollowingWhitespace
      firstNonBlank = /\S/.exec(@lineText())?.index or 0
      @moveTo @row(), firstNonBlank

  # Returns the first and the last line that are part of the current selection
  selectionRowRange: ->
    [cursorRow, cursorColumn] = @position()
    {row: anchorRow} = @editor.selection.getSelectionAnchor()
    [Math.min(cursorRow, anchorRow), Math.max(cursorRow, anchorRow)]

  # Returns the number of chars selected if the selection is one row. If the
  # selection is multiple rows, it retuns the number of line endings selected
  # and the number of chars selected on the last row of the selection
  characterwiseSelectionSize: ->
    {selectionAnchor, selectionLead} = @editor.selection
    rowsDown = selectionLead.row - selectionAnchor.row
    if rowsDown is 0
      chars: Math.abs(selectionAnchor.column - selectionLead.column)
    else
      lineEndings: Math.abs(rowsDown)
      trailingChars: (if rowsDown > 0 then selectionLead else selectionAnchor).column + 1


# Ace's UndoManager is extended to handle undoing and repeating switches to
# insert and replace mode
class JimUndoManager extends UndoManager
  # override so that the default undo (button and keyboard shortcut)
  # will skip over Jim's bookmarks and behave as they usually do
  undo: ->
    @silentUndo() if @isJimMark @lastOnUndoStack()
    super

  # is this a bookmark we pushed onto the stack or an actual Ace undo entry
  isJimMark: (entry) ->
    typeof entry is 'string' and /^jim:/.test entry

  lastOnUndoStack: -> @$undoStack[@$undoStack.length-1]

  # pop the item off the stack without doing anything with it
  silentUndo: ->
    deltas = @$undoStack.pop()
    @$redoStack.push deltas if deltas

  matchingMark:
    'jim:insert:end':  'jim:insert:start'
    'jim:replace:end': 'jim:replace:start'

  # If the last command was an insert or a replace ensure that all undo items
  # associated with that command are undone.  If not, just do a regular ace
  # undo.
  jimUndo: ->
    lastDeltasOnStack = @lastOnUndoStack()
    if typeof lastDeltasOnStack is 'string' and startMark = @matchingMark[lastDeltasOnStack]
      startIndex = null
      for i in [(@$undoStack.length-1)..0]
        if @$undoStack[i] is startMark
          startIndex = i
          break

      if not startIndex?
        console.log "found a \"#{lastDeltasOnStack}\" on the undoStack, but no \"#{startMark}\""
        return

      @silentUndo() # pop the end off
      while @$undoStack.length > startIndex + 1
        if @isJimMark @lastOnUndoStack()
          @silentUndo()
        else
          @undo()
      @silentUndo() # pop the start off
    else
      @undo()

  # If the last command was an insert return all text that was inserted taking
  # backspaces into account.
  #
  # If the cursor moved partway through the insert (with arrow keys or with the
  # mouse), then only the last peice of contiguously inserted text is returned
  # and `contiguous` is returned as `false`.  This is to match Vim's behavior
  # when repeating non-contiguous inserts.
  lastInsert: ->
    return '' if @lastOnUndoStack() isnt 'jim:insert:end'

    cursorPosInsert = null
    cursorPosRemove = null
    action = null
    stringParts = []
    removedParts = []
    isContiguous = (delta) ->
      return false unless /(insert|remove)/.test delta.action
      if not action or action is delta.action
        if delta.action is 'insertText'
          not cursorPosInsert or delta.range.isEnd cursorPosInsert...
        else
          not cursorPosRemove or delta.range.isStart cursorPosRemove...
      else
        if delta.action is 'insertText' and cursorPosInsert?
          delta.range.end.row is cursorPosInsert[0]
        else if delta.action is 'removeText' and cursorPosRemove?
          delta.range.end.row is cursorPosRemove[0]
        else
          true

    for i in [(@$undoStack.length - 2)..0]
      break if typeof @$undoStack[i] is 'string'
      for j in [(@$undoStack[i].length - 1)..0]
        for k in [(@$undoStack[i][j].deltas.length - 1)..0]
          delta = @$undoStack[i][j].deltas[k]
          if isContiguous(delta)
            action = delta.action
            if action is 'removeText'
              cursorPosRemove = [delta.range.end.row, delta.range.end.column]
              for text in delta.text.split('')
                removedParts.push text

            if action is 'insertText'
              cursorPosInsert = [delta.range.start.row, delta.range.start.column]
              continue if removedParts.length and delta.text is removedParts.pop()
              for text in [(delta.text.length - 1)..0]
                stringParts.unshift delta.text[text]
          else
            return string: stringParts.join(''), contiguous: false
    string: stringParts.join(''), contiguous: true


# cursor and selection styles that Jim uses
require('pilot/dom').importCssString """
  .jim-normal-mode div.ace_cursor
  , .jim-visual-mode div.ace_cursor {
    border: 0;
    background-color: #91FF00;
    opacity: 0.5;
  }
  .jim-visual-linewise-mode .ace_marker-layer .ace_selection {
    left: 0 !important;
    width: 100% !important;
  }
"""


# Is the keyboard event a printable character key?
isCharacterKey = (hashId, keyCode) -> hashId is 0 and not keyCode

# Sets up Jim to handle the Ace `editor`'s keyboard events
Jim.aceInit = (editor) ->
  editor.setKeyboardHandler
    handleKeyboard: (data, hashId, keyString, keyCode) ->
      if keyCode is 27 # esc
        jim.onEscape()
      else if isCharacterKey hashId, keyCode
        # We've made some deletion as part of a change operation already and
        # we're about to start the actual insert.  Mark this moment in the undo
        # stack.
        if jim.afterInsertSwitch
          if jim.mode.name is 'insert'
            jim.adaptor.markUndoPoint 'jim:insert:afterSwitch'
          jim.afterInsertSwitch = false

        if jim.mode.name is 'normal' and not jim.adaptor.emptySelection()
          # if a selection has been made with the mouse since the last
          # keypress in normal mode, switch to visual mode
          jim.setMode 'visual'

        if keyString.length > 1
          #TODO handle this better, we're dropping keypresses here
          keyString = keyString.charAt 0

        passKeypressThrough = jim.onKeypress keyString

        if not passKeypressThrough
          # this will stop the event
          command: {exec: (->)}

  undoManager = new JimUndoManager()
  editor.session.setUndoManager undoManager

  adaptor = new Adaptor editor
  jim = new Jim adaptor

  # to initialize the editor class names
  adaptor.onModeChange null, name: 'normal'

  # returns `jim` if embedders wanna inspect its state or give it a high five
  jim
