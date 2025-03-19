# ntp-monitor

Very basic NTP monitoring using RRDTOOL and NTPDATE (ntpdig).

Unable to use a "larger" monitoring solution (Zabbix, Munin, Graphana, etc), I had to resort to the basics.

## Usage

General syntax is as follows:

```
ntp-monitor.sh [track|graph] <ip-address> [ip-address] [...]
```

It uses two modes:

1. **track**, used to query and monitor an NTP server and

2. **graph**, used to create an image from measured values (as stored in the corresponding RRD-file).


```
ntp-monitor.sh track <ip-address> [ip-address] [...]
```

This will query all the IP-addresses and write the received values to seperate RRD files. Be advised to run the script periodically, preferably each minute. Be aware that monitoring many NTP-servers will still be hogging the CPU, I would recommend to monitor no more than 5 NTP servers (depending on CPU and bandwidth).

```
ntp-monitor.sh graph <ip-address> [ip-address] [...]
```

This will create a PNG image from the RRD file related to that IP-address.

## How to monitor NTP servers

I recommend monitoring NTP servers as close as possible to where you expect the largest clock drifts to occur *AND* as close as possible to a nearest well behaving NTP server. This makes it possible to compare graphs. Please be aware that monitoring will be done **based on comparison to the internal clock of the system on which you run ntp-monitor**.

Let's assume your home router is acting as an NTP server and has ip-adress 192.168.1.1, and you're not convinced that it is serving time as it should. The following crontab (`man 5 crontab`) will create seperate RRD files of offset and jitter of a known reference, 213.75.85.245, and your internal NTP server. Place the system that is monitoring the router next to the router, preferably on a direct link, so no other network component can mess up anything.

```
crontab -e
* * * * * ntp-monitor.sh track 213.75.85.245 192.168.1.1 2>&1 | logger -t NTP-MONITOR
```

To make PNG files, run the following:

```
ntp-monitor.sh graph 213.75.85.245 192.168.1.1
```
