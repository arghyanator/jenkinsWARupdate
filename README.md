# Jenkins Project to update its own WAR file

## Shell script
This shell script downloads WAR file version specified as command line parameter and install the new var file in jenkins War file location.
```
#!/bin/bash
##
# Update Jenkins WAR file 
# after saving current war file
# Created: 2019
##

## Check if New version specified or not
if [ $# -ne 1 ];
	then echo "Please specify target Jenkins WAR file version to upgrade to..."
	echo ""
	exit 1
fi

UPGDVER=$1
echo "Please stand by while we upgrade Jenkins WAR to requested version of ${UPGDVER}..."

## Get current WAR file version
CURRVER=$(java -jar /usr/share/jenkins/jenkins.war --version)

## Make a backup of current WAR file
cp /usr/share/jenkins/jenkins.war /usr/share/jenkins/jenkins.war.old_${CURRVER}
##
## Download new war version from Jenkins Download site
wget http://updates.jenkins-ci.org/download/war/${UPGDVER}/jenkins.war -O /usr/share/jenkins/jenkins.war
## Restart jenkins service to load the new WAR (twice to load the custom logo and theme as well)
#service jenkins restart
#sleep 10
#service jenkins restart

## Schedule restart of jenkins in 5 minutes
echo "Scheduled Restart of Jenkins in 2 minutues - please do not start jobs in next 2 minutes..."
echo "service jenkins restart
sleep 10
service jenkins restart" >/root/restart_jenkins.sh
chmod +x /root/restart_jenkins.sh
apt-get -y install at || true
at now + 2 min -f /root/restart_jenkins.sh

## Check new WAR version to make sure
echo "Jenkins WAR upgraded to requested version - $(java -jar /usr/share/jenkins/jenkins.war --version)"
exit 0
```

## Python Flask based API

Create a python flask based API program to execute the shell script using user/token
```
#!/usr/bin/env python
import os
import subprocess
import time

from flask import render_template 
from flask import request
from flask import Flask, abort, request, jsonify, g, url_for
from flask_sqlalchemy import SQLAlchemy
from flask_httpauth import HTTPBasicAuth
from passlib.apps import custom_app_context as pwd_context
from itsdangerous import (TimedJSONWebSignatureSerializer
                          as Serializer, BadSignature, SignatureExpired)

# initialization
app = Flask(__name__)
app.config['SECRET_KEY'] = 'dunamis packer templates'
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///db.sqlite'
app.config['SQLALCHEMY_COMMIT_ON_TEARDOWN'] = True

# extensions
db = SQLAlchemy(app)
auth = HTTPBasicAuth()


class User(db.Model):
    __tablename__ = 'users'
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(32), index=True)
    password_hash = db.Column(db.String(64))

    def hash_password(self, password):
        self.password_hash = pwd_context.encrypt(password)

    def verify_password(self, password):
        return pwd_context.verify(password, self.password_hash)

    def generate_auth_token(self, expiration=600):
        s = Serializer(app.config['SECRET_KEY'], expires_in=expiration)
        return s.dumps({'id': self.id})

    @staticmethod
    def verify_auth_token(token):
        s = Serializer(app.config['SECRET_KEY'])
        try:
            data = s.loads(token)
        except SignatureExpired:
            return None    # valid token, but expired
        except BadSignature:
            return None    # invalid token
        user = User.query.get(data['id'])
        return user


@auth.verify_password
def verify_password(username_or_token, password):
    # first try to authenticate by token
    user = User.verify_auth_token(username_or_token)
    if not user:
        # try to authenticate with username/password
        user = User.query.filter_by(username=username_or_token).first()
        if not user or not user.verify_password(password):
            return False
    g.user = user
    return True

# Create username function - Disabled - as we dont want users to be created by anyone
@app.route('/api/users', methods=['POST'])
def new_user():
    username = request.json.get('username')
    password = request.json.get('password')
    if username is None or password is None:
        abort(400)    # missing arguments
    if User.query.filter_by(username=username).first() is not None:
        abort(400)    # existing user
    user = User(username=username)
    user.hash_password(password)
    db.session.add(user)
    db.session.commit()
    return (jsonify({'username': user.username}), 201,
            {'Location': url_for('get_user', id=user.id, _external=True)})


@app.route('/api/users/<int:id>')
def get_user(id):
    user = User.query.get(id)
    if not user:
        abort(400)
    return jsonify({'username': user.username})


# Generate token by providing registered user/pass
@app.route('/api/token')
@auth.login_required
def get_auth_token():
    token = g.user.generate_auth_token(600)
    return jsonify({'token': token.decode('ascii'), 'duration': 600})


@app.route('/api/runupgrade')
@auth.login_required
def runupgrade():
    warversion = request.args.get('warversion', None)
    cmd = subprocess.Popen(['/root/update_jenkins_version.sh',warversion],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    stdout,error = cmd.communicate()
    upgout = stdout.splitlines()

    return render_template('index.html', upgout=upgout)
 
if __name__ == '__main__':
    if not os.path.exists('db.sqlite'):
        db.create_all()
    app.run(debug=True, host='0.0.0.0', port=5000)
    
```

## Set up Jenkins freestyle project
> Create the user/password using curl command on the shell of jenkins master

```
curl -i -X POST -H "Content-Type: application/json" -d '{"username":"apiuser","password":"apipassword"}'  http://localhost:5000/api/users
```
> Add the user/password in Jenkins credentials store<br>
> Create the project with following options<br>

**Parameters**<br>
[Build string parameters](https://github.com/arghyanator/jenkinsWARupdate/blob/master/project_string_parameter.png)
