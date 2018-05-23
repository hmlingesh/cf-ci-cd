FILE="/usr/local/bin/bosh"
if [ ! -f $FILE ]; then

	wget https://s3.amazonaws.com/bosh-cli-artifacts/bosh-cli-3.0.1-linux-amd64
	chmod +x bosh-cli-*
	sudo mv bosh-cli-* /usr/local/bin/bosh
else
	  echo "File $FILE exists."
fi

bosh -v
VBoxManage --version
DIRECTORY="/~/workspace/bosh-deployment"
if [ -d "$DIRECTORY" ]; then
  git pull  
else	
git clone https://github.com/cloudfoundry/bosh-deployment ~/workspace/bosh-deployment
fi


mkdir -p ~/deployments/vbox
cd ~/deployments/vbox

bosh create-env ~/workspace/bosh-deployment/bosh.yml \
  --state ./state.json \
  -o ~/workspace/bosh-deployment/virtualbox/cpi.yml \
  -o ~/workspace/bosh-deployment/virtualbox/outbound-network.yml \
  -o ~/workspace/bosh-deployment/bosh-lite.yml \
  -o ~/workspace/bosh-deployment/bosh-lite-runc.yml \
  -o ~/workspace/bosh-deployment/jumpbox-user.yml \
  --vars-store ./creds.yml \
  -v director_name="bosh-lite" \
  -v internal_ip=192.168.50.6 \
  -v internal_gw=192.168.50.1 \
  -v internal_cidr=192.168.50.0/24 \
  -v outbound_network_name=NatNetwork

 bosh alias-env vbox -e 192.168.50.6 --ca-cert <(bosh int ./creds.yml --path /director_ssl/ca)
 export BOSH_CLIENT=admin
 export BOSH_CLIENT_SECRET=`bosh int ./creds.yml --path /admin_password`

 bosh -e vbox env

 sudo ip route add   10.244.0.0/16 via 192.168.50.6
 sudo route add -net 10.244.0.0/16 gw  192.168.50.6
 cd $DIRECTORY
 export BOSH_CLIENT=admin
 export BOSH_CLIENT_SECRET=`bosh int ./creds.yml --path /admin_password`

 cd ~/workspace 
 git clone https://github.com/cloudfoundry/cf-deployment
 cd cf-deployment


 bosh -e vbox update-cloud-config iaas-support/bosh-lite/cloud-config.yml

 bosh -e vbox upload-stemcell https://bosh.io/d/stemcells/bosh-warden-boshlite-ubuntu-trusty-go_agent

  
 bosh -e vbox -d cf deploy cf-deployment.yml \
  -o operations/bosh-lite.yml \
  --vars-store deployment-vars.yml \
  -v system_domain=bosh-lite.com

