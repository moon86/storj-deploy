#!/bin/bash

cd ~
echo ""
echo "##########################"
echo "# Installation de davfs2 #"
echo "##########################"

sudo apt-get update && sudo apt-get install -y davfs2 wget python git
sudo chmod 777 /etc/davfs2/davfs2.conf
sudo adduser $USER davfs2

echo "###############################################################"
echo "# Création du point de montage et des répertoires de stockage #"
echo "###############################################################"

if [ ! -d "/home/$USER/Storj" ];
then
  echo "Création du dossier /home/$USER/Storj";
  mkdir /home/$USER/Storj
fi
if [ ! -d "/home/$USER/Storj/dataDrive" ];
then
  echo "Création du dossier /home/$USER/Storj/dataDrive";
  mkdir /home/$USER/Storj/dataDrive
fi
echo -n "Please Input the OD4B Link, e.g. 'https://****-my.sharepoint.com/personal/*****/Documents/' [ENTER]: "
read OD4B
echo -n "Please Input the OneDrive Username, e.g. 'user@domain.xyz' [ENTER]: "
read oneDriveUsername
echo -n "Please input the OneDrive Password [ENTER]: "
read -s oneDrivePassword
echo ''
echo -n "How many Storj nodes do you want to create ? [ENTER]: "
read nbStorjNodes
echo -n "Storj node size (ie : 500GB) ? [ENTER]: "
read storjNodeSize
echo -n "What is your public IP / Domain name ? [ENTER]: "
read storjNodeIP
echo -n "What is your ETH wallet ? [ENTER]: "
read ethWallet
echo -n "What is your Storj Stat key ? [ENTER]: "
read storjStatToken

echo "Press any key to continue"
read

wget https://raw.githubusercontent.com/yulahuyed/test/master/get-sharepoint-auth-cookie.py
echo "python get-sharepoint-auth-cookie.py ${OD4B} ${oneDriveUsername} ${oneDrivePassword} > cookie.txt"
python get-sharepoint-auth-cookie.py ${OD4B} ${oneDriveUsername} ${oneDrivePassword} > cookie.txt
sed -i "s/ //g" cookie.txt
cat cookie.txt
echo "Press any key to continue"
read
COOKIE=$(cat cookie.txt)
DAVFS_CONFIG=$(grep -i "use_locks 0" /etc/davfs2/davfs2.conf)
if [ "${DAVFS_CONFIG}" == "use_locks 0" ] 
then
  echo "continue..."
else
  echo "use_locks 0" >> /etc/davfs2/davfs2.conf
  echo "[/home/$USER/Storj/dataDrive]" >> /etc/davfs2/davfs2.conf
  echo "add_header Cookie ${COOKIE}" >> /etc/davfs2/davfs2.conf
fi
rm cookie.txt get-sharepoint-auth-cookie.py

echo "###########################################"
echo "# Ajout du point de montage dans la fstab #"
echo "###########################################"

FSTABALREADYEXIST=`sudo cat /etc/fstab | grep dataDrive | wc -l`
if [[ $FSTABALREADYEXIST -lt 1 ]]
then
cat << EOF | sudo tee -a /etc/fstab

# WebDAV
${OD4B} /home/$USER/Storj/dataDrive davfs rw,user,_netdev,noauto 0 0
EOF
else
  echo "Données déjà existantes"
fi
sudo cat /etc/fstab
echo "Press any key to continue"
read

echo "##########################################"
echo "# Enregsitrement des identifiants WebDav #"
echo "##########################################"

USERALREADYEXIST=`sudo cat /etc/davfs2/secrets | grep dataDrive | wc -l`
if [[ $USERALREADYEXIST -lt 1 ]]
then
cat << EOF | sudo tee -a /etc/davfs2/secrets
# OneDrive application password
/home/$USER/Storj/dataDrive $oneDriveUsername $oneDrivePassword
EOF
else
  echo "Données déjà existantes"
fi
sudo cat /etc/davfs2/secrets
echo "Press any key to continue"
read

echo "#####################"
echo "# Montage du WebDAV #"
echo "#####################"

sudo /sbin/mount.davfs ${OD4B} /home/$USER/Storj/dataDrive

echo "Press any key to continue"
read

sudo chown $USER:$USER /home/$USER/Storj/dataDrive
HOSTNAME=`cat /proc/sys/kernel/hostname`
if [ ! -d "/home/$USER/Storj/dataDrive/$HOSTNAME" ]; then
  echo "Création du dossier /home/$USER/Storj/dataDrive/$HOSTNAME";
  mkdir /home/$USER/Storj/dataDrive/$HOSTNAME
fi
sudo chown $USER:$USER /home/$USER/Storj/dataDrive/$HOSTNAME
sudo chmod g+w /home/$USER/Storj/dataDrive/$HOSTNAME
for ((i=1 ; $i <= $nbStorjNodes ; i++))
do
  if [ ! -d "/home/$USER/Storj/dataDrive/$HOSTNAME/data$i" ]; then
    echo "Création du dossier /home/$USER/Storj/dataDrive/$HOSTNAME/data$i";
    mkdir /home/$USER/Storj/dataDrive/$HOSTNAME/data$i
  fi
