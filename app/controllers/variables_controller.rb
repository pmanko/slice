# frozen_string_literal: true

# Allows project editors to view and modify project variables.
class VariablesController < ApplicationController
  before_action :authenticate_user!
  before_action :find_viewable_project_or_redirect, only: [
    :report_lookup, :search, :checks_search, :events_search, :values_search
  ]
  before_action :find_editable_project_or_redirect, only: [
    :index, :show, :new, :edit, :create, :update, :destroy, :copy,
    :add_grid_variable, :restore
  ]
  before_action :find_restorable_variable_or_redirect, only: [:restore]
  before_action :find_editable_variable_or_redirect, only: [
    :show, :edit, :update, :destroy
  ]

  def report_lookup
    @variable = @project.variable_by_id params[:variable_id]
  end

  def copy
    variable = viewable_variables.find_by_id params[:id]
    @variable = current_user.variables.new(variable.copyable_attributes) if variable

    if @variable
      render :new
    else
      redirect_to project_variables_path(@project)
    end
  end

  def add_grid_variable
    @child_grid_variable = @project.grid_variables.new
  end

  # GET /variables
  def index
    @order = scrub_order(Variable, params[:order], 'variables.name')
    variable_scope = viewable_variables.search(params[:search]).order(@order)
    variable_scope = variable_scope.where(user_id: params[:user_id]) if params[:user_id].present?
    variable_scope = variable_scope.with_variable_type(params[:variable_type]) if params[:variable_type].present?
    @variables = variable_scope.page(params[:page]).per(20)
  end

  # GET /search.json
  def search
    variable_scope = viewable_variables.where(variable_type: %w(dropdown checkbox radio string integer numeric date calculated imperial_height imperial_weight))
                                       .where('name ILIKE (?)', "#{params[:q]}%")
                                       .order(:name).limit(10)
    render json: variable_scope.pluck(:name)
  end

  def values_search
    @variable = viewable_variables.where('name ILIKE ?', params[:q].split(':').first).first
    render json: (@variable ? @variable.shared_options : []) + [{value: 'any'}, { value: 'missing' }]
  end

  # GET /checks_search.json
  def checks_search
    check_scope = @project.checks.runnable
                          .where('slug ILIKE (?)', "#{params[:q]}%")
                          .order(:slug).limit(10)
    render json: check_scope.pluck(:slug)
  end

  # GET /events_search.json
  def events_search
    event_scope = @project.events
                          .where('slug ILIKE (?) or id = ?', "#{params[:q]}%", params[:q].to_i)
                          .order(:slug).limit(10)
    render json: event_scope.collect(&:to_param)
  end

  # GET /variables/1
  def show
  end

  # GET /variables/new
  def new
    @variable = current_user.variables.where(project_id: @project.id).new
  end

  # GET /variables/1/edit
  def edit
  end

  # POST /variables
  def create
    @variable = current_user.variables.where(project_id: @project.id).new(variable_params)
    if @variable.save
      @variable.create_variables_from_questions!
      @variable.update_grid_tokens!
      url = if params[:continue].to_s == '1'
              new_project_variable_path(@variable.project)
            else
              [@variable.project, @variable]
            end
      redirect_to url, notice: 'Variable was successfully created.'
    else
      render :new
    end
  end

  # PATCH /variables/1
  def update
    if @variable.update(variable_params)
      @variable.update_grid_tokens!
      url = if params[:continue].to_s == '1'
              new_project_variable_path(@variable.project)
            else
              [@variable.project, @variable]
            end
      redirect_to url, notice: 'Variable was successfully updated.'
    else
      render :edit
    end
  end

  # DELETE /variables/1
  def destroy
    @variable.destroy

    respond_to do |format|
      format.html { redirect_to project_variables_path(@project) }
      format.js
    end
  end

  # POST /variables/1/restore
  def restore
    @variable.update deleted: false
    redirect_to [@project, @variable]
  end

  private

  def viewable_variables
    current_user.all_viewable_variables.where(project_id: @project.id)
  end

  def find_editable_variable_or_redirect
    @variable = @project.variables.find_by_id(params[:id])
    redirect_without_variable
  end

  def find_restorable_variable_or_redirect
    @variable = Variable.where(project_id: @project.id, deleted: true).find_by_id(params[:id])
    redirect_without_variable
  end

  def redirect_without_variable
    return if @variable
    empty_response_or_root_path(project_variables_path(@project))
  end

  def variable_params
    params[:variable] ||= {}
    params[:variable][:updater_id] = current_user.id
    clean_domain_id
    parse_variable_dates
    params.require(:variable).permit(
      :name, :display_name, :description, :variable_type,
      :updater_id, :display_name_visibility, :prepend, :append, :field_note,
      # For Integers and Numerics
      :hard_minimum, :hard_maximum, :soft_minimum, :soft_maximum,
      # For Dates
      :date_hard_maximum, :date_hard_minimum, :date_soft_maximum,
      :date_soft_minimum,
      # For Date, Time
      :show_current_button,
      # For Time
      :show_seconds,
      # For Time Duration
      :time_duration_format,
      # For Calculated Variables
      :calculation, :format, :hide_calculation,
      # For Integer, Numeric, and Calculated
      :units,
      # For Grid Variables
      { grid_tokens: [:variable_id] },
      :multiple_rows, :default_row_number,
      # For Autocomplete Strings
      :autocomplete_values,
      # Radio and Checkbox
      :alignment, :domain_id
    )
  end

  def clean_domain_id
    if params[:variable][:variable_type] && !Variable::TYPE_DOMAIN.include?(params[:variable][:variable_type])
      params[:variable][:domain_id] = nil
    end
  end

  def parse_variable_dates
    parse_date_if_key_present(:variable, :date_hard_maximum)
    parse_date_if_key_present(:variable, :date_hard_minimum)
    parse_date_if_key_present(:variable, :date_soft_maximum)
    parse_date_if_key_present(:variable, :date_soft_minimum)
  end
end
