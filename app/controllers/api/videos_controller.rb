class Api::VideosController < ApplicationController
  require 'net/http'
  protect_from_forgery except: [:status]

  PAGE = 1
  PAGESIZE = 10

  def list
    query = params[:q]
    @page = params[:page] ? params[:page].to_i : PAGE
    @pagesize = params[:pagesize] ? params[:pagesize].to_i : PAGESIZE

    @page = [@page, 1].max # 1以上にする
    offset = (@page - 1) * @pagesize

    if query
      if query.blank?
        @videos = []
      else
        @videos = Video.where('name LIKE ?', '%' + query + '%')
                       .order('created_at desc')
                       .offset(offset)
                       .limit(@pagesize)
      end
    else
      @videos = Video.order('created_at desc').offset(offset).limit(@pagesize)
    end
    @videos = @videos.select(&:encoded?)
    @host_with_protocol = "#{request.protocol}#{request.raw_host_with_port}"
  end

  def status
    x_amz_sns_message_type = request.headers['HTTP_X_AMZ_SNS_MESSAGE_TYPE']
    Rails.logger.info("x_amz_sns_message_type=#{x_amz_sns_message_type}")

    case x_amz_sns_message_type
    when 'SubscriptionConfirmation'
      data = JSON.parse(request.body.read)
      subscribe_topic(data['SubscribeURL'])
    when 'Notification'
      data = JSON.parse(request.body.read)
      Rails.logger.info("data=#{data.to_json}")
      message = JSON.parse(data["Message"])
      update_job_status(message)
    end

    head :ok
  end

  private

  def subscribe_topic(url)
    Rails.logger.info("subscribe url=#{url}")

    uri = URI.parse(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    response = http.request(Net::HTTP::Get.new(uri.request_uri))

    Rails.logger.info("response code=#{response.code}")
    Rails.logger.info("response body=#{response.body}")
  end

  def update_job_status(message)
    state = message["state"].downcase
    job_id = message["jobId"]

    job = TranscoderJob.find_by(job_id: job_id)
    unless job
      Rails.logger.info("transcoder job(#{job_id}) is not found")
      return
    end

    Rails.logger.info("job_id=#{job_id}")
    Rails.logger.info("state=#{state}")

    job.update_attribute(:state, state)

    video = job.video
    if job.state.completed? && (video.width.nil? || video.height.nil?)
      video.update_properties
      Rails.logger.info("width=#{video.width}, height=#{video.height}, duration=#{video.duration}")
    end
  end
end
