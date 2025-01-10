#!/bin/bash

# Read from environment variables
DB_NAME=${SCAMAGNIFIER_MONGO_DB:-default_db_name}
DB_USER=${SCAMAGNIFIER_MONGO_NORMAL_USERNAME:-default_user}
DB_PWD=${SCAMAGNIFIER_MONGO_NORMAL_PASSWORD:-default_password}

# Create the JavaScript file with MongoDB commands
cat <<EOF > mongo-init.js
db = db.getSiblingDB("$DB_NAME");

db.createUser({
    user: '$DB_USER',
    pwd: '$DB_PWD',
    roles: [{
        role: 'readWrite',
        db: '$DB_NAME'
    }]
});
EOF

echo "JavaScript file created with the following content:"
cat mongo-init.js