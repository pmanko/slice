# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://jashkenas.github.com/coffee-script/

@toggleOptions = (element) ->
  if $(element).val() in ['dropdown', 'checkbox', 'radio']
    $('[data-object~="options"]').show()
  else
    $('[data-object~="options"]').hide()
  if $(element).val() in ['integer', 'numeric']
    $('[data-object~="number"]').show()
  else
    $('[data-object~="number"]').hide()

@checkForBlankOptions = () ->
  blank_options = $('[data-object~="option-name"]').filter( () ->
    $.trim($(this).val()) == ''
  )
  blank_options.parent().parent().addClass('error')
  unless $('#variable_variable_type').val() not in ['dropdown', 'checkbox', 'radio'] or blank_options.size() == 0 or confirm('Options with blank names will be removed. Proceed anyways?')
    return false
  true

@checkMinMax = () ->
  number_fields = $('[data-object~="minmax"]').filter( () ->
    parseInt($.trim($(this).val())) < parseInt($(this).attr('min')) or parseInt($.trim($(this).val())) > parseInt($(this).attr('max'))
  )
  number_fields.parent().parent().addClass('error')
  if number_fields.size() > 0
    alert('Some numeric fields are out of range!')
    return false
  true

jQuery ->
  $('#add_more_options').on('click', () ->
    $.post(root_url + 'variables/add_option', $("form").serialize() + "&_method=post", null, "script")
    false
  )

  $(document)
    .on('change', '#variable_variable_type', () -> toggleOptions($(this)))

  $('#options[data-object~="sortable"]').sortable( placeholder: "well alert alert-block" )

  $(document).on('click', '[data-object~="form-check-before-submit"]', () ->
    if checkForBlankOptions() == false
      return false
    $($(this).data('target')).submit()
    false
  )

  $(document).on('click', '[data-object~="variable-check-before-submit"]', () ->
    if checkMinMax() == false
      return false
    $($(this).data('target')).submit()
    false
  )
