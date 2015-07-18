class Video < ActiveRecord::Base
  before_destroy :cancel_encode
  after_destroy :delete_s3_files
  after_create :start_encode

  has_many :transcoder_jobs, dependent: :delete_all

  MAX_UPLOADSIZE = 50.megabytes

  def s3_folder_key
    "video/#{Rails.env}/#{uuid}"
  end

  def rtmp_url
    if rtmp_encoded?
      "rtmp://#{Settings.cloudfront.rtmp_domain}/cfx/st/&mp4:#{Video.signed_path(rtmp_path)}"
    else
      "rtmp://#{Settings.cloudfront.rtmp_domain}/cfx/st/&mp4:#{Video.signed_path(original_path)}"
    end
  end

  def hls_url
    "https://#{Settings.cloudfront.web_domain}/#{hls_master_path}"
  end

  def thumbnail_url
    "https://#{Settings.cloudfront.web_domain}/#{thumbnail_path}"
  end

  def original_path
    "#{s3_folder_key}/original.mp4"
  end

  def rtmp_path
    "#{s3_folder_key}/encoded.mp4"
  end

  def hls_master_path
    "#{s3_folder_key}/encoded.m3u8"
  end

  def hls_media_path(name)
    "#{s3_folder_key}/#{name}.m3u8"
  end

  def thumbnail_path
    "#{s3_folder_key}/thumb-00001.png"
  end

  def rtmp_job
    transcoder_jobs.where(job_type: :rtmp).first
  end

  def hls_job
    transcoder_jobs.where(job_type: :hls).first
  end

  def rtmp_encoded?
    job = rtmp_job
    return false unless job
    job.state.completed?
  end

  def hls_encoded?
    job = hls_job
    return false unless job
    job.state.completed?
  end

  def encoded?
    rtmp_encoded? && hls_encoded?
  end

  def update_properties
    if rtmp_encoded?
      job_id = rtmp_job.job_id
    elsif hls_encoded?
      job_id = hls_job.job_id
    else
      job_id = nil
    end
    return unless job_id

    transcoder = Aws::ElasticTranscoder::Client.new
    resp = transcoder.read_job(id: job_id)
    Rails.logger.debug("resp=#{resp.inspect}")
  
    output_width = resp.job.output.width
    output_height = resp.job.output.height
    if output_width > output_height
      self.width = resp.job.input.detected_properties.width
      self.height = resp.job.input.detected_properties.height
    else
      self.width = resp.job.input.detected_properties.height
      self.height = resp.job.input.detected_properties.width
    end
    self.duration = resp.job.input.detected_properties.duration_millis
    save!
  end

  class << self
    def signed_path(path)
      key_pair_id = Settings.cloudfront.key_pair_id
      private_key_path = "#{Rails.root}/lib/assets/pk.pem"
      signer = AwsCfSigner.new(private_key_path, key_pair_id)
      signer.sign(path, ending: Time.now + 3600)
    end

    def signed_url(path)
      key_pair_id = Settings.cloudfront.key_pair_id
      private_key_path = "#{Rails.root}/lib/assets/pk.pem"
      url = "https://#{Settings.cloudfront.web_domain}/#{path}"
      signer = AwsCfSigner.new(private_key_path, key_pair_id)
      signer.sign(url, ending: Time.now + 3600)
    end

    def signed_cookies(path, expiry)
      key_pair_id = Settings.cloudfront.key_pair_id
      private_key_path = "#{Rails.root}/lib/assets/pk.pem"
      resource = "https://#{Settings.cloudfront.web_domain}/#{path}/*"
      Rails.logger.debug("resource=#{resource}")
      condition = { "DateLessThan" => { "AWS:EpochTime" => expiry } }
      policy = { "Statement" => ["Resource" => resource, "Condition" => condition] }
      encoded_policy = Base64.encode64(policy.to_json).tr('+=/', '-_~')
      pkey = OpenSSL::PKey::read(File.read(private_key_path))
      signature = pkey.sign(OpenSSL::Digest::SHA1.new, policy.to_json)
      encoded_signature = Base64.encode64(signature).tr('+=/', '-_~')
      cookies = {
        'CloudFront-Expires' => expiry,
        'CloudFront-Policy' => encoded_policy.gsub!(/(\r\n|\r|\n)/, ''),
        'CloudFront-Signature' => encoded_signature.gsub!(/(\r\n|\r|\n)/, ''),
        'CloudFront-Key-Pair-Id' => key_pair_id
      }
      cookies
    end

    def new_session_path
      "session/#{SecureRandom.uuid}.html"
    end
  end

  private

  def delete_s3_files
    # 以下をBucketPolicyに追加
    #
    #   "Statement": [
    #   {
    #     "Sid": "AddPerm",
    #     "Effect": "Allow",
    #     "Principal": "*",
    #     "Action": [
    #       "s3:DeleteObject"
    #     ],
    #     "Resource": "arn:aws:s3:::tanakatsuyo-streaming-protected/*"
    #   }
    #   ]
    #
    bucket = Settings.s3.bucket
    key = s3_folder_key

    s3 = Aws::S3::Client.new
    tree = s3.list_objects(bucket: bucket, prefix: key)
    files = tree.contents.collect { |f| { key: f.key } }
    resp = s3.delete_objects(bucket: bucket, delete: { objects: files })
    Rails.logger.debug(resp)
  end

  def start_encode
    transcoder = Aws::ElasticTranscoder::Client.new

    # rtmp
    rtmp_job = transcoder.create_job(pipeline_id: Settings.transcoder.pipeline_id,
                                     input: { key: original_path,
                                              frame_rate: 'auto',
                                              resolution: 'auto',
                                              aspect_ratio: 'auto' },
                                     output: { key: 'encoded.mp4',
                                               thumbnail_pattern: 'thumb-{count}',
                                               preset_id: '1351620000001-100070' },
                                     output_key_prefix: s3_folder_key + '/')

    # hls
    hls_job = transcoder.create_job(pipeline_id: Settings.transcoder.pipeline_id,
                                    input: { key: original_path,
                                              frame_rate: 'auto',
                                              resolution: 'auto',
                                              aspect_ratio: 'auto' },
                                    outputs: [{ key: 'hls_400k_',
                                              preset_id: '1351620000001-200050',
                                              segment_duration: '10.0' },
                                              { key: 'hls_600k_',
                                                preset_id: '1351620000001-200040',
                                                segment_duration: '10.0' }],
                                    output_key_prefix: s3_folder_key + '/',
                                    playlists: [{ name: 'encoded',
                                                  format: 'HLSv3',
                                                  output_keys: ['hls_400k_', 'hls_600k_'] }])

    TranscoderJob.create(job_id: rtmp_job.job.id, job_type: :rtmp, video_id: id)
    TranscoderJob.create(job_id: hls_job.job.id, job_type: :hls, video_id: id)
  end

  def cancel_encode
    transcoder = Aws::ElasticTranscoder::Client.new

    transcoder_jobs.each do |job|
      if job.state.progressing?
        begin
          # elastic transcoderが処理を開始していたら例外になる
          transcoder.cancel_job(id: job.job_id)
        rescue => e
        end
      end
    end
  end
end
