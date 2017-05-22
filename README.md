# rpi3-pilight-fauxmo-homebdrige

A guide for setting up a Raspberry Pi 3 as a bridge to control 433 MHz radio controlled power plugs via Amazon Echo (Alexa) and iOS Home app (HomeKit).

Some of this guide is taken from other guides, which are listed at the end of this file. Credit goes to them!

## Hardware

- Raspberry Pi 3
- 433 MHz transceivers
  - I got [these](https://www.amazon.de/gp/product/B00R2U8OEU/)
- Female-female jumper wires for connecting the transceivers to the RPi.
- 433 MHz remote controlled power plugs
  - I got [these](http://www.pollin.de/shop/dt/MjAzOTQ0OTk-/Gebraucht_und_geprueft/Haustechnik/Installation/Funksteckdosen_dimmer_Set_GT_7008.html). They are learning, which means each plug can be programmed to each button of the remote.
  - There's also plugs where the ID can be manually set with dip switches.

### Wiring

Connect the like shown [here](https://raspberry.tips/hausautomatisierung/raspberry-pi-steuern-von-funksteckdosen-und-sensoren-mit-pilight/#Sensorennbspmit_dem_Raspberry_Pi_verbinden).

## Software

Raspian Jessie Lite is used. Installation is not covered here. I assume you have terminal access either via monitor/keyboard or via SSH.

### Install pilight from the development branch

        pi@rpi:~ $ sudo apt-get install git-core
        pi@rpi:~ $ sudo apt-get install --no-install-recommends cmake dialog libpcap-dev libunwind-dev
        pi@rpi:~ $ git clone --depth 1 -b development https://github.com/pilight/pilight.git
        pi@rpi:~ $ cd pilight
        pi@rpi:~ $ chmod +x setup.sh
        pi@rpi:~ $ sudo ./setup.sh

Click `Save and Install`.

        pi@rpi:~ $ sudo ldconfig
        pi@rpi:~ $ sudo systemctl enable pilight

Edit `/etc/pilight/config.json` and delete the line that says `webserver-https-port`. Now the daemon can be started:

        pi@rpi:~ $ sudo systemctl start pilight

Afterwards it is possible to check what code is sent by the remote for the power plugs. Do so by executing `pilight-receive`

        pi@rpi:~ $ pilight-receive

You should see something like the following when pressing a remote button:

        pi@rpi:~ $ pilight-receive
        {
                "origin": "sender",
                "protocol": "quigg_gt7000",
                "code": {
                        "id": 0,
                        "unit": 0,
                        "state": on
                },
                "repeat": 1,
        }

The important parts are protocol, id and unit. You can test your 433 MHz transmitter with the following command, which should switch the plug:

        pi@rpi:~ $ pilight-send -p quigg_gt7000 -i 0 -u 0 -t
	
Optional: Adding `-l` as an argument can be used to program the plug via pilight. This is handy if your remote is out of batteries ;)

	pi@rpi:~ $ pilight-send -p quigg_gt7000 -i 0 -u 0 -t -l

If this was successful, it can be included into pilight's `config.json`.
IMPORTANT: Always stop the pilight daemon before editing the config!

        pi@rpi:~ $ sudo systemctl stop pilight
        pi@rpi:~ $ sudo emacs /etc/pilight/config.json

The device is added to the device section, and referenced in the gui section:

        "devices": {
                "CouchLight": {
                        "protocol": [ "quigg_gt7000" ],
                        "id": [{
                                "id": 0,
                                "unit": 0
                        }],
                        "state": "off"
                }
        }
        "gui": {
		"CouchLight": {
			"name": "Couch Light",
			"group": [ "LivingRoom" ],
			"media": [ "all" ]
        	},
        }

Save the config and restart pilight:

        pi@rpi:~ $ sudo systemctl start pilight

You should now see the switch in pilight's webgui. You can browse to it by going to:

        http://IP_OF_RPI:5001

### Fauxmo

In order to control pilight devices with an Amazon Echo, the fauxmo.py script from [makermusings](https://github.com/makermusings/fauxmo) is used. Download and edit it:

        pi@rpi:~ $ sudo apt-get install --no-install-recommends python-requests
        pi@rpi:~ $ wget https://raw.githubusercontent.com/makermusings/fauxmo/master/fauxmo.py
        pi@rpi:~ $ chmod +x fauxmo.py
        pi@rpi:~ $ emacs fauxmo.py

Got to the end of the script and edit the `FAUXMOS` array. It will be used to control pilight via its REST API.

        FAUXMOS = [
                ['Couch', rest_api_handler('http://localhost:5001/control?device=CouchLight&state=on',
                                 'http://localhost:5001/control?device=CouchLight&state=off')],
        ]

Create a fauxmo user and systemd unit file to autostart the script.

        pi@rpi:~ $ sudo useradd -M --system --shell /bin/false fauxmo
        pi@rpi:~ $ sudo emacs /etc/systemd/system/fauxmo.service

Copy this into the editor:

        [Unit]
        Description=Wemo Powerplug Switch Emulator
        Wants=network-online.target
        After=syslog.target network.target network-online.target

        [Service]
        Type=idle
        User=fauxmo
        ExecStart=/home/pi/fauxmo.py
        Restart=on-failure

        [Install]
        WantedBy=multi-user.target

Register it with systemd and make it autostart on boot:

        pi@rpi:~ $ sudo systemctl daemon-reload
        pi@rpi:~ $ sudo systemctl enable fauxmo
        pi@rpi:~ $ sudo systemctl start fauxmo

In the Alexa App, go to smart home, and search for new devices. Afterwards, you should be able to voice control them.

## Homebridge

	wget https://nodejs.org/dist/v6.10.0/node-v6.10.0-linux-armv7l.tar.xz
	tar -xvf node-v6.10.0-linux-armv7l.tar.xz
	cd node-v6.10.0-linux-armv7l/
	sudo cp -R  bin/ include/ lib/ share/ /usr/local/
	sudo apt-get install libavahi-compat-libdnssd-dev
	sudo npm install -g --unsafe-perm homebridge
	sudo npm install -g homebridge-pilight
	sudo mkdir /var/lib/homebridge
	
Create `/var/lib/homebridge/config.json`, and add your pilight devices:

	{
	  "bridge": {
	    "name": "Homebridge",
	    "username": "CC:22:3D:E3:CE:30",
	    "port": 51826,
	    "pin": "031-45-154"
	  },
	  "description": "This is an example configuration file with pilight plugin.",
	  "accessories": [
	    {
	      "accessory": "pilight",
	      "name": "Couch Light",
	      "device": "CouchLight",
	      "sharedWS": false,
	      "type": "Switch"
	    }
	  ],
	  "platforms": [
	  ]
	}
	
Continue with

	sudo chown -R homebridge:homebridge /var/lib/homebridge/

Create `/etc/default/homebridge` and save:

	# Defaults / Configuration options for homebridge
	# The following settings tells homebridge where to find the config.json file and where to persist the data (i.e. pairing and others)
	HOMEBRIDGE_OPTS=-U /var/lib/homebridge
	# If you uncomment the following line, homebridge will log more 
	# You can display this via systemd's journalctl: journalctl -f -u homebridge
	# DEBUG=*
	
Create `etc/systemd/system/homebridge.service` and save:

	[Unit]
	Description=Node.js HomeKit Server
	Wants=network-online.target
        After=syslog.target network.target network-online.target

	[Service]
	Type=simple
	User=homebridge
	EnvironmentFile=/etc/default/homebridge
	ExecStart=/usr/local/bin/homebridge $HOMEBRIDGE_OPTS
	Restart=on-failure
	RestartSec=10
	KillMode=process

	[Install]
	WantedBy=multi-user.target
	
Finally, do:

	sudo systemctl daemon-reload
	sudo systemctl enable homebridge
	sudo systemctl start homebridge

## Credits / Resources

 - https://raspberry.tips/hausautomatisierung/raspberry-pi-steuern-von-funksteckdosen-und-sensoren-mit-pilight/#Sensorennbspmit_dem_Raspberry_Pi_verbinden
 - https://www.pilight.org/get-started/installation/#stable_git
 - https://gist.github.com/johannrichard/0ad0de1feb6adb9eb61a/
