#!/usr/bin/env bash
# Perform checks for yum on VMs using Microsoft Azure RHUI
#
VERSION="1.0.0"
SCRIPTNAME=`basename $0`
# Clean the environment
PATH="/sbin:/usr/sbin:/usr/local/sbin:/usr/local/bin:/bin:/usr/bin"
test -n "${TERM}" || TERM="raw"
LANG="POSIX"
export PATH TERM LANG

#######################################
# Header display to user
#######################################
function header() {
  # Need confirmation from user to run
  cecho -c 'yellow' "!!THIS SCRIPT SHOULD ONLY BE USED IF INSTANCE HAS YUM REPOSITORY ISSUES!!"
  read -p "Are you sure you want to continue? [y/n] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    cecho -c 'yellow' "Press [Y] or [y] next time to continue check"
	safe_exit
  fi
  cecho -c 'bold' "## YUM-REPOCHECK ##"
  cecho -c 'bold' "`date`"
}

#######################################
#Checking if the vm is using the current RHUI
#######################################
function current {
echo " "
cecho -c 'yellow' "Checking if using the current RHUI"
#check if /etc/yum.repos.d/rh-cloud.repo contains rhui-1-3. This would indicate it is using updated settings. 
grep "rhui-1.microsoft.com" /etc/yum.repos.d/rh-cloud.repo &> /dev/null 
#if the above doesn't find rhui-1, it returns a failure, thus it couldn't find it. Checking for all 3 servers. 
if [ $? -eq 0 ]; then
grep "rhui-2.microsoft.com" /etc/yum.repos.d/rh-cloud.repo &> /dev/null
  if [ $? -eq 0 ]; then
     grep "rhui-3.microsoft.com" /etc/yum.repos.d/rh-cloud.repo &> /dev/null
         if [ $? -eq 0 ]; then
cecho -c 'green' "Successful - /etc/yum.repos.d/rh-cloud.repo contains the 3 update servers."
   sleep 2
else
cecho -c 'red' "/etc/yum.repos.d/rh-cloud.repo is using outdated settings."
   cecho -c 'red' "https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/redhat/redhat-rhui#manual-update-procedure-to-use-the-azure-rhui-servers"
   safe_exit
   fi
fi
fi
}

#######################################
#Checking if the ssl cert dates are valid
# See https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/redhat/redhat-rhui#update-expired-rhui-client-certificate-on-a-vm
#######################################
function sslcert {
echo " " 
cecho -c 'yellow' "Checking if the ssl cert dates are valid"
#Assign the actual end date as a variable so it can be displayed later
enddate=`openssl x509 -in /etc/pki/rhui/product/content.crt -noout -text|grep -E 'Not After'`
#Check if the certificate expires in the next 60 seconds. If so, it's expired and needs refreshed. 
sudo openssl x509 -in /etc/pki/rhui/product/content.crt -noout -text -checkend 60 | grep "Certificate will expire" &> /dev/null
if [ $? -eq 0 ]; then
  cecho -c 'green' "Successful - The certificate is not expired"
  cecho -c 'green' Expiration date: $enddate
   sleep 2
else
cecho -c 'red' "The SSL cert has expired"
cecho -c 'red' Expiration date: $enddate
   cecho -c 'red' "See the following to update it: https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/redhat/redhat-rhui#manual-update-procedure-to-use-the-azure-rhui-servers"
   safe_exit
   fi

openssl x509 -in /etc/pki/rhui/product/content.crt -noout -text|grep -E 'Not Before|Not After'
read -p "Does today's date fall between the Not Before and Not After date? [y/n] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    cecho -c 'yellow' "Update the RHUI cert and try updates again"
    cecho -c 'blue' "See https://docs.microsoft.com/en-us/azure/virtual-machines/workloads/redhat/redhat-rhui#update-expired-rhui-client-certificate-on-a-vm"
        safe_exit
  fi
}

#######################################
#
# Checking for connectivity to rhui-1.microsoft.com over port 443 
#
#######################################
function connectivityrhui {
echo " " 
cecho -c 'yellow' "Checking for connectivity to https://rhui-1.microsoft.com over port 443" 
curl -v --connect-timeout 10 https://rhui-1.microsoft.com:443 &> /dev/null
if [ $? -eq 0 ]; then
   cecho -c 'green' "Successful - Server can connect to https://rhui-1.microsoft.com:443 "
   sleep 1
else
   echo -c 'red' "FAIL - Need to determine why the VM does not have access to the above address"
   echo -c 'red' "Potential reasons:"
   echo -c 'red' "- VM is behind a Standard Internal Load balancer. A Basic load balancer is required."
   echo -c 'red' "- A virtual network appliance could be blocking traffic. A UDR would be needed."
   echo -c 'red' "- If a proxy is being used, yum needs to be required to use this  /etc/yum.conf
proxy=http://<IP address>:<port number>"
   echo -c 'red' "- VM is behind a Standard Internal Load balancer"
        safe_exit
fi
}

