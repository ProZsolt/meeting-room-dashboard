# Meeting room dashboard

## Docker usage example
### Build
`docker build . --tag meeting-room-dashboard:1.0 --tag meeting-room-dashboard:latest`

### Run
`docker run -p 80:80 -d -e MRD_JSON_KEY="<cred_path>.json" -e MRD_PERSON="<impersonated_mail_address>" -e MRD_USER="<basicauth_usr>" -e MRD_PASSWORD="<basicauth_pw>" meeting-room-dashboard`