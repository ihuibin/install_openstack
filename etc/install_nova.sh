#！/bin/bash
#log function
NAMEHOST=$HOSTNAME
if [  -e $PWD/lib/liberty-log.sh ]
then	
	source $PWD/lib/liberty-log.sh
else
	echo -e "\033[41;37m $PWD/liberty-log.sh is not exist. \033[0m"
	exit 1
fi
#input variable
if [  -e $PWD/lib/installrc ]
then	
	source $PWD/lib/installrc 
else
	echo -e "\033[41;37m $PWD/lib/installr is not exist. \033[0m"
	exit 1
fi
if [  -e /etc/openstack-liberty_tag/computer.tag  ]
then
	echo -e "\033[41;37m Oh no ! you can't execute this script on computer node.  \033[0m"
	log_error "Oh no ! you can't execute this script on computer node. "
	exit 1 
fi

if [ -f  /etc/openstack-liberty_tag/install_glance.tag ]
then 
	log_info "glance have installed ."
else
	echo -e "\033[41;37m you should install glance first. \033[0m"
	exit
fi


if [ -f  /etc/openstack-liberty_tag/install_nova.tag ]
then 
	echo -e "\033[41;37m you haved install nova \033[0m"
	log_info "you haved install nova."	
	exit
fi
unset http_proxy https_proxy ftp_proxy no_proxy 
#create nova databases 
function  fn_create_nova_database () {
mysql -uroot -p${ALL_PASSWORD} -e "CREATE DATABASE nova;" &&  mysql -uroot -p${ALL_PASSWORD} -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '${ALL_PASSWORD}';" && mysql -uroot -p${ALL_PASSWORD} -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY '${ALL_PASSWORD}';" 
fn_log "create nova databases"
}
mysql -uroot -p${ALL_PASSWORD} -e "show databases ;" >test 
DATABASENOVA=`cat test | grep nova`
rm -rf test 
if [ ${DATABASENOVA}x = novax ]
then
	log_info "nova database had installed."
else
	fn_create_nova_database
fi


source /root/admin-openrc.sh 
USER_NOVA=`openstack user list | grep nova | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [ ${USER_NOVA}x = novax ]
then
	log_info "openstack user had created  nova"
else
	openstack user create  nova  --password ${ALL_PASSWORD}
	fn_log "openstack user create  nova  --password ${ALL_PASSWORD}"
	openstack role add --project service --user nova admin
	fn_log "openstack role add --project service --user nova admin"
fi



SERVICE_NOVA=`openstack service list | grep nova | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [  ${SERVICE_NOVA}x = novax ]
then 
	log_info "openstack service create nova."
else
	openstack service create --name nova --description "OpenStack Compute" compute
	fn_log "openstack service create --name nova --description "OpenStack Compute" compute"
fi


ENDPOINT_LIST_INTERNAL=`openstack endpoint list  | grep compute  |grep internal | wc -l`
ENDPOINT_LIST_PUBLIC=`openstack endpoint list | grep compute   |grep public | wc -l`
ENDPOINT_LIST_ADMIN=`openstack endpoint list | grep compute   |grep admin | wc -l`
if [  ${ENDPOINT_LIST_INTERNAL}  -eq 1  ]  && [ ${ENDPOINT_LIST_PUBLIC}  -eq  1   ] &&  [ ${ENDPOINT_LIST_ADMIN} -eq 1  ]
then
	log_info "openstack endpoint create nova."
else
	openstack endpoint create --region RegionOne   compute public http://${HOSTNAME}:8774/v2/%\(tenant_id\)s  &&  openstack endpoint create --region RegionOne   compute internal http://${HOSTNAME}:8774/v2/%\(tenant_id\)s  && openstack endpoint create --region RegionOne   compute admin http://${HOSTNAME}:8774/v2/%\(tenant_id\)s
	fn_log "openstack endpoint create --region RegionOne   compute public http://${NAMEHOST}:8774/v2/%\(tenant_id\)s  &&  openstack endpoint create --region RegionOne   compute internal http://${NAMEHOST}:8774/v2/%\(tenant_id\)s  && openstack endpoint create --region RegionOne   compute admin http://${NAMEHOST}:8774/v2/%\(tenant_id\)s"
