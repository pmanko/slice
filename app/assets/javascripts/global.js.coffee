@loadColorSelectors = () ->
  $('[data-object~="color-selector"]').each( () ->
    $this = $(this)
    $this.ColorPicker(
      color: $this.data('color')
      onShow: (colpkr) ->
        $(colpkr).fadeIn(500)
        return false
      onHide: (colpkr) ->
        $(colpkr).fadeOut(500)
        $($this.data('form')).submit()
        return false
      onChange: (hsb, hex, rgb) ->
        $($this.data('target')).val('#' + hex)
        $($this.data('target')+"_display").css('backgroundColor', '#' + hex)
      onSubmit: (hsb, hex, rgb, el) ->
        $(el).ColorPickerHide();
    )
  )

@slideToPosition = (position) ->
  $('html, body').animate({ scrollTop: $("[name='position_#{position}']").offset().top - 60 }, 'fast');

@showContourModal = () ->
  $("#contour-backdrop, .contour-modal-wrapper").show()
  $('html, body').animate({ scrollTop: $(".contour-modal-wrapper").offset().top - 80 }, 'fast');

@hideContourModal = () ->
  $("#contour-backdrop, .contour-modal-wrapper").hide()

@color_radio_group = (group_name) ->
  $(":radio[name='" + group_name + "']").each( (index, element) ->
    if $(element).prop('checked')
      $(element).parent().addClass('selected')
    else
      $(element).parent().removeClass('selected')
  )

@color_checkbox_group = (group_name) ->
  $(":checkbox[name='" + group_name + "']").each( (index, element) ->
    if $(element).prop('checked')
      $(element).parent().addClass('selected')
    else
      $(element).parent().removeClass('selected')
  )


jQuery ->
  $(document)
    .on('click', '[data-object~="remove"]', () ->
      plural = if $(this).data('count') == 1 then '' else 's'
      if $(this).data('count') in [0, undefined] or ($(this).data('count') and confirm('Removing this option will PERMANENTLY ERASE DATA you have collected. Are you sure you want to RESET responses that used this option from ' + $(this).data('count') + ' sheet' + plural +  '?'))
        $('#' + $(this).data('target')).remove()
        false
      else
        false
    )
    .on('click', '[data-object~="modal-show"]', () ->
      $($(this).data('target')).modal({ dynamic: true });
      false
    )
    .on('click', '[data-object~="modal-hide"]', () ->
      $($(this).data('target')).modal('hide');
      false
    )
    .on('click', "#contour-backdrop", (e) ->
      hideContourModal() if e.target.id = "contour-backdrop"
    )
    .on('click', '[data-object~="show-contour-modal"]', () ->
      showContourModal()
      false
    )
    .on('click', '[data-object~="hide-contour-modal"]', () ->
      hideContourModal()
      slideToPosition($(this).data('position')) if $(this).data('position')
      false
    )
    .on('click', '[data-object~="submit"]', () ->
      $($(this).data('target')).submit()
      false
    )
    .on('click', '[data-object~="reset-filters"]', () ->
      $('[data-object~="filter"]').val('')
      $('[data-object~="filter-html"]').html('')
      $('#variable-type-all').button('toggle')
      $('[data-object~="set-statuses"]').addClass('active')
      $('#statuses_pending').val('pending')
      $('#statuses_test').val('test')
      $('#statuses_valid').val('valid')
      $($(this).data('target')).submit()
      false
    )
    .on('click', '[data-object~="suppress-click"]', () ->
      false
    )
    .on('mouseenter', '[data-object~="hover-show"]', () ->
      return false unless document.documentElement.ontouchstart == undefined
      $('[data-object~="hover-show"]').each( (index, element) ->
        $($(element).data('target')).hide()
      )
      $($(this).data('target')).show()
    )
    .on('mouseleave', '[data-object~="hover-show"]', () ->
      $($(this).data('target')).hide()
    )
    .on('click', '[data-object~="set-audit-row"]', () ->
      if $(this).hasClass("active")
        $('[data-audit-row~="'+$(this).data('value')+'"]').hide()
      else
        $('[data-audit-row~="'+$(this).data('value')+'"]').show()
    )
    .on('focus', "select[rel~=tooltip], input[rel~=tooltip], textarea[rel~=tooltip]", () ->
      $(this).tooltip( trigger: 'focus' )
    )
    .on('focus', "[rel~=tooltip]", () ->
      $(this).tooltip( trigger: 'hover' )
    )
    .on('focus', "[rel~=popover]", () ->
      $(this).popover( offset: 10, trigger: 'focus' )
    )
    .ready( () ->
      if $("#sheet_design_id").val() == ''
        $("#sheet_design_id").focus()
      else
        $("#sheet_subject_id").focus()
      if $("#global-search").val() != ''
        $("#global-search").focus()
    )
    .on('click', '#global-search', (e) ->
      e.stopPropagation()
      false
    )
    .on('change', '.checkbox input:checkbox', () ->
      if $(this).is(':checked')
        $(this).parent().addClass('selected')
      else
        $(this).parent().removeClass('selected')
    )
    .on('change', '.radio input:radio', () ->
      group_name = $(this).attr('name')
      color_radio_group(group_name)
    )
    .keydown( (e) ->
      # p will enter the search box, Esc will exit
      if e.which == 80 and not $("input, textarea, select, a").is(":focus")
        $("#global-search").focus()
        e.preventDefault()
        return
      $("#global-search").blur() if $("#global-search").is(':focus') and e.which == 27
    )
    .on('click', '[data-object~="settings-save"]', () ->
      window.$isDirty = false
      $($(this).data('target')).submit()
      false
    )

  $("#global-search").typeahead(
    source: (query, process) ->
      return $.get(root_url + 'search', { q: query }, (data) -> return process(data))
    updater: (item) ->
      $("#global-search").val(item)
      $("#global-search-form").submit()
      return item
  )

  # $("[rel~=popover]").popover( offset: 10, trigger: 'focus' )
  $("span[rel~=tooltip], button[rel~=tooltip]").tooltip( trigger: 'hover' )

  window.$isDirty = false
  msg = 'You haven\'t saved your changes.'

  $(document).on('change', ':input', () ->
    if $("#isdirty").val() == '1'
      window.$isDirty = true
  )

  $(document).ready( () ->
    window.onbeforeunload = (el) ->
      if window.$isDirty
        return msg
  )

  # $(".datepicker").datepicker( "option", "onClose", (dateText, inst) -> $(this).focus() )

  $('[data-object~="typeaheadmap"]').each( () ->
    $this = $(this)
    $this.typeaheadmap( source: $this.data('source'), "key": "key", "value": "value" )
  )

  loadColorSelectors()
