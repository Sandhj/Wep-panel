LINK="https://raw.githubusercontent.com/Sandhj/Wep-panel/main/"

mkdir -p /root/web/templates
cd web
wget -q ${LINK}app.py

cd templates
#Home
wget -q ${LINK}/templates/Home/login.html
wget -q ${LINK}/templates/Home/register.html
wget -q ${LINK}/templates/Home/dash_admin.html
wget -q ${LINK}/templates/Home/dash_guest.html

#Server
wget -q ${LINK}templates/Home/add_server.html
wget -q ${LINK}templates/Home/delete_server.html
wget -q ${LINK}templates/Home/status_server.html

#Users
wget -q ${LINK}templates/Home/add_balance.html
wget -q ${LINK}templates/Home/kurangi_saldo.html
wget -q ${LINK}templates/Home/users.html

#Vpn
wget -q ${LINK}templates/Home/create_ssh.html
wget -q ${LINK}templates/Home/create_vmess.html
wget -q ${LINK}templates/Home/create_vless.html
wget -q ${LINK}templates/Home/create_trojan.html
wget -q ${LINK}templates/Home/delete_account.html
wget -q ${LINK}templates/Home/result.html
wget -q ${LINK}templates/Home/riwayat.html