fi
#test network
function fn_test_network () {
if [ -f $PWD/lib/proxy.sh ]
then 
	source  $PWD/lib/proxy.sh
fi
curl www.baidu.com >/dev/null   
fn_log "curl www.baidu.com >/dev/null"
}



if  [ -f /etc/yum.repos.d/repo.repo ]
then
	log_info " use local yum."
else 
	fn_test_network
fi

yum clean all && yum install openstack-nova-api openstack-nova-cert   openstack-nova-conductor openstack-nova-console   openstack-nova-novncproxy openstack-nova-scheduler   python-novaclient -y
fn_log "yum clean all && yum install openstack-nova-api openstack-nova-cert openstack-nova-conductor openstack-nova-console openstack-nova-novncproxy openstack-nova-scheduler python-novaclient -y"
unset http_proxy https_proxy ftp_proxy no_proxy 
FIRST_ETH=`ip addr | grep ^2: |awk -F ":" '{print$2}'`
FIRST_ETH_IP=`ifconfig ${FIRST_ETH}  | grep netmask | awk -F " " '{print$2}'`
[ -f /etc/nova/nova.conf_bak ]  || cp -a /etc/nova/nova.conf /etc/nova/nova.conf_bak
openstack-config --set  /etc/nova/nova.conf database connection  mysql://nova:${ALL_PASSWORD}@${HOSTNAME}/nova && 
openstack-config --set  /etc/nova/nova.conf DEFAULT rpc_backend  rabbit &&  
openstack-config --set  /etc/nova/nova.conf oslo_messaging_rabbit rabbit_host  ${HOSTNAME}&& 
openstack-config --set  /etc/nova/nova.conf oslo_messaging_rabbit rabbit_userid  openstack   && 
openstack-config --set  /etc/nova/nova.conf oslo_messaging_rabbit rabbit_password  ${ALL_PASSWORD} && 
openstack-config --set  /etc/nova/nova.conf DEFAULT auth_strategy  keystone && 
openstack-config --set  /etc/nova/nova.conf keystone_authtoken auth_uri  http://${HOSTNAME}:5000 &&  \
openstack-config --set  /etc/nova/nova.conf keystone_authtoken auth_url  http://${HOSTNAME}:35357 &&   \
openstack-config --set  /etc/nova/nova.conf keystone_authtoken auth_plugin  password &&   \
openstack-config --set  /etc/nova/nova.conf keystone_authtoken project_domain_id  default &&   \
openstack-config --set  /etc/nova/nova.conf keystone_authtoken user_domain_id  default &&    \
openstack-config --set  /etc/nova/nova.conf keystone_authtoken project_name  service &&   \
openstack-config --set  /etc/nova/nova.conf keystone_authtoken username  nova &&   \
openstack-config --set  /etc/nova/nova.conf keystone_authtoken password  ${ALL_PASSWORD} &&   \
openstack-config --set  /etc/nova/nova.conf DEFAULT my_ip ${FIRST_ETH_IP} &&   \
openstack-config --set  /etc/nova/nova.conf DEFAULT verbose  True &&   \
openstack-config --set  /etc/nova/nova.conf DEFAULT network_api_class  nova.network.neutronv2.api.API &&   \
openstack-config --set  /etc/nova/nova.conf DEFAULT security_group_api  neutron &&   \
openstack-config --set  /etc/nova/nova.conf DEFAULT linuxnet_interface_driver  nova.network.linux_net.NeutronLinuxBridgeInterfaceDriver &&   \
openstack-config --set  /etc/nova/nova.conf DEFAULT firewall_driver  nova.virt.firewall.NoopFirewallDriver &&   \
openstack-config --set  /etc/nova/nova.conf vnc vncserver_listen  ${FIRST_ETH_IP}  &&   \
openstack-config --set  /etc/nova/nova.conf vnc vncserver_proxyclient_address  ${FIRST_ETH_IP} &&   \
openstack-config --set  /etc/nova/nova.conf vnc  novncproxy_base_url  http://${FIRST_ETH_IP}:6080/vnc_auto.html
openstack-config --set  /etc/nova/nova.conf glance host  $HOSTNAME &&   \
openstack-config --set  /etc/nova/nova.conf oslo_concurrency lock_path  /var/lib/nova/tmp &&   \
openstack-config --set  /etc/nova/nova.conf DEFAULT enabled_apis osapi_compute,metadata
fn_log "config /etc/nova/nova.conf "