done

echo "#########################"
echo "# Installation de Storj #"
echo "#########################"

STORJALREADYEXIST=`which storjshare | wc -l`
if [[ $STORJALREADYEXIST -lt 1 ]]
then
  wget -qO- https://raw.githubusercontent.com/creationix/nvm/v0.33.0/install.sh | bash
  source ~/.nvm/nvm.sh
  nvm install --lts
  sudo apt install git python build-essential
  npm install --global storjshare-daemon
  storjshare --help
else
  echo "Storj is already installed"
fi

echo "###############################################"
echo "# Création du programme de lancement de Storj #"
echo "###############################################"

if [ ! -d "Storj/app" ]; then
  echo "Création du dossier mkdir Storj/app";
  mkdir Storj/app
fi
cd Storj/app
echo "#!/bin/bash

echo \"----- Set parameters -----\"
OD4B=\"${OD4B}\"
oneDriveUsername=\"${oneDriveUsername}\"
oneDrivePassword=\"${oneDrivePassword}\"

echo \"----- NVM Load -----\"
export NVM_DIR=\"/home/\$USER/.nvm\"
[ -s \"$NVM_DIR/nvm.sh\" ] && . \"$NVM_DIR/nvm.sh\" # This loads nvm

echo \"----- Start Daemon -----\"
storjshare daemon
echo \"----- Done -----\"
if grep -qs 'dataDrive/' /proc/mounts; then
    echo \"Already mounted.\"
else
    echo \"----- Create cookie -----\"
    echo \"Replace the current davfs with the backup file\"
    sudo rm /etc/davfs2/davfs2.conf
    sudo cp /etc/davfs2/davfs2.conf.bak /etc/davfs2/davfs2.conf
    sudo chmod 777 /etc/davfs2/davfs2.conf
    cd /home/$USER/Storj/app/
    wget https://raw.githubusercontent.com/yulahuyed/test/master/get-sharepoint-auth-cookie.py
    echo \"python get-sharepoint-auth-cookie.py ${OD4B} ${oneDriveUsername} ${oneDrivePassword} > cookie.txt\"
    python get-sharepoint-auth-cookie.py ${OD4B} ${oneDriveUsername} ${oneDrivePassword} > cookie.txt
    sed -i \"s/ //g\" cookie.txt
    cat cookie.txt

    COOKIE=$(cat cookie.txt)
    DAVFS_CONFIG=$(grep -i \"use_locks 0\" /etc/davfs2/davfs2.conf)
    if [ \"${DAVFS_CONFIG}\" == \"use_locks 0\" ]
    then
      echo \"continue...\"
    else
      echo \"use_locks 0\" >> /etc/davfs2/davfs2.conf
      echo \"[/home/$USER/Storj/dataDrive]\" >> /etc/davfs2/davfs2.conf
      echo \"add_header Cookie ${COOKIE}\" >> /etc/davfs2/davfs2.conf
    fi
    rm cookie.txt get-sharepoint-auth-cookie.py

    echo \"----- Montage WebDAV -----\"
    sudo mount /home/\$USER/Storj/dataDrive/
    find /home/\$USER/Storj/dataDrive/ 2>/dev/null | grep -v \"lost\" | xargs -i sudo chown -R \$USER:\$USER {} 2>/dev/null
    echo \"----- Done -----\"
fi
sleep 5
echo \"----- Start Storj -----\"
cd /home/\$USER/.config/storjshare/configs/
for nodes in *
do
   storjshare start --config /home/\$USER/.config/storjshare/configs/\$nodes
done
cd /home/\$USER/Storj/app/StorjMonitor/
screen -dmS StorjMonitor ./storjMonitor.sh
echo \"----- Done -----\"
" > /home/$USER/Storj/app/start-storj.sh
sudo chmod +x start-storj.sh
echo "Done"

echo "######################"
echo "# Création des nodes #"
echo "######################"

for ((i=1 ; $i <= $nbStorjNodes ; i++))
do
  echo -n "Which network port do you want to use for the node $i ? [ENTER]: "
  read storjPort
  storjshare create --storj=$ethWallet --storage=/home/$USER/Storj/dataDrive/$HOSTNAME/data$i/ --size $storjNodeSize --rpcaddress $storjNodeIP --rpcport $storjPort --manualforwarding true --noedit  
done

cd /home/$USER/Storj/app

echo "#############################"
echo "# Installation de Storj Mon #"
echo "#############################"

if [ ! -d "/home/$USER/Storj/app/StorjMonitor" ];
then
  git clone https://github.com/calxibe/StorjMonitor.git
  cd StorjMonitor/
  sudo chmod +x storjMonitor-install.sh
  sed -i -e "s/YOUR-TOKEN-HERE/\$storjStatToken/g" /tmp/file.txt
  cd ..
else
  echo "Storj Monitor is already installed"
fi

echo "######################"
echo "# Lancement de Storj #"
echo "######################"

bash start-storj.sh
storjshare status