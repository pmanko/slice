class SheetVariable < ActiveRecord::Base
  attr_accessible :response, :sheet_id, :user_id, :variable_id, :response_file, :response_file_uploaded_at, :response_file_cache, :remove_response_file

  audited associated_with: :sheet
  has_associated_audits

  # Model Validation
  belongs_to :sheet, touch: true
  belongs_to :variable
  belongs_to :user
  has_many :grids
  has_many :responses

  validates_presence_of :sheet_id, :variable_id, :user_id

  mount_uploader :response_file, GenericUploader

  def max_grids_position
    self.variable.variable_type == 'grid' && self.grids.size > 0 ? self.grids.pluck(:position).max : -1
  end

  def update_responses!(values, current_user)
    old_response_ids = self.responses.collect{|r| r.id} # Could use pluck, but pluck has issues with scopes and unsaved objects
    new_responses = []
    values.select{|v| not v.blank?}.each do |value|
      r = Response.find_or_create_by_sheet_id_and_sheet_variable_id_and_variable_id_and_value(self.sheet_id, self.id, self.variable_id, value, { user_id: current_user.id })
      new_responses << r
    end
    self.responses = new_responses
    Response.where(id: old_response_ids, sheet_variable_id: nil).destroy_all
  end

  def update_grid_responses!(response, current_user)
    # {"13463487147483201"=>{"123"=>"6", "494"=>["", "1", "0"], "493"=>"This is my institution"},
    #  "1346351022118849"=>{"123"=>"1", "494"=>[""], "493"=>""},
    #  "1346351034600475"=>{"494"=>["", "0"], "493"=>""}}
    response.select!{|key, vhash| vhash.values.select{|v| (not v.kind_of?(Array) and not v.blank?) or (v.kind_of?(Array) and not v.join.blank?)}.size > 0}
    response.each_with_index do |(key, variable_response_hash), position|
      variable_response_hash.each_pair do |variable_id, res|
        grid = self.grids.find_or_create_by_variable_id_and_position(variable_id, position, { user_id: self.user_id })
        if grid.variable.variable_type == 'file'
          grid_old = self.grids.find_by_variable_id_and_position(variable_id, key)
          if not res[:response_file].kind_of?(Hash) or (res[:response_file].kind_of?(Hash) and not res[:response_file][:cache].blank?)
            # New file added, do nothing
          elsif grid_old
            # Found preexisting grid
            # copy from existing grid
            res = { response_file: grid_old.response_file }
          else
            # No old grid found, remove file
            res = { remove_response_file: '1' }
          end
        end

        v_type = (grid.variable.variable_type == 'scale' ? grid.variable.scale_type : grid.variable.variable_type)

        case v_type when 'checkbox'
          res = [] if res.blank?
          grid.update_responses!(res, current_user) # Response should be an array
        else
          grid.update_attributes format_response(v_type, res)
        end

      end
    end

    self.grids.where("position >= ?", response.size).destroy_all
  end

  # Returns response as a hash that can sent to update_attributes
  def format_response(variable_type, response)
    case variable_type when 'file'
      response = {} if response.blank?
    when 'date'
      response = { response: parse_date(response, response) }
    when 'time'
      response = { response: parse_time(response) } # Currently things that aren't parsed are stored as blank.
    else
      response = { response: response }
    end
    response
  end


  # Return a hash that represents the name, value, and description of the response
  # Ex: Given Variable Gender With Response Male, returns: { label: 'Male', value: 'm', description: 'Male gender of human species' }
  def response_hash(position = nil, variable_id = nil)
    result = { name: '', value: '', description: '', color: '' }

    object = if position.blank? or variable_id.blank?
      self # SheetVariable
    else
      self.grids.find_by_variable_id_and_position(variable_id, position) # Grid
    end

    return result unless object

    if ['dropdown', 'radio'].include?(object.variable.variable_type) or (object.variable.variable_type == 'scale' and object.variable.scale_type == 'radio')
      hash = (object.variable.shared_options.select{|option| option[:value] == object.response}.first || {})
      result[:name] = hash[:name]
      result[:value] = hash[:value]
      result[:description] = hash[:description]
      result[:color] = hash[:color]
    elsif ['checkbox'].include?(object.variable.variable_type) or (object.variable.variable_type == 'scale' and object.variable.scale_type == 'checkbox')
      results = []
      object.variable.shared_options.select{|option| object.responses.pluck(:value).include?(option[:value])}.each do |option|
        result = { name: option[:name], value: option[:value], description: option[:description], color: option[:color] }
        results << result
      end
      result = results
    elsif ['integer', 'numeric', 'calculated'].include?(object.variable.variable_type)
      hash = object.variable.options_only_missing.select{|option| option[:value] == object.response}.first
      if hash.blank?
        result[:name] = ((not object.response.blank? and not object.response == 'NaN' and not object.variable.prepend.blank?) ? "#{object.variable.prepend} " : '') +
                        object.response +
                        ((not object.response.blank? and not object.response == 'NaN' and not object.variable.units.blank?) ? " #{object.variable.units}" : '') +
                        ((not object.response.blank? and not object.response == 'NaN' and not object.variable.append.blank?) ? " #{object.variable.append}" : '')
        result[:value] = object.response
        result[:description] = object.variable.description
      else
        result[:name] = hash[:value] + ": " + hash[:name]
        result[:value] = hash[:value]
        result[:description] = hash[:description]
      end
    elsif ['file'].include?(object.variable.variable_type)
      if object.response_file.size > 0
        result[:name] = object.response_file.to_s.split('/').last
        result[:value] = object.response_file
        result[:description] = object.variable.description
      end
    elsif ['date'].include?(object.variable.variable_type)
      result[:name] = object.response_with_add_on # Potentially format this in the future
      result[:value] = object.response
      result[:description] = object.variable.description
    elsif ['time'].include?(object.variable.variable_type)
      result[:name] = object.response_with_add_on # Potentially format this in the future
      result[:value] = object.response
      result[:description] = object.variable.description
    elsif ['string', 'text'].include?(object.variable.variable_type)
      result[:name] = object.response_with_add_on
      result[:value] = object.response
      result[:description] = object.variable.description
    end
    result
  end



  def response_with_add_on
    prepend_string = ''
    append_string = ''

    prepend_string = self.variable.prepend + " " if not self.response.blank? and not self.variable.prepend.blank?
    append_string =  " " + self.variable.append if not self.response.blank? and not self.variable.append.blank?
    prepend_string + self.response + append_string
  end

  private

  # Copied from Application Controller
  def parse_date(date_string, default_date = '')
    date_string.to_s.split('/').last.size == 2 ? Date.strptime(date_string, "%m/%d/%y") : Date.strptime(date_string, "%m/%d/%Y") rescue default_date
  end

  # Copied from Application Controller
  def parse_time(time_string, default_time = '')
    Time.parse(time_string).strftime('%H:%M:%S') rescue default_time
  end

end
