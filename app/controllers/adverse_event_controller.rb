# frozen_string_literal: true

# Provides authentication for single adverse event to medical monitor.
class AdverseEventController < ApplicationController
  prepend_before_action { request.env['devise.skip_timeout'] = true }
  skip_before_action :verify_authenticity_token
  before_action :find_adverse_event_or_redirect

  def show
    @adverse_event_review = @adverse_event.adverse_event_reviews.new
  end

  def review
    @adverse_event_review = @adverse_event.adverse_event_reviews.new(adverse_event_review_params)
    if @adverse_event_review.save
      redirect_to about_path, notice: 'Thank you for reviewing this adverse event.'
    else
      render :show
    end
  end

  private

  def adverse_event_review_params
    params.require(:adverse_event_review).permit(:name, :comment)
  end

  def authenticate_adverse_event_from_token!
    adverse_event_id = params[:authentication_token].to_s.split('-').first
    auth_token = params[:authentication_token].to_s.gsub(/^#{adverse_event_id}-/, '')
    adverse_event = adverse_event_id && AdverseEvent.current.where(closed: false).find_by(id: adverse_event_id)
    # Devise.secure_compare is used to mitigate timing attacks.
    if adverse_event && Devise.secure_compare(adverse_event.authentication_token, auth_token)
      @adverse_event = adverse_event
      @project = @adverse_event.project
    end
  end

  def find_adverse_event_or_redirect
    authenticate_adverse_event_from_token!
    redirect_to about_path, alert: 'Adverse event has been closed.' unless @adverse_event
  end
end
