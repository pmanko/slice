# frozen_string_literal: true

require 'valuables/default'

module Valuables
  class TimeDurationResponse < Default
    include DateAndTimeParser

    def name
      hash = parse_time_duration(@object.response)
      if @object.variable.show_seconds?
        "#{hash[:hours]}h #{hash[:minutes]}m #{hash[:seconds]}s"
      else
        "#{hash[:hours]}h #{hash[:minutes]}m"
      end
    rescue
      @object.response
    end
  end
end