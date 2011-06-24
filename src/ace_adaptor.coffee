jim = new Jim()

aceAdaptor =
  onEscape: (env, args) -> env.editor.clearSelection()

  gotoLine: (env, args) -> env.editor.gotoLine args.lineNumber

  navigateUp:    (env, args) -> env.editor.navigateUp args.times
  navigateDown:  (env, args) -> env.editor.navigateDown args.times
  navigateLeft:  (env, args) -> env.editor.navigateLeft args.times
  navigateRight: (env, args) -> env.editor.navigateRight args.times

  navigateFileEnd:   (env, args) -> env.editor.navigateFileEnd()
  navigateLineEnd:   (env, args) -> env.editor.navigateLineEnd()
  navigateLineStart: (env, args) -> env.editor.navigateLineStart()

  deleteLeft: (env, args) ->
    aceAdaptor.selectLeft env, args
    aceAdaptor.deleteSelection env, args
  deleteRight: (env, args) ->
    aceAdaptor.selectRight env, args
    aceAdaptor.deleteSelection env, args
  deleteToLineEnd: (env, args) ->
    env.editor.selection.selectLineEnd()
    aceAdaptor.deleteSelection env, args
  deleteSelection: (env, args) ->
    jim.registers[args.register] = env.editor.getCopyText()
    env.editor.session.remove env.editor.getSelectionRange()

  selectUp: (env, args) ->
    env.editor.selection.selectUp() for i in [1..(args.times or 1)]
  selectDown: (env, args) ->
    env.editor.selection.selectDown() for i in [1..(args.times or 1)]
  selectLeft: (env, args) ->
    env.editor.selection.selectLeft() for i in [1..(args.times or 1)]
  selectRight: (env, args) ->
    env.editor.selection.selectRight() for i in [1..(args.times or 1)]
  selectLine: (env, args) ->
    env.editor.selection.selectLine()

  yankSelection: (env, args) ->
    jim.registers[args.register] = env.editor.getCopyText()
    if env.editor.selection.isBackwards()
      env.editor.clearSelection()
    else
      {start} = env.editor.getSelectionRange()
      env.editor.navigateTo start.row, start.column


  isntCharacterKey: (hashId, key) ->
    (hashId isnt 0 and (key is "" or key is String.fromCharCode 0)) or key.length > 1

  handleKeyboard: (data, hashId, key) ->
    noop = ->
    if key is "esc"
      jim.onEscape()
      result = action: 'onEscape'
    else if @isntCharacterKey(hashId, key)
      # do nothing if it's just a modifier key
      return

    key = key.toUpperCase() if hashId & 4 and key.match /^[a-z]$/
    result ?= jim.onKeypress key
    if result?
      jim.setMode result.changeToMode if result.changeToMode?
      command:
        exec: this[result.action] or noop
      args: result.args

define (require, exports, module) ->
  require('pilot/dom').importCssString """
    .jim-normal-mode div.ace_cursor {
      border: 0;
      background-color: #91FF00;
      opacity: 0.5;
    }
  """

  console.log 'defining startup'
  startup = (data, reason) ->
    {editor} = data.env
    if not editor
      setTimeout startup, 0, data, reason
      return
    console.log 'executing startup'
    editor.setKeyboardHandler aceAdaptor

    jim.onModeChange = (prevMode) ->
      if @modeName is 'normal'
        editor.setStyle 'jim-normal-mode'
      else
        editor.unsetStyle 'jim-normal-mode'

    jim.onModeChange()
  exports.startup = startup

  exports.Jim = Jim
  return
