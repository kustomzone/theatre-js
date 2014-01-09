Foxie = require 'foxie'
_Emitter = require '../../_Emitter'

module.exports = class WorkspaceListView extends _Emitter

	constructor: (@mainBox) ->

		super

		@moosh = @mainBox.editor.moosh

		@kilid = @mainBox.editor.kilid

		@kilidScopeForEdit = @kilid.getScope 'workspace-list-view'

		@node = Foxie('.timeflow-workspaceList').putIn(@mainBox.node)

		@holder = Foxie('.timeflow-workspaceList-holder').putIn(@node)

		@model = @mainBox.editor.model.workspaces

		window.model = @model

		@model.on 'new-workspace', (ws) =>

			@_recognizeNewWorkspace ws

		do @_initRename

		do @_initNewBtn

	_recognizeNewWorkspace: (ws) ->

		wsNode = new Foxie('.timeflow-workspaceList-workspace').putIn(@holder)

		wsNode.node.innerText = ws.name

		@_attachCtrl wsNode.node

		ws.on 'remove', =>

			wsNode.remove()

		@moosh.onClick(wsNode)
		.withNoKeys()
		.onDone (e) =>

			ws.activate()

		@moosh.onClick(wsNode)
		.withKeys('ctrl')
		.onDone (e) =>

			@moosh.ignore(wsNode)

			@_startEdit wsNode, =>

				@moosh.unignore(wsNode)

				if wsNode.node.innerText.trim() is ''

					ws.remove()

				else

					ws.rename wsNode.node.innerText.trim()

			, =>

				@moosh.unignore(wsNode)

				wsNode.node.innerText = ws.name

	_attachCtrl: (node) ->

		@moosh.onHover(node)
		.withKeys('ctrl')
		.onEnter =>

			node.classList.add 'pre-edit'

		.onLeave =>

			node.classList.remove 'pre-edit'

		return

	_initRename: ->

		@currentEdit = null

		@kilidScopeForEdit.on('enter')
		.onEnd (e) =>

			@_storeEdit()

		@kilidScopeForEdit.on('esc')
		.onEnd (e) =>

			@_discardEdit()

		@kilidScopeForEdit.on('ctrl+delete')
		.onEnd (e) =>

			@currentEdit.innerText = ''

			@_storeEdit()

	_startEdit: (wsNode, cb, discard) ->

		@kilidScopeForEdit.activate()

		@currentEditCallBack = cb

		@currentEditDiscardCallBack = discard

		@currentEdit = wsNode.node

		@currentText = @currentEdit.innerText

		@currentEdit.contentEditable = yes

		@currentEdit.classList.add 'editing'

		@currentEdit.focus()

	_storeEdit: ->

		return unless @currentEdit?

		@kilidScopeForEdit.deactivate()

		@currentEdit.contentEditable = no

		@currentEdit.classList.remove 'editing'

		@currentEdit = null

		if @currentEditCallBack

			@currentEditCallBack()

			@currentEditCallBack = null

	_discardEdit: ->

		return unless @currentEdit?

		@kilidScopeForEdit.deactivate()

		@currentEdit.contentEditable = no

		@currentEdit.classList.remove 'editing'

		@currentEdit = null

		if @currentEditDiscardCallBack

			@currentEditDiscardCallBack()

			@currentEditDiscardCallBack = null

	_initNewBtn: ->

		@newBtn = Foxie('.timeflow-workspaceList-workspace').putIn(@node)

		@newBtn.node.innerText = '+'

		@moosh.onClick(@newBtn)
		.onDone =>

			@newBtn.node.innerText = ''

			@_startEdit @newBtn, =>

				if @newBtn.node.innerText isnt ''

					@model.get(@newBtn.node.innerText)

				@newBtn.node.innerText = '+'

			, =>

				@newBtn.node.innerText = '+'

	show: ->

		return if @visible

		@node.addClass 'visible'

		@visible = yes

		@moosh.onClickOutside @node, =>

			do @hide

		@_emit 'show'

	hide: ->

		if @visible

			@_storeEdit()

			@node.removeClass 'visible'

			@visible = no

		@_emit 'hide'

		return