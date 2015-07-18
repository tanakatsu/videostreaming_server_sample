json.array!(@videos) do |video|
  json.extract! video, :id, :name, :created_at
  json.url video_url(video)
  json.page @page
  json.pagesize @pagesize
  if video.encoded?
    json.thumbnail_url "#{@host_with_protocol}#{thumbnail_video_path(video)}"
    json.rtmp_url video.rtmp_url
    json.hls_url "#{@host_with_protocol}#{hls_playlist_video_path(video)}" # signed url
    json.hls_player_url "#{@host_with_protocol}#{hls_player_video_path(video)}"
    json.width video.width
    json.height video.height
    json.duration video.duration
  end
end
