# frozen_string_literal: true

# Allows PDF files to be attached to a record.
class RandomizationSchedulePDFUploader < CarrierWave::Uploader::Base
  # Choose what kind of storage to use for this uploader:
  storage :file
  # storage :s3

  # Override the directory where uploaded files will be stored.
  # This is a sensible default for uploaders that are meant to be mounted:
  def store_dir
    File.join(
      "projects",
      model.randomization.project_id.to_s,
      "randomizations",
      model.randomization_id.to_s,
      "schedules"
      # , mounted_as.to_s
    )
  end

  # Provide a default URL as a default if there hasn't been a file uploaded:
  # def default_url
  #   "/assets/fallback/" + [version_name, "default.png"].compact.join("_")
  # end

  # Add a white list of extensions which are allowed to be uploaded.
  def extension_whitelist
    %w(pdf)
  end

  # Override the filename of the uploaded files:
  # def filename
  #   "something.jpg" if original_filename
  # end
end