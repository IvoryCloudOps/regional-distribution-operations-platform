#!/bin/bash

dnf install -y httpd

systemctl enable httpd
systemctl start httpd

cat > /var/www/html/index.html <<'EOF'
Regional Distribution Operations Platform
Instance healthy
EOF

