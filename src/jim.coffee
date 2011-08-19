define (require, exports, module) ->
  Keymap     = require './keymap'
  {GoToLine} = require './motions'

  class Jim
    constructor: (@adaptor) ->
      @command = null
      @registers = {}
      @keymap = Keymap.getDefault()
      @setMode 'normal'

    modes: require './modes'

    setMode: (modeName) ->
      console.log 'setMode', modeName if @debugMode
      prevModeName = @modeName
      return if modeName is prevModeName
      @modeName = modeName
      modeParts = modeName.split ":"
      @mode = @modes[modeParts[0]]
      switch prevModeName
        when 'insert'  then @adaptor.moveLeft()
        when 'replace' then @adaptor.setOverwriteMode off
      @onModeChange? prevModeName

    inVisualMode: -> /^visual:/.test @modeName

    onEscape: ->
      @setMode 'normal'
      @command = null
      @commandPart = '' # just in case...
      @adaptor.clearSelection()

    onKeypress: (keys) -> @mode.onKeypress.call this, keys

    deleteSelection: (exclusive, linewise) ->
      @registers['"'] = @adaptor.deleteSelection exclusive, linewise
    yankSelection: (exclusive, linewise) ->
      @registers['"'] = @adaptor.selectionText exclusive, linewise
      @adaptor.clearSelection true
