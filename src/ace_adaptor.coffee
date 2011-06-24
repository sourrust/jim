jim = new Jim()

aceAdaptor =
  onEscape: (env, args, request) -> env.editor.clearSelection()

  gotoLine: (env, args, request) -> env.editor.gotoLine args.lineNumber

  navigateUp:    (env, args, request) -> env.editor.navigateUp args.times
  navigateDown:  (env, args, request) -> env.editor.navigateDown args.times
  navigateLeft:  (env, args, request) -> env.editor.navigateLeft args.times
  navigateRight: (env, args, request) -> env.editor.navigateRight args.times

  navigateFileEnd:   (env, args, request) -> env.editor.navigateFileEnd()
  navigateLineEnd:   (env, args, request) -> env.editor.navigateLineEnd()
  navigateLineStart: (env, args, request) -> env.editor.navigateLineStart()

  deleteLeft: (env, args, request) ->
    aceAdaptor.selectLeft(env, args, request)
    aceAdaptor.deleteSelection(env, args, request)
  deleteRight: (env, args, request) ->
    aceAdaptor.selectRight(env, args, request)
    aceAdaptor.deleteSelection(env, args, request)
  deleteToLineEnd: (env, args, request) ->
    env.editor.selection.selectLineEnd()
    aceAdaptor.deleteSelection(env, args, request)
  deleteSelection: (env, args, request) ->
    jim.registers[args.register] = env.editor.getCopyText()
    env.editor.session.remove env.editor.getSelectionRange()

  selectUp:    (env, args, request) ->
    env.editor.selection.selectUp() for i in [1..(args.times or 1)]
  selectDown:  (env, args, request) ->
    env.editor.selection.selectDown() for i in [1..(args.times or 1)]
  selectLeft:  (env, args, request) ->
    env.editor.selection.selectLeft() for i in [1..(args.times or 1)]
  selectRight: (env, args, request) ->
    env.editor.selection.selectRight() for i in [1..(args.times or 1)]
  selectLine: (env, args, request) ->
    env.editor.selection.selectLine()

  yankSelection: (env, args, request) ->
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
