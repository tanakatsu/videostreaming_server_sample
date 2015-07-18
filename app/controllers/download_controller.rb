class DownloadController < ApplicationController
  before_action :site_http_basic_authenticate_with unless Rails.env.development?

  def file
    return :not_found if params[:name].blank?

    key = "app/#{params[:name]}"
    obj = Aws::S3::Object.new(Settings.s3.bucket, key)
    url = obj.presigned_url(:get)

    redirect_to url
  end

  private

  def site_http_basic_authenticate_with
    authenticate_or_request_with_http_basic("Application") do |name, password|
      name == Settings.basicauth.username && password == Settings.basicauth.password
    end
  end
end
