Sends an email everytime a github wiki page has been updated

Setting up:
-----------

1. Deploy to heroku, add starter "Sendgrid" addon
2. Set `WIKI_UPDATE_RECEIVER_EMAIL` environment variable on heroku
3. Set `WIKI_UPDATE_SENDER_EMAIL` environment variable on heroku
4. Create webhook for a github repo that has a wiki. Choose "gollum" event, point it at the app.