su -s /bin/sh -c "nova-manage db sync" nova 
fn_log "su -s /bin/sh -c "nova-manage db sync" nova "

systemctl enable openstack-nova-api.service   openstack-nova-cert.service openstack-nova-consoleauth.service  openstack-nova-scheduler.service openstack-nova-conductor.service   openstack-nova-novncproxy.service && systemctl start openstack-nova-api.service   openstack-nova-cert.service openstack-nova-consoleauth.service  openstack-nova-scheduler.service openstack-nova-conductor.service   openstack-nova-novncproxy.service
fn_log "systemctl enable openstack-nova-api.service   openstack-nova-cert.service openstack-nova-consoleauth.service  openstack-nova-scheduler.service openstack-nova-conductor.service   openstack-nova-novncproxy.service && systemctl start openstack-nova-api.service   openstack-nova-cert.service openstack-nova-consoleauth.service  openstack-nova-scheduler.service openstack-nova-conductor.service   openstack-nova-novncproxy.service"
#test network
function fn_test_network () {
if [ -f $PWD/lib/proxy.sh ]
then 
	source  $PWD/lib/proxy.sh
fi
curl www.baidu.com >/dev/null   
fn_log "curl www.baidu.com >/dev/null"
}



if  [ -f /etc/yum.repos.d/repo.repo ]
then
	log_info " use local yum."
else 
	fn_test_network
fi

yum clean all && yum install openstack-nova-compute sysfsutils -y
fn_log "yum clean all && yum install openstack-nova-compute sysfsutils -y"

unset http_proxy https_proxy ftp_proxy no_proxy 
FIRST_ETH=`ip addr | grep ^2: |awk -F ":" '{print$2}'`
FIRST_ETH_IP=`ifconfig ${FIRST_ETH}  | grep netmask | awk -F " " '{print$2}'`




HARDWARE=`egrep -c '(vmx|svm)' /proc/cpuinfo`
if [ ${HARDWARE}  -eq 0 ]
then 
	openstack-config --set  /etc/nova/nova.conf libvirt virt_type  qemu 
	log_info  "openstack-config --set  /etc/nova/nova.conf libvirt virt_type  qemu sucessed."
else
	openstack-config --set  /etc/nova/nova.conf libvirt virt_type  kvm
	log_info  "openstack-config --set  /etc/nova/nova.conf libvirt virt_type  qemu sucessed."
fi

systemctl enable libvirtd.service openstack-nova-compute.service &&  systemctl start libvirtd.service openstack-nova-compute.service 
fn_log "systemctl enable libvirtd.service openstack-nova-compute.service &&  systemctl start libvirtd.service openstack-nova-compute.service "


source /root/admin-openrc.sh
nova service-list 
NOVA_STATUS=`nova service-list | awk -F "|" '{print$7}'  | grep -v State | grep -v ^$ | grep down`
if [  -z ${NOVA_STATUS} ]
then
	echo "nova status is ok"
	log_info  "nova status is ok"
	echo -e "\033[32m nova status is ok \033[0m"
else
	echo "nova status is down"
	log_error "nova status is down."
	exit
fi
nova endpoints

fn_log "nova endpoints"
nova image-list
fn_log "nova image-list"
NOVA_IMAGE_STATUS=` nova image-list  | grep cirros-0.3.4-x86_64  | awk -F "|"  '{print$4}'`
if [ ${NOVA_IMAGE_STATUS}  = ACTIVE ]
then
	log_info  "nova image status is ok"
	echo -e "\033[32m nova image status is ok \033[0m"
else
	echo "nova image status is error."
	log_error "nova image status is error."
	exit
fi




echo -e "\033[32m ################################################ \033[0m"
echo -e "\033[32m ###         Install Nova Sucessed           #### \033[0m"
echo -e "\033[32m ################################################ \033[0m"
if  [ ! -d /etc/openstack-liberty_tag ]
then 
	mkdir -p /etc/openstack-liberty_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-liberty_tag/install_nova.tag




