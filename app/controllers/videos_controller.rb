# coding: utf-8
class VideosController < ApplicationController
  before_action :site_http_basic_authenticate_with, except: [:hls_playlist, :thumbnail, :hls_player] unless Rails.env.development?
  before_action :set_video, only: [:show, :edit, :update, :destroy, :hls_playlist, :thumbnail, :hls_player]
  before_action :check_encoded?, only: [:show] if Rails.env.development?

  # GET /videos
  # GET /videos.json
  def index
    @videos = Video.order('created_at desc').page(params[:page]).per(10)
    @admin = session[:visitor] != true
  end

  # GET /videos/1
  # GET /videos/1.json
  def show
    @hls_player = (browser.ios? || browser.android? || browser.safari?) && @video.encoded?
    @use_signed_cookie = true # signed cookieを使う場合

    clear_old_sessions
    if @use_signed_cookie
      if session_expired?
        session_page_key = create_session # signed_cookieをセットするページを作成
        @session_url = Video.signed_url(session_page_key)
        redirect_to @session_url
      end
    end
  end

  # GET /videos/new
  def new
    @video = Video.new
    @video.uuid = SecureRandom.uuid
  end

  # GET /videos/1/edit
  def edit
  end

  # POST /videos
  # POST /videos.json
  def create
    @video = Video.new(video_params)

    respond_to do |format|
      if @video.save
        format.html { redirect_to @video, notice: 'Video was successfully created.' }
        format.json { render :show, status: :created, location: @video }
      else
        format.html { render :new }
        format.json { render json: @video.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /videos/1
  # PATCH/PUT /videos/1.json
  def update
    respond_to do |format|
      if @video.update(video_params)
        format.html { redirect_to @video, notice: 'Video was successfully updated.' }
        format.json { render :show, status: :ok, location: @video }
      else
        format.html { render :edit }
        format.json { render json: @video.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /videos/1
  # DELETE /videos/1.json
  def destroy
    @video.destroy
    respond_to do |format|
      format.html { redirect_to videos_url, notice: 'Video was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  # POST /videos/upload_complete
  def upload_complete
    Rails.logger.debug('upload_complete:' + params.inspect)
    @unique_id = params[:unique_id]
  end

  # GET /videos/1/hls_playlist
  def hls_playlist
    use_cookie = params['cookie'] == "true" ? true : false
    
    if use_cookie
      # 署名つきCookieをセットした後CloudFront上のプレイリストファイルに遷移する
      clear_old_sessions
      session_page_key = create_session(:content) # signed_cookieをセットするページを作成
      @session_url = Video.signed_url(session_page_key)
      redirect_to @session_url
    else
      if media_playlist?
        playlist = media_playlist(params[:name])
      else
        playlist = master_playlist
      end
      #render text: playlist, disposition: 'inline' # for debug
      render text: playlist, disposition: 'inline', content_type: 'application/x-mpegURL'
    end
  end

  # GET /videos/1/hls_player
  def hls_player
    @use_flex = params[:flex] == "false" ? false : true

    if @video.width && @video.height
      @aspect_ratio = @video.width / @video.height
    else
      @aspect_ratio = nil
    end

    clear_old_sessions
    if session_expired?
      session_page_key = create_session(:not_pc_player) # signed_cookieをセットするページを作成
      @session_url = Video.signed_url(session_page_key)
      redirect_to @session_url and return
    end
  end

  # GET /videos/1/thumbnail
  def thumbnail
    signed_url = Video.signed_path(@video.thumbnail_url)
    redirect_to signed_url
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_video
    @video = Video.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def video_params
    params.require(:video).permit(:name, :uuid, :content_type)
  end

  def site_http_basic_authenticate_with
    authenticate_or_request_with_http_basic("Application") do |name, password|
      authed = false
      if name == Settings.basicauth.guest.username && password == Settings.basicauth.guest.password
        authed = true
        session[:visitor] = true
      elsif name == Settings.basicauth.admin.username && password == Settings.basicauth.admin.password
        authed = true
        session[:visitor] = nil
      end
      authed
    end
  end

  def check_encoded?
    return if @video.encoded?

    s3 = Aws::S3::Client.new
    unless @video.rtmp_encoded?
      begin
        s3.get_object(bucket: Settings.s3.bucket, key: @video.rtmp_path)
        @video.rtmp_job.update_attribute(:state, :completed) if @video.rtmp_job
      rescue => e
      end
    end

    unless @video.hls_encoded?
      begin
        s3.get_object(bucket: Settings.s3.bucket, key: @video.hls_master_path)
        @video.hls_job.update_attribute(:state, :completed) if @video.hls_job
      rescue => e
      end
    end

    @video.update_properties if @video.width.nil? || @video.height.nil?
  end

  def media_playlist?
    params[:name].present? && params[:name].match(/hls_\d+k_/)
  end

  def download_master_m3u8
    s3 = Aws::S3::Client.new
    key = @video.hls_master_path
    obj = s3.get_object(bucket: Settings.s3.bucket, key: key)
    obj.body
  end

  def download_media_m3u8(name)
    s3 = Aws::S3::Client.new
    key = @video.hls_media_path(name)
    obj = s3.get_object(bucket: Settings.s3.bucket, key: key)
    obj.body
  end

  def master_playlist
    # TODO: DBにパラメータを保存しておくようにする
    file = download_master_m3u8
    playlist = M3u8::Playlist.read file
    playlist.items.each do |item|
      item.uri = hls_playlist_video_path(@video, name: item.uri.gsub('.m3u8', ''))
    end
    playlist.to_s
  end

  def media_playlist(name)
    # TODO: DBにパラメータを保存しておくようにする
    file = download_media_m3u8(name)
    key_pair_id = Settings.cloudfront.key_pair_id
    private_key_path = "#{Rails.root}/lib/assets/pk.pem"
    signer = AwsCfSigner.new(private_key_path, key_pair_id)

    playlist = M3u8::Playlist.read file
    playlist.items.each do |item|
      url = "https://#{Settings.cloudfront.web_domain}/#{@video.s3_folder_key}/#{item.segment}"
      item.segment = signer.sign(url, ending: Time.now + 3600)
    end
    playlist.to_s
  end

  def create_session(page = :pc_player)
    new_session_s3key = Video.new_session_path
    cookies = Video.signed_cookies(@video.s3_folder_key, 1.hour.from_now.to_i)
    case page
    when :pc_player
      return_url = video_url(@video)
    when :not_pc_player
      return_url = hls_player_video_url(@video)
      unless request.GET.keys.empty?
        get_params = request.GET.map { |k, v| "#{k}=#{v}" }.join('&')
        return_url += "?#{get_params}"
      end
    when :content
      return_url = @video.hls_url
    end
    path = "/#{@video.s3_folder_key}/"
    script = ''
    cookies.each do |k,v|
      script << "document.cookie='#{k}=#{v};path=#{path}';"
    end
    script << "window.location.href='#{return_url}';"
    html = "<html><head><script>#{script}</script></head><body><p id='status'>authenticating...</p></body></html>"
    s3 = Aws::S3::Client.new
    s3.put_object(bucket: Settings.s3.bucket, key: new_session_s3key, body: html)
    new_session_s3key
  end

  def clear_old_sessions
    s3 = Aws::S3::Client.new
    tree = s3.list_objects(bucket: Settings.s3.bucket, prefix: 'session/')
    files = tree.contents.select { |f| f.last_modified < Time.now.utc - 1.hour }.collect { |f| { key: f.key }}
    s3.delete_objects(bucket: Settings.s3.bucket, delete: { objects: files }) if files.present?
  end

  def session_expired?
    if session[:authenticated_video] && session[:authenticated_video]["uuid"] == @video.uuid
      time = Time.at(session[:authenticated_video]["time"].to_i)
      if time >= Time.now - 1.minute
        return false
      end
    end
    session[:authenticated_video] = { uuid: @video.uuid, time: Time.now.to_i }
    true
  end
end
