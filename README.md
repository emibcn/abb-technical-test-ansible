# Assigment

## 1. Automated provisioning
> Create a script (Ansible/Chef/Puppet, whenever you prefer), which executed on freshly installed Ubuntu, will provision a software stack, including installing minimal graphical 
> environment (e.g. XFCE/LXDE, etc), Chromium browser, Docker, performs git pull on configurable URL (simulate it with the given docker-compose files upload them to your GitHub)
> and provided credentials and finally run the script from task 2. Upload the playbook/script in GitHub.

Result: https://github.com/emibcn/abb-technical-test-ansible

I've choosen Ansible:
- I've installed Ansible inside a container using `docker-compose`. This will be executed in my PC (not the Ubuntu server in the VM).
- To run the script, the command will look like `docker-compose run ansible ansible-playbook main.yml` (I can add `ansible-playbook` command to the `Dockerfile` `CMD` or `entrypoint` to ease its execution).
- The server IP is declared in the [`hosts`](./ansible/hosts) file (`192.168.56.102` in my environment).
- The Ansible configuration files are bind-mounted inside the container. This way, the changes I do during development are instantly available into the container.
- The test script repository and file name are configurable via Ansible vars `repo_test_script` and `test_script`, respectively (with working defaults):
```
ansible-playbook -e repo_test_script="https://github.com/emibcn/abb-technical-test-script.git" -e test_script="test-script.sh" main.yml
```
- The Grafana stack `dcoker-compose` environment repository is configurable via Ansible vars (with working defaults):
```
ansible-playbook -e repo_grafana_dockercompose="https://github.com/emibcn/abb-technical-test-grafana.git" main.yml
```
- There are other variables with working defaults that can be changed.

## 2. Scripting
> Create a script with bash which get the public ip (or land ip) resolve the hostname and
> show some message when you have not connectivity with your router.

I created a script which accepts an optional parameter `--human`:
- If not present (default), prints its output in a format accepted by Telegraf/InfluxDB
- If present, prints the output as human readable

The script can be found at https://github.com/emibcn/abb-technical-test-script.git

## 3. Web app optimization
> Start a docker stack (swarm or docker-compose) with Grafana, and some
> backend like influx and show the status of script of the step 2. (if you have problems with the step 2
> script only explain how you going to do and who you deploy de stack)

I've created a Grafana/InfluxDB/Telegraf stack:
- The credentials (Grafana and InfluxDB) are auto-generated if not present previously. They are stored in the ansible directory `credentials/` (it is needed to access the Grafana web service). They are saved as plaintext, though some encryption would be desirable in a production environment. I did it this way because the corporation would probably already have some credentials manager to share them across the team members.
- The Telegraf service gathers the info from the above script by getting the contents of a file bind-mounted inside it's container. This way, the script runs in the host (with all its environment) and the results are available from the container.
- The Telegraf service saves the gathered info into the InfluxDB service, using read/write credentials (admin)
- The InfluxDB service is at it's 1.8 version, because the version 2 lacks autoconfiguration of credentials in its docker image (and is still compatible with both Grafana and Telegraf).
- The Grafana service has it's provisioning files to:
  - Declare the InfluxDB service
  - Define the home Dahsboard, with a chart showing the time to ping the router, the current status (`OK` or `ERROR` when router could not be determined or reached) and a 10 lines long log of statuses
  - The admin credentials are stored into the host running Ansible, in the `./credentials/grafana.server1` file (plaintext; configurable via `vars`)

The script above is added to the server `cron` (using Ansible) to execute it every minute and save its output into a file which will be bind-mounted into the Telegraf container.

This stack can be found at: https://github.com/emibcn/abb-technical-test-grafana

## 4. Networking
> Explain how you try to inspect the error in the next case:
> We have a remote user who has an edge machine connected on a VPN with network (192.168.2.0/23)
> using 4G connection with public ip 89.32.42.4. And another interface connected to the factory net-
> work 10.2.3.0/32 . They added one robot and one database sink. The robot is on the factory network
> and the database and the monitoring tool is running on a docker stack the. The user says that he
> added the ip and the database hostname, but the monitoring tool is not storing any data. You have
> access to the VPN and the edge has the port 22 open and you know the user (username: support)
> and password to access

### 1. how you connect to the edge
- Through the VPN network

#### a. what ip range
The VPN network is `192.168.2.0/23`, which has IPs in the range `192.168.2.1` to `192.168.3.254` (510 IPs)

#### b. what protocol you should use to connect
Using SSH protocol, as the user has open the TCP port 22, the default for the SSH service

#### c. write the linux command or the connection string for this protocol
As I don't know (yet) the user's IP, I'll ask to the user what IP does he has in the VPN, or look into the VPN logs/state files and determine it from there.
In the following command, I'll take the IP 192.168.2.100 as an example of what I'd deduced from the previous step (user telling the VPN IP or from the logs/state files).
I know the user (`support`) and its password in his PC. I'd need to be connected to the same VPN to be able to connect to his PC:

```
ssh support@192.168.2.100
```

Once connected, I'll probably need to become root, probably using `sudo`.

### 2. Write 3 different things you should check

> The robot is on the factory network and the database and the monitoring tool is running on a docker stack the.

From here, I can't certainly know where the Docker stack is running. I'll assume it is in the user's PC, as no other PC has been specified.

> The user says that he added the ip and the database hostname

I'll assume he added the **Robot IP** and the **database hostname** to the monitoring tool.

a. Check if the database is running without errors:
   - Check if it has write access to its storage files, probably a docker volume (or a PC directory) mounted into the storage files path.
   - Check if the storage path is in a filesystem with enough free space.
   - If applicable, check if the database has a correct token (for propietary software)

b. Check if the monitoring tool has access to the database:
   - Check wether the monitoring tool has access to the database and, if needed, has correct credentials. I'd check both the monitoring tool' logs and the database logs. Where to find them depends on how it is configured (plain `docker` or using `docker-compose`). In either case, logs may be available through `docker logs`, saved into files or sent to an external logging mechanism like an ELK stack, a `syslogd` server, etc.

c. Check if both the PC and the monitoring tool have access to the factory network and the Robot IP:
   - Check the PC firewall and routing tables
   - Ping the robot IP and some other IP in the factory network from the user PC
   - Ping the robot from inside the monitoring container
   - Check if the robot has the ports used by the monitoring tool open: SNMP, SSH, HTTP/s, custom/propietary. If the monitoring tool is a known one, I'd check there which port and protocol are used to monitor the robot. If it's not, I'd need to sniff the network from the PC looking for connections to the Robot IP with tools like `iptables`, `tcpspy`, `tcpdump`, `netstat`, etc, or look into the monitoring tool' or the robot documentations.

### 3. Write 5 different error that should happened

a. There is some problem in the physical stack:
   - Some cable not connected/broken
   - A disk full
   - The robot is shutdown

b. Some problem in the network configuration:
   - IPs, netmasks or routes
   - Firewall blocking IPs or ports

c. A misconfiguration in the docker stack:
   - The docker service itself may have problems (not up, disk full, file permissions, ...)
   - Containers not correctly linked
   - Database credentials
   - Some versioning problems (for example, the monitoring tool may need a different database version)
   - If the monitoring tool or the database are propietary, they might need some token to unlock its usage
   
d. A misconfiguration in the monitoring tool:
   - Wrong robot IP
   - Wrong robot service and/or port
   - Wrong credentilas for connecting to the robot
   
e. A misconfiguration in the robot:
   - Wrong network configuration
   - Monitoring service disabled
   - Network unauthorized (auth by network, firewall)
   - Monitoring tool unauthorized (auth by user)
