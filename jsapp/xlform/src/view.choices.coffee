_ = require 'underscore'
Backbone = require 'backbone'
$choices = require './model.choices'
$modelUtils = require './model.utils'
$baseView = require './view.pluggedIn.backboneView'
$viewTemplates = require './view.templates'
$viewUtils = require './view.utils'
_t = require('utils').t

module.exports = do ->
  class ListView extends $baseView
    initialize: ({@rowView, @model})->
      @list = @model
      @row = @rowView.model
      $($.parseHTML $viewTemplates.row.selectQuestionExpansion()).insertAfter @rowView.$('.card__header')
      @$el = @rowView.$(".list-view")
      @ulClasses = @$("ul").prop("className")

    render: ->
      cardText = @rowView.$el.find('.card__text')
      if cardText.find('.card__buttons__multioptions.js-expand-multioptions').length is 0
        cardText.prepend $.parseHTML($viewTemplates.row.expandChoiceList())
      @$el.html (@ul = $("<ul>", class: @ulClasses))
      if @row.get("type").get("rowType").specifyChoice
        for option, i in @model.options.models
          new OptionView(model: option, cl: @model).render().$el.appendTo @ul
        if i == 0
          while i < 2
            @addEmptyOption("Option #{++i}")

        @$el.removeClass("hidden")
      else
        @$el.addClass("hidden")
      @ul.sortable({
          axis: "y"
          cursor: "move"
          distance: 5
          items: "> li"
          placeholder: "option-placeholder"
          opacity: 0.9
          scroll: false
          deactivate: =>
            if @hasReordered
              @reordered()
              @model.getSurvey()?.trigger('change')
            true
          change: => @hasReordered = true
        })
      btn = $($viewTemplates.$$render('xlfListView.addOptionButton'))
      btn.click(() =>
        i = @model.options.length
        @addEmptyOption("Option #{i+1}")
        @model.getSurvey()?.trigger('change')
        setTimeout =>
          @ul.find('li').last().find('.editable-wrapper').trigger('click')
        , 1
      )

      @$el.append(btn)
      return @

    addEmptyOption: (label)->
      emptyOpt = new $choices.Option(label: label)
      @model.options.add(emptyOpt)
      new OptionView(model: emptyOpt, cl: @model).render().$el.appendTo @ul
      lis = @ul.find('li')
      if lis.length == 2
        lis.find('.js-remove-option').removeClass('hidden')

    reordered: (evt, ui)->
      ids = []
      @ul.find("> li").each (i,li)=>
        lid = $(li).data("optionId")
        if lid
          ids.push lid
      for id, n in ids
        @model.options.get(id).set("order", n, silent: true)
      @model.options.comparator = "order"
      @model.options.sort()
      @hasReordered = false

  class OptionView extends $baseView
    tagName: "li"
    className: "multioptions__option xlf-option-view xlf-option-view--depr"
    events:
      "keyup input": "keyupinput"
      "click .js-remove-option": "remove"
    initialize: (@options)->
      Backbone.on('consentRowChoiceValueError', @onConsentRowChoiceValueError, @)
      Backbone.on('consentRowChoiceValueNotError', @onConsentRowChoiceValueNotError, @)

    onConsentRowChoiceValueError: (args) ->
      if args.cid == @model.cid
        @$el.siblings('.message').remove()
        @$el.closest('div').addClass('input-error')
        if @$el.siblings('.message').length is 0
          $message = $('<div/>').addClass('message').text('Consent items must have a value of "1"')
          @$el.after($message)

    onConsentRowChoiceValueNotError: (args) ->
      if args.cid == @model.cid
        @$el.closest('div').removeClass('input-error')
        @$el.siblings('.message').remove()

    render: ->
      @t = $("<i class=\"fa fa-trash-o js-remove-option\">")
      @pw = $("<div class=\"editable-wrapper js-cancel-select-row\">")
      @p = $("<span class=\"js-cancel-select-row\">")
      @c = $("<code><label>#{_t("Value:")}</label> <span class=\"js-cancel-select-row\">#{_t("AUTOMATIC")}</span></code>")
      @i = $("<code><label>#{_t("Image:")}</label> <span class=\"js-cancel-select-row\">#{_t("None")}</span></code>")
      @d = $('<div>')
      @optionImageField = 'image'
      if @model
        @p.html @model.get("label") || 'Empty'
        @$el.attr("data-option-id", @model.cid)
        $('span', @c).html @model.get("name")
        $('span', @i).html @model.get(@optionImageField)
        @model.set('setManually', true)
      else
        @model = new $choices.Option()
        @options.cl.options.add(@model)
        @p.html("Option #{1+@options.i}").addClass("preliminary")

      $viewUtils.makeEditable @, @model, @p, edit_callback: _.bind @saveValue, @
      @n = $('span', @c)
      $viewUtils.makeEditable @, @model, @n, edit_callback: (val) =>
        other_names = @options.cl.getNames()
        if @model.get('name')? && val.toLowerCase() == @model.get('name').toLowerCase()
          other_names.splice _.indexOf(other_names, @model.get('name')), 1
        valChanged = false
        if val is ''
          valChanged = true if val isnt @model.get('name')
          @model.unset('name')
          val = 'AUTOMATIC'
          @$el.trigger("choice-list-update", @options.cl.cid)
          if valChanged
            if @model.getSurvey()?
              @model.getSurvey()?.trigger('change', { cid: @model.cid })
            else
              @model.collection._parent.getSurvey()?.trigger('change', { cid: @model.cid })
            if @model.collection?.length == 1
              if parseInt(@model.get('name')) == 1
                Backbone.trigger('ocConsentRowsEvent', { type: 'consentRowChoiceValue', error: false, value: @model.get('name'), cid: @model.cid })
              else
                Backbone.trigger('ocConsentRowsEvent', { type: 'consentRowChoiceValue', error: true, value: @model.get('name'), cid: @model.cid })
          return
        else
          val = $modelUtils.sluggify(val, {
                    preventDuplicates: other_names
                    lowerCase: false
                    lrstrip: true
                    incrementorPadding: false
                    characterLimit: 14
                    validXmlTag: false
                    nonWordCharsExceptions: '+-.'
                  })
          valChanged = true if val isnt @model.get('name')
          @model.set('name', val)
          @$el.trigger("choice-list-update", @options.cl.cid)
          if valChanged
            if @model.getSurvey()?
              @model.getSurvey()?.trigger('change', { cid: @model.cid })
            else
              @model.collection._parent.getSurvey()?.trigger('change', { cid: @model.cid })
            if @model.collection?.length == 1
              if parseInt(@model.get('name')) == 1
                Backbone.trigger('ocConsentRowsEvent', { type: 'consentRowChoiceValue', error: false, value: @model.get('name'), cid: @model.cid })
              else
                Backbone.trigger('ocConsentRowsEvent', { type: 'consentRowChoiceValue', error: true, value: @model.get('name'), cid: @model.cid })
          return newValue: @model.get('name')

      @j = $('span', @i)
      $viewUtils.makeEditable @, @model, @j, edit_callback: (val) =>
        valChanged = false
        if val is ''
          valChanged = true if val isnt @model.get(@optionImageField)
          @model.unset(@optionImageField)
          val = 'None'
          @$el.trigger("choice-list-update", @options.cl.cid)
          @model.getSurvey()?.trigger('change') if valChanged
        else
          valChanged = true if val isnt @model.get(@optionImageField)
          if val is 'None' and @model.get(@optionImageField) is undefined
            valChanged = false

          if valChanged
            @model.set(@optionImageField, val)
            @$el.trigger("choice-list-update", @options.cl.cid)
            if @model.getSurvey()?
              @model.getSurvey()?.trigger('change', { cid: @model.cid })
            else
              @model.collection._parent.getSurvey()?.trigger('change', { cid: @model.cid })
        return

      @pw.html(@p)

      @pw.on 'click', (event) =>
        if !@p.is(':hidden') && event.target != @p[0]
          @p.click()

      @d.append(@pw)
      @d.append(@t)
      @d.append(@c)
      @d.append(@i)
      @$el.html(@d)
      @
    keyupinput: (evt)->
      ifield = @$("input.inplace_field")
      if evt.keyCode is 8 and ifield.hasClass("empty")
        ifield.blur()

      if ifield.val() is ""
        ifield.addClass("empty")
      else
        ifield.removeClass("empty")

    remove: ()->
      $parent = @$el.parent()

      @model.getSurvey()?.trigger('change')

      @$el.remove()
      @model.destroy()

      lis = $parent.find('li')
      if lis.length == 1
        lis.find('.js-remove-option').addClass('hidden')

    saveValue: (nval)->
      # if new value has no non-space characters, it is invalid
      unless "#{nval}".match /\S/
        nval = false

      if nval
        nval = nval.replace /\t/g, ' '
        valChanged = false
        valChanged = true if nval isnt @model.get('label')
        @model.set("label", nval, silent: true)
        other_names = @options.cl.getNames()
        if !@model.get('setManually')
          sluggifyOpts =
            preventDuplicates: other_names
            lowerCase: false
            stripSpaces: true
            lrstrip: true
            incrementorPadding: 3
            validXmlTag: true
          @model.set("name", $modelUtils.sluggify(nval, sluggifyOpts))
        @$el.trigger("choice-list-update", @options.cl.cid)

        @model.getSurvey()?.trigger('change') if valChanged
        return
      else
        return newValue: @model.get "label"

  ListView: ListView
  OptionView: OptionView
