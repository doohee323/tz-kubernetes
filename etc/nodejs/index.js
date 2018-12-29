'use strict';

var http = require('http');
var os = require("os");

var instance = process.env.INSTANCE || 'test instance';
var username = process.env.SECRET_USERNAME || 'username';
var password = process.env.SECRET_PASSWORD || 'password';
var db_host = process.env.DB_HOST || 'db_host';
var host = os.hostname();

var app = http.createServer(function (req, res) {
  console.log('Request from ', req.connection.remoteAddress);
  res.end('Hello from ' + instance + ' running on ' + host + ' by ' + username + '/' + password + ' with ' + db_host +' \n');
});

app.listen(3000, function() {
  console.log('listening on port 3000');
});
