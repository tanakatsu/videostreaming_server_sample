class TranscoderJob < ActiveRecord::Base
  belongs_to :video

  extend Enumerize
  enumerize :state, in: [:progressing, :completed, :error], default: :progressing
  enumerize :job_type, in: [:rtmp, :hls]
end