#######################################
#
# Checking for connectivity to rhui-1.microsoft.com over port 443
#
#######################################
function checkdns {
echo " " 
cecho -c 'yellow' "Checking DNS Resolution to rhui-1.microsoft.com"
nslookup rhui-1.microsoft.com > /dev/null
if [ $? -eq 0 ]; then
   cecho -c 'green' "Successful - DNS is resolving rhui-1.microsoft.com as required"
   sleep 2
else
   cecho -c 'red' "FAIL - troubleshoot name resolution before continuing"
        safe_exit
fi
}


#######################################
# Check if smt servers are accessible over https
# Globals:
#   None
# Arguments:
#   None
#######################################
function check_https() {
  cecho -c 'bold' "-Checking https access"
  for i in "${smt_servers[@]}"; do
    local https_return_code=$(curl -k -m 5 -s -o /dev/null -w "%{http_code}" https://$i/api/health/status)
	if [ $https_return_code -ne "200" ]; then
	  cecho -c 'red' "PROBLEM: https access issue. Open port 443 to SMT servers:"
	  cecho -c 'red' "${smt_servers[*]}"
	  safe_exit
	else
      cecho -c 'green' "https access OK"
	  break
	fi
  done
}

#######################################
# functions to verify if package versions are less than equal
# Globals:
#   None
# Arguments:
#   None
#######################################
function verlte() {
  [  "${1}" = "`echo -e "${1}\n${2}" | sort -V | head -n1`" ]
}

#######################################
# functions to verify if package versions are less than
# Globals:
#   None
# Arguments:
#   None
#######################################
function verlt() {
  [ "${1}" = "${2}" ] && return 1 || verlte "${1}" "${2}"
}

#######################################
# Check that package versions are at minimum recommended
# Globals:
#   None
# Arguments:
#   None
#######################################
function check_regionclient_version() {
  cecho -c 'bold' "-Checking cloud-regionsrv-client version"
  local required_version="9.0.10"
  local installed_version="$(rpm -q cloud-regionsrv-client --queryformat "%{VERSION}")"
  if verlt $installed_version $required_version; then
	cecho -c 'red' "PROBLEM: Update infrastructure packages need to be updated manually"
	cecho -c 'red' "Follow Situation 4 at https://www.suse.com/support/kb/doc/?id=000019633"
	safe_exit
  else 
	cecho -c 'green' "cloud-regionsrv-client OK"
  fi
}

#######################################
# Metadata access is required. Check metadata is accessible
# Globals:
#   None
# Arguments:
#   None
#######################################
function check_metadata() {
  cecho -c 'bold' "-Checking metadata access"
  if [[ "${FRAMEWORK}" == "azure" ]]; then
    local company="microsoft"
    local check_region="$(timeout 5 azuremetadata --location 2>/dev/null | awk {'print $2'})"
  elif [[ "${FRAMEWORK}" == "ec2" ]]; then
    local company="amazon"
    local check_region="$(timeout 5 ec2metadata --availability-zone 2>/dev/null | rev | cut -c 2- | rev)"
  elif [[ "${FRAMEWORK}" == "gce" ]]; then
    local company="google"
    local check_region="$(timeout 5 gcemetadata --query instance --zone 2>/dev/null | cut -d/ -f4 | rev | cut -c 3- | rev)"
  fi

  if [[ -z "${check_region}" ]]; then
	  cecho -c 'red' "PROBLEM: Metadata is not accessible. Fix access to metadata at 169.254.169.254"
	  collect_debug_data
	  safe_exit
  else
    cecho -c 'green' "Metadata OK"
	local CMD="xml_grep --pretty_print --strict 'server[@region=\"$check_region\"]' | grep server | awk {'print \$2'} | cut -d '\"' -f2"
	# Get SMT servers that are in region
    local get_smt="$(echo ${!company} | eval $CMD)"
	IFS=" " read -a smt_servers <<< $get_smt
  fi
}

#######################################
# Check if current smt server in /etc/hosts is region correct
# Globals:
#   None
# Arguments:
#   None
#######################################
function check_current_smt() {
  cecho -c 'bold' "-Checking SMT server entry is correct in /etc/hosts"
  # Get current /etc/hosts
  local smt_ip="$(getent hosts smt-azure.susecloud.net | awk {'print $1'})"

  if [[ "${smt_servers[@]}" =~ "${smt_ip}" ]]; then
    cecho -c 'green' "SMT server entry OK"
  fi

  if [[ ! "${smt_servers[@]}" =~ "${smt_ip}" ]]; then
    cecho -c 'red' "PROBLEM: SMT server entry is for wrong region"
  fi
}  

#######################################
# Check if the instance has access to at least 1 region server over https
# Globals:
#   None
# Arguments:
#   None
#######################################
function check_region_servers() {
  local good_count=0
  local get_region_servers="$(cat /etc/regionserverclnt.cfg | grep regionsrv | awk {'print $3'})"
  IFS=', ' read -r -a region_servers <<< "$get_region_servers"
  cecho -c 'bold' "-Checking regionserver access"
  for i in "${region_servers[@]}"; do
    local https_return_code=$(curl -k -m 5 -s -o /dev/null -w "%{http_code}" https://$i/regionInfo)
	if [ $https_return_code -eq "200" ]; then
	  good_count=$((good_count+1))
	fi
  done

  if [ $good_count -eq 0 ]; then
	cecho -c 'red' "PROBLEM: No access to a region server. Open port 443 to a region server:"
	cecho -c 'red' "${region_servers[*]}"
	safe_exit
  else
    cecho -c 'green' "region server access OK"
  fi
}

#######################################
# Force the client to register to SMT again
# Globals:
#   None
# Arguments:
#   None
#######################################
function registercloudguestnow() {
  /usr/sbin/registercloudguest --force-new 
  cecho -c 'yellow' "Check repository access now."
}  
#######################################
# End of run report
# Globals:
#   None
# Arguments:
#   None
#######################################
function report() {
  if [ $COUNT -eq 0 ]; then
    cecho -c 'green' "EVERYTHING OK. Running registercloudguest"
	collect_debug_data

  else 
	cecho -c 'yellow' "There were problems fixed. Running registercloudguest"
	collect_debug_data
fi
}

#######################################
# Collection of debug data if healing fails
# Globals:
#   tmp_dir
# Arguments:
#   None
#######################################
function collect_debug_data() {
  cecho -c 'yellow' "Collecting debug data. Please wait..."
  local date=$(date +"%Y-%m-%d_%H-%M-%S")
  local var_location="/var/log/"
  tmp_dir="/tmp/${scriptName}.$RANDOM.$RANDOM.$RANDOM.$$"
  (umask 077 && mkdir "${tmp_dir}") || { 
  die "Could not create temporary directory! Exiting."
  }
  local data_provider="$(cat /etc/regionserverclnt.cfg | grep dataProvider | cut -d "=" -f2)" 
  if [[ "${FRAMEWORK}" == "azure" ]]; then
    /usr/bin/azuremetadata --api latest > $tmp_dir/azuremetadata.latest 2>&1
    /usr/bin/azuremetadata > $tmp_dir/azuremetadata.default 2>&1
  elif [[ "${FRAMEWORK}" == "ec2" ]]; then
    /usr/bin/ec2metadata --api latest > $tmp_dir/ec2metadata.latest 2>&1
    /usr/bin/ec2metadata > $tmp_dir/ec2metadata.default 2>&1
  elif [[ "${FRAMEWORK}" == "gce" ]]; then
    /usr/bin/gcemetadata > $tmp_dir/gcemetadata.default 2>&1
  fi

  ($data_provider > $tmp_dir/metadata.dataprovider 2>&1)
  cp /var/log/sc-repocheck $tmp_dir
  /bin/ls -lA --time-style=long-iso /etc/products.d/ > $tmp_dir/baseproduct

  if [[ "$TCPDUMP_OFF" -eq 0 ]]; then
    tcpdump -s0 -C 100 -W 1 -w $tmp_dir/registercloudguest.pcap tcp port 443 or tcp port 80 2> /dev/null &
    tcpdumppid=$(echo $!)
  fi	
  
    registercloudguestnow

  if [[ "$TCPDUMP_OFF" -eq 0 ]]; then
    kill -13 ${tcpdumppid}
    mv $tmp_dir/registercloudguest.pcap $tmp_dir/registercloudguest.${tcpdumppid}.pcap
  fi

  cp /var/log/cloudregister $tmp_dir
  local filename="${var_location}${SCRIPTNAME}-${date}.tar.xz"
  # compress and move debugging data to /var/log
  tar cfJP $filename $tmp_dir/
  cecho -c 'yellow' "Debug data location: $filename"
}

#######################################
# Any actions that should be taken if the script is prematurely
# exited. 
# Globals:
#   None
# Arguments:
#   None
#######################################
function trap_cleanup() {
  echo ""
  if [ -d "${tmp_dir}" ]; then
    rm -r "${tmp_dir}"
  fi
  die "Script exited prematurely. Exit trapped."
}

#######################################
# Exit safely
# Globals:
#   None
# Arguments:
#   None
#######################################
function safe_exit() {
  # Delete temp files, if any
  if [ -d "${tmp_dir}" ] ; then
    rm -r "${tmp_dir}"
  fi
  trap - INT TERM EXIT
  exit
}

#######################################
# The following function prints a text using custom color
# -c or --color define the color for the print. See the array colors for the available options.
# -n or --noline directs the system not to print a new line after the content.
# Last argument is the message to be printed.
#######################################
function cecho () {
 
    declare -A colors;
    colors=(\
        ['black']='\E[0;47m'\
        ['red']='\E[0;31m'\
        ['green']='\E[0;32m'\
        ['yellow']='\E[0;33m'\
        ['blue']='\E[0;34m'\
        ['magenta']='\E[0;35m'\
        ['cyan']='\E[0;36m'\
        ['white']='\E[0;37m'\
		['bold']='\E[0;1m'\

    );
 
    local defaultMSG="No message passed.";
    local defaultColor="black";
    local defaultNewLine=true;
 
    while [[ $# -gt 1 ]];
    do
    key="$1";
 
    case $key in
        -c|--color)
            color="$2";
            shift;
        ;;
        -n|--noline)
            newLine=false;
        ;;
        *)
            # unknown option
        ;;
    esac
    shift;
    done
 
    message=${1:-$defaultMSG};   # Defaults to default message.
    color=${color:-$defaultColor};   # Defaults to default color, if not specified.
    newLine=${newLine:-$defaultNewLine};
 
    echo -en "${colors[$color]}";
    echo -en "$message" | tee -a /var/log/sc-repocheck;
    echo >> /var/log/sc-repocheck;
    if [ "$newLine" = true ] ; then
        echo;
    fi
    tput sgr0; #  Reset text attributes to normal without clearing screen.
 
    return;
}
#######################################
# Print usage
# Globals:
#   None
# Arguments:
#   None
#######################################
usage() {
  echo -n "${SCRIPTNAME} [OPTION]...
SUSECloud Update Infrastructure Check
 Options:
  -h, --help        Display this help and exit
      --no-tcpdump  Don't run tcpdump during debug collection
      --version     Output version information and exit
"
}

#######################################
# die
# Globals:
#   None
# Arguments:
#   None
#######################################
die() 
{ echo "$*" 1>&2 ; exit 1; }

#######################################
# Run through all checks
# Globals:
#   None
# Arguments:
#   None
#######################################
function main_script() {
  clear
  header
  current
  sslcert
  checkdns
  connectivityrhui
  #framework
  #os
  #check_metadata
  #check_http
  #check_https
  #check_region_servers
  #check_hosts
  #check_baseproduct
  #check_regionclient_version
  #report
}



############## End of Function definitions ###################
# Iterate over options breaking -ab into -a -b when needed and --foo=bar into
# --foo bar
optstring=h
unset options
while (($#)); do
  case $1 in
    # If option is of type -ab
    -[!-]?*)
      # Loop over each character starting with the second
      for ((i=1; i < ${#1}; i++)); do
        c=${1:i:1}

        # Add current char to options
        options+=("-$c")

        # If option takes a required argument, and it's not the last char make
        # the rest of the string its argument
        if [[ $optstring = *"$c:"* && ${1:i+1} ]]; then
          options+=("${1:i+1}")
          break
        fi
      done
      ;;

    # If option is of type --foo=bar
    --?*=*) options+=("${1%%=*}" "${1#*=}") ;;
    # add --endopts for --
    --) options+=(--endopts) ;;
    # Otherwise, nothing special
    *) options+=("$1") ;;
  esac
  shift
done
set -- "${options[@]}"
unset options

# Read the options and set stuff
while [[ $1 = -?* ]]; do
  case $1 in
    -h|--help) usage >&2; safe_exit ;;
	--no-tcpdump) declare -i TCPDUMP_OFF=1 ;;
    --version) echo "${SCRIPTNAME} ${VERSION}"; safe_exit ;;
    *) die "invalid option: '$1'." ;;
  esac
  shift
done

# Store the remaining part as arguments.
args+=("$@")

############## End of Options ###################

# Trap bad exits
trap trap_cleanup EXIT INT TERM

# Run all checks
main_script
# Safely exit script
safe_exit
