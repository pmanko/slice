# frozen_string_literal: true

# Grants access to public surveys for and adding grid rows.
class ExternalController < ApplicationController
  prepend_before_action { request.env["devise.skip_timeout"] = true }
  skip_before_action :verify_authenticity_token
  before_action :set_design, only: [:add_grid_row]
  before_action :set_variable, only: [:add_grid_row]

  # # GET /about
  # def about
  # end

  # # GET /about/use
  # def about_use
  # end

  # # GET /contact
  # def contact
  # end

  # # GET /landing
  # def landing
  # end

  # POST /external/add_grid_row.js?design=REQUIRED&variable_id=REQUIRED
  #      &design_option_id=REQUIRED&header=OPTIONAL&handoff=OPTIONAL
  def add_grid_row
    I18n.locale = World.language
    return unless @design

    @design_option = @design.design_options.find_by(id: params[:design_option_id])
    @project = @design.project
  end

  # GET /sitemap.xml.gz
  def sitemap_xml
    if ENV["AMAZON"].to_s == "true"
      Aws.config[:credentials] = Aws::Credentials.new(
        Rails.application.credentials.dig(:aws, :access_key_id),
        Rails.application.credentials.dig(:aws, :secret_access_key)
      )
      s3 = Aws::S3::Resource.new(region: Rails.application.credentials.dig(:aws, :region))
      bucket = Rails.application.credentials.dig(:aws, :bucket)
      obj = s3.bucket(bucket).object("sitemaps/sitemap.xml.gz")
      url = obj.presigned_url(:get, expires_in: ActiveStorage.service_urls_expire_in.to_i)
      redirect_to url
    else
      sitemap_xml = File.join(CarrierWave::Uploader::Base.root, "sitemaps", "sitemap.xml.gz")
      if File.exist?(sitemap_xml)
        send_file sitemap_xml
      else
        head :ok
      end
    end
  end

  # # GET /terms-of-service
  # def terms_of_service
  # end

  # # GET /privacy-policy
  # def privacy_policy
  # end

  # GET /version
  # GET /version.json
  def version
    render layout: "layouts/full_page"
  end

  private

  def set_design
    @design = set_publicly_viewable_design
    @design = set_handoff_design unless @design
    @design = set_current_user_design unless @design
    @design = set_assignment_design unless @design
  end

  def set_publicly_viewable_design
    Design.current.where(publicly_available: true).where(project_id: params[:project_id]).find_by_param(params[:design])
  end

  def set_handoff_design
    handoff = Handoff.find_by_param(params[:handoff])
    handoff.subject_event.event.designs.where(project_id: params[:project_id]).find_by_param(params[:design]) if handoff
  end

  def set_current_user_design
    current_user.all_viewable_designs.where(project_id: params[:project_id]).find_by_param(params[:design]) if current_user
  end

  def set_assignment_design
    @assignment = AeAssignment.where(reviewer: current_user).find_by(id: params[:assignment_id])
    @design = @assignment.ae_team_pathway.designs.find_by_param(params[:design]) if @assignment
  end

  def set_variable
    @variable = @design.variables.find_by(id: params[:variable_id]) if @design
    empty_response_or_root_path unless @variable
  end
end
