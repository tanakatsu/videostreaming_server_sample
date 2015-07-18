# VideoStreamingServer Sample

### How to use

1. AWS Configuration
	- S3
		- create bucket
		- edit CORS configuration
		
		```
		<?xml version="1.0" encoding="UTF-8"?>
		<CORSConfiguration xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
    		<CORSRule>
        		<AllowedOrigin>*</AllowedOrigin>
        		<AllowedMethod>GET</AllowedMethod>
        		<AllowedMethod>POST</AllowedMethod>
        		<AllowedMethod>PUT</AllowedMethod>
        		<AllowedMethod>DELETE</AllowedMethod>
        		<MaxAgeSeconds>3000</MaxAgeSeconds>
        		<AllowedHeader>*</AllowedHeader>
    		</CORSRule>
		</CORSConfiguration>
		```
	- CloudFront keypair
		- create key pairs (via Security Credentials menu under your name)
		- take a note of Access Key ID
		- download pem and copy 
		```
		$ cp yourkey.pem lib/assets/
		```
	- Cloudfront
		- create Origin Access Identity
		- create RTMP distribution
			- Origin Domain Name:  select a S3 bucket
          - Restrict Bucket Access: Yes
          - Origin Access Identity:  select a OAI 
          - Restrict Viewer Access: Yes
          - Trusted Signers: Self
      - create Web distribution
      		- Origin Domain Name:  select a S3 bucket
          - Origin Access Identity:  select a OAI 
          - Restrict Viewer Access: Yes
          - Trusted Signers: Self 
	- SNS
     	- create subscription
      		- Protocol: http or https
          - Endpoint: [deploy host]/videos/upload_complete
	- ElasticTranscoder
     	- create pipeline
      		- Input Bucket: select a S3 bucket
          - S3 Bucket for Transcoded Files and Playlists: select a S3 bucket
          - Notifications
          	- On Progressing Event: Use an existing SNS topic
          	- Select a Topic: select a created SNS topic
          	         	
1. Edit env.sample.js depending on your environment
	- In case of Heroku, you can set environments variables using 'heroku config:set ENVNAME=value'
1. Start application
2. 
```
$ source env.sample.sh
$ rails s
```

### Related project

- [tanakatsu/reactnative\_video\_streaming\_player](https://github.com/tanakatsu/reactnative_video_streaming_player)
