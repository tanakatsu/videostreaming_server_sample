S3DirectUpload.config do |c|
  c.access_key_id = Settings.aws.access_key_id         # your access key id
  c.secret_access_key = Settings.aws.secret_access_key # your secret access key
  c.bucket = Settings.s3.bucket                        # your bucket name
  c.region = Settings.aws.region                       # region prefix of your bucket url. This is _required_ for the non-default AWS region, eg. "s3-eu-west-1"
  c.url = "https://#{c.bucket}.s3-#{c.region}.amazonaws.com/"      # S3 API endpoint (optional), eg. "https://#{c.bucket}.s3.amazonaws.com/"
end
