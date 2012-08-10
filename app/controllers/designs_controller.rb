class DesignsController < ApplicationController
  before_filter :authenticate_user!

  def copy
    design = current_user.all_viewable_designs.find_by_id(params[:id])
    respond_to do |format|
      if design and @design = current_user.designs.new(design.copyable_attributes)
        format.html { render 'new' }
        format.json { render json: @design }
      else
        format.html { redirect_to designs_path }
        format.json { head :no_content }
      end
    end
  end

  def selection
    @sheet = Sheet.new
    @design = current_user.all_viewable_designs.find_by_id(params[:sheet][:design_id])
  end

  def add_section
    @design = Design.new(post_params.except(:option_tokens))
    @option = { }
  end

  def add_variable
    @design = Design.new(post_params)
    @option = { variable_id: '' }
  end

  def variables
    @design = Design.new(params[:design])
  end

  def reorder
    @design = current_user.all_designs.find_by_id(params[:id])
    if @design
      if params[:rows].blank?
        @design.reorder_sections(params[:sections].to_s.split(','), current_user)
      else
        @design.reorder(params[:rows].to_s.split(','), current_user)
      end
      render 'reorder'
    else
      render nothing: true
    end
  end

  # GET /designs
  # GET /designs.json
  def index
    current_user.pagination_set!('designs', params[:designs_per_page].to_i) if params[:designs_per_page].to_i > 0
    design_scope = current_user.all_viewable_designs

    design_scope = design_scope.where(id: params[:design_ids]) unless params[:design_ids].blank?

    ['project', 'user'].each do |filter|
      design_scope = design_scope.send("with_#{filter}", params["#{filter}_id".to_sym]) unless params["#{filter}_id".to_sym].blank?
    end

    @search_terms = params[:search].to_s.gsub(/[^0-9a-zA-Z]/, ' ').split(' ')
    @search_terms.each{|search_term| design_scope = design_scope.search(search_term) }

    @order = scrub_order(Design, params[:order], 'designs.name')
    design_scope = design_scope.order(@order)

    @design_count = design_scope.count

    if params[:format] == 'csv'
      if @design_count == 0
        redirect_to designs_path, alert: 'No data was exported since no designs matched the specified filters.'
        return
      end
      generate_csv(design_scope)
      return
    end

    @designs = design_scope.page(params[:page]).per( current_user.pagination_count('designs') )

    respond_to do |format|
      format.html # index.html.erb
      format.js
      format.json { render json: @designs }
    end
  end

  def print
    @design = current_user.all_viewable_designs.find_by_id(params[:id])
    if @design
      render layout: false
    else
      render nothing: true
    end
  end

  # GET /designs/1
  # GET /designs/1.json
  def show
    @design = current_user.all_viewable_designs.find_by_id(params[:id])

    respond_to do |format|
      if @design
        format.html # show.html.erb
        format.json { render json: @design }
      else
        format.html { redirect_to designs_path }
        format.json { head :no_content }
      end
    end
  end

  # GET /designs/new
  # GET /designs/new.json
  def new
    @design = current_user.designs.new(post_params)

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @design }
    end
  end

  # GET /designs/1/edit
  def edit
    @design = current_user.all_designs.find_by_id(params[:id])
    redirect_to designs_path unless @design
  end

  # POST /designs
  # POST /designs.json
  def create
    @design = current_user.designs.new(post_params)

    respond_to do |format|
      if @design.save
        format.html { redirect_to @design, notice: 'Design was successfully created.' }
        format.json { render json: @design, status: :created, location: @design }
      else
        format.html { render action: "new" }
        format.json { render json: @design.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /designs/1
  # PUT /designs/1.json
  def update
    @design = current_user.all_designs.find_by_id(params[:id])

    respond_to do |format|
      if @design
        if @design.update_attributes(post_params)
          format.html { redirect_to @design, notice: 'Design was successfully updated.' }
          format.json { head :no_content }
        else
          format.html { render action: "edit" }
          format.json { render json: @design.errors, status: :unprocessable_entity }
        end
      else
        format.html { redirect_to designs_path }
        format.json { head :no_content }
      end
    end
  end

  # DELETE /designs/1
  # DELETE /designs/1.json
  def destroy
    @design = current_user.all_designs.find_by_id(params[:id])
    @design.destroy if @design

    respond_to do |format|
      format.html { redirect_to designs_path }
      format.js { render 'destroy' }
      format.json { head :no_content }
    end
  end

  private

  def generate_csv(design_scope)
    @csv_string = CSV.generate do |csv|
      csv << ['Variable Project', 'Design Name', 'Variable Name', 'Variable Display Name', 'Variable Header', 'Variable Description', 'Variable Type', 'Variable Options', 'Variable Branching Logic', 'Hard Min', 'Soft Min', 'Soft Max', 'Hard Max', 'Calculation', 'Variable Creator']

      design_scope.each do |design|
        design.options.each do |option|
          if option[:variable_id].blank?
            row = [
                    design.project ? design.project.name : '',
                    design.name,
                    option[:section_id],
                    option[:section_name],
                    nil, # Variable Header
                    option[:section_description], # Variable Description
                    'section',
                    nil, # Variable Options
                    option[:branching_logic],
                    nil, # Hard Min
                    nil, # Soft Min
                    nil, # Soft Max
                    nil, # Hard Max
                    nil, # Calculation
                    nil # Creator
                  ]
            csv << row
          elsif variable = current_user.all_viewable_variables.find_by_id(option[:variable_id])
            row = [
                    variable.project ? variable.project.name : '',
                    design.name,
                    variable.name,
                    variable.display_name,
                    variable.header, # Variable Header
                    variable.description, # Variable Description
                    variable.variable_type,
                    variable.options.blank? ? '' : variable.options, # Variable Options
                    option[:branching_logic],
                    variable.hard_minimum, # Hard Min
                    variable.soft_minimum, # Soft Min
                    variable.soft_maximum, # Soft Max
                    variable.hard_maximum, # Hard Max
                    variable.calculation, # Calculation
                    variable.user.name # Creator
                  ]
            csv << row
          end
        end
      end
    end
    file_name = (design_scope.size == 1 ? "#{design_scope.first.name.gsub(/[^ a-zA-Z0-9_-]/, '_')} DD" : 'Designs')
    send_data @csv_string, type: 'text/csv; charset=iso-8859-1; header=present',
                           disposition: "attachment; filename=\"#{file_name} #{Time.now.strftime("%Y.%m.%d %Ih%M %p")}.csv\""
  end

  def post_params
    params[:design] ||= {}

    params[:design][:updater_id] = current_user.id

    params[:design].slice(
      :name, :description, :project_id, :option_tokens, :email_template, :updater_id
    )
  end
end
