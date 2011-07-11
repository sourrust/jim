define (require, exports, module) ->
  class Jim
    @modes:
      insert: require 'jim/modes/insert'
      normal: require 'jim/modes/normal'
      visual: require 'jim/modes/visual'

    constructor: (@adaptor) ->
      @clearBuffer()
      @registers = {}
      @setMode 'normal'

    clearBuffer: -> @buffer = @operator = ''

    setMode: (modeName) ->
      console.log 'setMode', modeName
      prevModeName = @modeName
      @clearBuffer()
      return if modeName is prevModeName
      @modeName = modeName
      modeParts = modeName.split ":"
      @mode = Jim.modes[modeParts[0]]
      @adaptor.moveLeft() if prevModeName is 'insert'
      @onModeChange? prevModeName

    onEscape: ->
      @setMode 'normal'
      @adaptor.clearSelection()

    onKeypress: (key) ->
      @buffer += key
      console.log '@buffer', @buffer
      @mode.execute.call this

    deleteSelection: (exclusive, linewise) ->
      @registers['"'] = @adaptor.deleteSelection exclusive, linewise
    yankSelection: (exclusive, linewise) ->
      @registers['"'] = @adaptor.selectionText exclusive, linewise
      @adaptor.clearSelection true
