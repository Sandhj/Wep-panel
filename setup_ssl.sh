#Pasang Domain Dan SSL

# Pastikan script dijalankan dengan akses root
if [ "$(id -u)" -ne 0 ]; then
    echo "Script ini harus dijalankan dengan akses root."
    exit 1
fi


# Lokasi file konfigurasi Nginx
NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"

# Membuat file konfigurasi Nginx
cat > "$NGINX_CONF" <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://$FLASK_IP:$PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

echo "File konfigurasi telah dibuat: $NGINX_CONF"

# Membuat symbolic link ke sites-enabled jika belum ada
if [ ! -L "/etc/nginx/sites-enabled/$DOMAIN" ]; then
    ln -s "$NGINX_CONF" /etc/nginx/sites-enabled/
    echo "Symbolic link dibuat: /etc/nginx/sites-enabled/$DOMAIN"
fi

# Uji konfigurasi Nginx
nginx -t
if [ $? -eq 0 ]; then
    # Reload Nginx
    systemctl reload nginx
    echo "Nginx berhasil di-reload dan konfigurasi telah aktif."
else
    echo "Terdapat kesalahan dalam konfigurasi Nginx. Silahkan periksa kembali file $NGINX_CONF."
fi

#pasang SSL
sudo apt install certbot python3-certbot-nginx -y
sudo certbot --nginx -d $DOMAIN
