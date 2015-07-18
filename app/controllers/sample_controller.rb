class SampleController < ApplicationController

  def rtmp
    @cloudfront_domain = 's2bosp9lce9byq'
    path = 'sample/000000-GOPR1190-0.pano.2000k.mp4'
    @rtmp_url = "rtmp://#{@cloudfront_domain}.cloudfront.net/cfx/st/&mp4:#{signed_path(path)}"
  end

  def hls

  end

  def hls_index
    @cloudfront_domain = 'd2y483bp0k4s6r'
    file = download_original_m3u8
    playlist = signed_m3u8_segments(file)
    render text: playlist, disposition: 'inline', content_type: 'application/x-mpegURL'
  end

  private

  def signed_path(path)
    key_pair_id = Settings.cloudfront.key_pair_id
    private_key_path = "#{Rails.root}/lib/assets/pk.pem"
    signer = AwsCfSigner.new(private_key_path, key_pair_id)
    signer.sign(path, ending: Time.now + 3600)
  end

  def download_original_m3u8
    s3 = Aws::S3::Client.new
    key = 'sample/ios/000000-GOPR1190-0.pano.2000k.m3u8'
    obj = s3.get_object(bucket: Settings.s3.bucket, key: key)
    obj.body
  end

  def signed_m3u8_segments(file)
    key_pair_id = Settings.cloudfront.key_pair_id
    private_key_path = "#{Rails.root}/lib/assets/pk.pem"
    signer = AwsCfSigner.new(private_key_path, key_pair_id)

    playlist = M3u8::Playlist.read file
    playlist.items.each do |item|
      url = "https://#{@cloudfront_domain}.cloudfront.net/sample/ios/#{item.segment}"
      item.segment = signer.sign(url, ending: Time.now + 3600)
    end
    playlist.to_s
  end
end
