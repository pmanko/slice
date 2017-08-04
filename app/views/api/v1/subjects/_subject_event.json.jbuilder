# frozen_string_literal: true

json.extract! subject_event, :id, :name, :event_id, :event_date, :unblinded_responses_count, :unblinded_questions_count, :unblinded_percent

json.event_designs do
  json.array!(subject_event.event.event_designs.includes(:design)) do |event_design|
    json.extract! event_design.design, :name, :id
    sheets = @subject.sheets.where(subject_event: subject_event, design: event_design.design)
    json.sheets do
      json.array!(sheets) do |sheet|
        json.partial! "api/v1/subjects/sheet", sheet: sheet
      end
    end
  end
end