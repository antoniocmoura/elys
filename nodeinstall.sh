#!/bin/bash
source <(curl -s https://raw.githubusercontent.com/itrocket-team/testnet_guides/main/utils/common.sh)

printLogo

read -p "Enter WALLET name:" WALLET
echo 'export WALLET='$WALLET
read -p "Enter your MONIKER :" MONIKER
echo 'export MONIKER='$MONIKER
read -p "Enter your PORT (for example 17, default port=26):" PORT
echo 'export PORT='$PORT

# set vars
echo "export WALLET="$WALLET"" >> $HOME/.bash_profile
echo "export MONIKER="$MONIKER"" >> $HOME/.bash_profile
echo "export ELYS_CHAIN_ID="elystestnet-1"" >> $HOME/.bash_profile
echo "export ELYS_PORT="$PORT"" >> $HOME/.bash_profile
source $HOME/.bash_profile

printLine
echo -e "Moniker:        \e[1m\e[32m$MONIKER\e[0m"
echo -e "Wallet:         \e[1m\e[32m$WALLET\e[0m"
echo -e "Chain id:       \e[1m\e[32m$ELYS_CHAIN_ID\e[0m"
echo -e "Node custom port:  \e[1m\e[32m$ELYS_PORT\e[0m"
printLine
sleep 1

printGreen "1. Installing go..." && sleep 1
# install go, if needed
cd $HOME
VER="1.21.4"
wget "https://golang.org/dl/go$VER.linux-amd64.tar.gz"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "go$VER.linux-amd64.tar.gz"
rm "go$VER.linux-amd64.tar.gz"
[ ! -f ~/.bash_profile ] && touch ~/.bash_profile
echo "export PATH=$PATH:/usr/local/go/bin:~/go/bin" >> ~/.bash_profile
source $HOME/.bash_profile
[ ! -d ~/go/bin ] && mkdir -p ~/go/bin

echo $(go version) && sleep 1

source <(curl -s https://raw.githubusercontent.com/itrocket-team/testnet_guides/main/utils/dependencies_install)

printGreen "4. Installing binary..." && sleep 1
# download binary
cd $HOME
rm -rf elys
git clone https://github.com/elys-network/elys.git
cd elys
git fetch
git checkout v0.29.31
make install

printGreen "5. Configuring and init app..." && sleep 1
# config and init app
elysd config node tcp://localhost:${ELYS_PORT}657
elysd config keyring-backend os
elysd config chain-id elystestnet-1
elysd init "$MONIKER" --chain-id elystestnet-1
sleep 1
echo done

printGreen "6. Downloading genesis and addrbook..." && sleep 1
# download genesis and addrbook
wget -O $HOME/.elys/config/genesis.json https://testnet-files.itrocket.net/elys/genesis.json
wget -O $HOME/.elys/config/addrbook.json https://testnet-files.itrocket.net/elys/addrbook.json
sleep 1
echo done

printGreen "7. Adding seeds, peers, configuring custom ports, pruning, minimum gas price..." && sleep 1
# set seeds and peers
SEEDS="ae7191b2b922c6a59456588c3a262df518b0d130@elys-testnet-seed.itrocket.net:54656"
PEERS="0977dd5475e303c99b66eaacab53c8cc28e49b05@elys-testnet-peer.itrocket.net:38656"
sed -i -e "s/^seeds *=.*/seeds = \"$SEEDS\"/; s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $HOME/.elys/config/config.toml

# set custom ports in app.toml
sed -i.bak -e "s%:1317%:${ELYS_PORT}317%g;
s%:8080%:${ELYS_PORT}080%g;
s%:9090%:${ELYS_PORT}090%g;
s%:9091%:${ELYS_PORT}091%g;
s%:8545%:${ELYS_PORT}545%g;
s%:8546%:${ELYS_PORT}546%g;
s%:6065%:${ELYS_PORT}065%g" $HOME/.elys/config/app.toml


# set custom ports in config.toml file
sed -i.bak -e "s%:26658%:${ELYS_PORT}658%g;
s%:26657%:${ELYS_PORT}657%g;
s%:6060%:${ELYS_PORT}060%g;
s%:26656%:${ELYS_PORT}656%g;
s%^external_address = \"\"%external_address = \"$(wget -qO- eth0.me):${ELYS_PORT}656\"%;
s%:26660%:${ELYS_PORT}660%g" $HOME/.elys/config/config.toml

# config pruning
sed -i -e "s/^pruning *=.*/pruning = \"custom\"/" $HOME/.elys/config/app.toml
sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"100\"/" $HOME/.elys/config/app.toml
sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"50\"/" $HOME/.elys/config/app.toml

# set minimum gas price, enable prometheus and disable indexing
sed -i 's|minimum-gas-prices =.*|minimum-gas-prices = "0.0018ibc/2180E84E20F5679FCC760D8C165B60F42065DEF7F46A72B447CFF1B7DC6C0A65,0.00025ibc/E2D2F6ADCC68AA3384B2F5DFACCA437923D137C14E86FB8A10207CF3BED0C8D4,0.00025uelys"|g' $HOME/.elys/config/app.toml
sed -i -e "s/prometheus = false/prometheus = true/" $HOME/.elys/config/config.toml
sed -i -e "s/^indexer *=.*/indexer = \"null\"/" $HOME/.elys/config/config.toml
sleep 1
echo done

# create service file
sudo tee /etc/systemd/system/elysd.service > /dev/null <<EOF
[Unit]
Description=elys node
After=network-online.target
[Service]
User=$USER
WorkingDirectory=$HOME/.elys
ExecStart=$(which elysd) start --minimum-gas-prices="0.0018ibc/2180E84E20F5679FCC760D8C165B60F42065DEF7F46A72B447CFF1B7DC6C0A65,0.00025ibc/E2D2F6ADCC68AA3384B2F5DFACCA437923D137C14E86FB8A10207CF3BED0C8D4,0.00025uelys" --home $HOME/.elys
Restart=on-failure
RestartSec=5
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF

printGreen "8. Downloading snapshot and starting node..." && sleep 1
# reset and download snapshot
elysd tendermint unsafe-reset-all --home $HOME/.elys
if curl -s --head curl https://testnet-files.itrocket.net/elys/snap_elys.tar.lz4 | head -n 1 | grep "200" > /dev/null; then
  curl https://testnet-files.itrocket.net/elys/snap_elys.tar.lz4 | lz4 -dc - | tar -xf - -C $HOME/.elys
    else
  echo no have snap
fi

# enable and start service
sudo systemctl daemon-reload
sudo systemctl enable elysd
sudo systemctl restart elysd && sudo journalctl -u elysd -f
