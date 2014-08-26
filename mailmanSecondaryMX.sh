#! /bin/bash

#------------------------------------------#
#           mailmanSecondaryMX             #
#------------------------------------------#
#                                          #
#  Extract Postfix's virtual_alias_maps to #
#        a secondary MX Server             #
#                                          #
#              Yvan Godard                 #
#          godardyvan@gmail.com            #
#                                          #
#      Version 0.1 -- august, 23 2014      #
#             Under Licence                #
#     Creative Commons 4.0 BY NC SA        #
#                                          #
#          http://goo.gl/znEUU4            #
#                                          #
#------------------------------------------#

# Variables initialisation
VERSION="mailmanSecondaryMX v0.1 - 2014, Yvan Godard [godardyvan@gmail.com]"
help="no"
SCRIPT_DIR=$(dirname $0)
SCRIPT_NAME=$(basename $0)
RELAY_RECIPIENT_MAP=/var/lib/mailman/data/virtual-mailman
EXTRACTED_MAP=$(mktemp /tmp/mailmanSecondaryMX_map.XXXXX)
EXTRACTED_MAP_TEMP=$(mktemp /tmp/mailmanSecondaryMX_map_temp.XXXXX)
REMOTE_SERVER_ADDRESS=""
REMOTE_SERVER_USER="root"
REMOTE_SERVER_POSTMAP_CMD="/usr/sbin/postmap"
REMOTE_RELAY_RECIPIENT_MAP="/etc/postfix/mailmanSecondaryMX"
DOMAINS="alldomains"
DOMAINS_LIMIT=0
LIST_DOMAINS=$(mktemp /tmp/mailmanSecondaryMX_domains.XXXXX)
EMAIL_REPORT="nomail"
EMAIL_LEVEL=0
LOG="/var/log/mailmanSecondaryMX.log"
LOG_TEMP=$(mktemp /tmp/mailmanSecondaryMX_tmpLog.XXXXX)
LOG_ACTIVE=0
EMAIL_ADDRESS=""
SSH_TEST=0

help () {
	echo -e "$VERSION\n"
	echo -e "This tool is designed to export a Postfix's virtual_alias_maps to a secondary MX Server."
	echo -e "SSH access to this second server should be possible without password (key authentication)."
	echo -e "This tool is licensed under the Creative Commons 4.0 BY NC SA licence."
	echo -e "\nDisclamer:"
	echo -e "This tool is provide without any support and guarantee."
	echo -e "\nSynopsis:"
	echo -e "./${SCRIPT_NAME} [-h] | -s <secondary server address>"
	echo -e "                        [-r <relay recipient map>] [-u <remote user>]"
	echo -e "                        [-R <remote postfix map>] [-c <remote postmap command>]"
	echo -e "                        [-d <domains to extract>]"
	echo -e "                        [-e <email report option>] [-E <email address>] [-j <log file>]"
	echo -e "\n\t-h:                              prints this help then exit"
	echo -e "\nMandatory option:"
	echo -e "\t-s <secondary server address>:   the address of the secondary MX Server (IP or URL, i.e.: 'mysecondarymx.server.com')"
	echo -e "\nOptional options:"
	echo -e "\t-r <relay recipient map>:        the full path of relay recipient map, as defined here http://goo.gl/39uDsc,"
	echo -e "\t                                 for the Mailman server (default: '${RELAY_RECIPIENT_MAP}')"
	echo -e "\t-u <remote user>:                the remote user who can connect through SSH to the secondary MX server,"
	echo -e "\t                                 and can lauch Postmap command (i.e.: 'myuser', default: '${REMOTE_SERVER_USER}'."
	echo -e "\t-R <remote postfix map>:         the full name of the remote Postfix map filename (i.e.: '/etc/postfix/map1',"
	echo -e "\t                                 default '${REMOTE_RELAY_RECIPIENT_MAP}''). This map file must be defined"
	echo -e "\t                                 in '/etc/postfix/main.cf' as a 'relay_recipient_maps ='"
	echo -e "\t-c <remote postmap command>:     the full path of sencondary MX server 'postmap' command (default: '${REMOTE_SERVER_POSTMAP_CMD}')"
	echo -e "\t-d <domains to extract>:         domains that must be processed with or without '@', separated by '%'"
	echo -e "\t                                 (i.e.: '@mydomain.com' or 'my.domain.com%@second.domain.net') or use 'alldomains'."
	echo -e "\t                                 For all domains, please enter '-d alldomains'. By default: '${DOMAINS}'"
	echo -e "\t-e <email report option>:        settings for sending a report by email, must be 'onerror', 'forcemail' or 'nomail',"
	echo -e "\t                                 default: '${EMAIL_REPORT}'."
	echo -e "\t-E <email address>:              email address to send the report, must be filled if '-e forcemail' or '-e onerror' options is used"
	echo -e "\t-j <log file>:                   enables logging instead of standard output. Specify an argument for the full path to the log file"
	echo -e "\t                                 (i.e.: '$LOG') or use 'default' ($LOG)"
	exit 0
}

error () {
	echo -e "\n*** Error ***"
	echo -e ${1}
	echo -e "\n"${VERSION}
	alldone 1
}

alldone () {
	# Redirect standard outpout
	exec 1>&6 6>&-
	# Logging if needed 
	[ $LOG_ACTIVE -eq 1 ] && cat $LOG_TEMP >> $LOG
	# Print current log to standard outpout
	[ $LOG_ACTIVE -ne 1 ] && cat $LOG_TEMP
	[ $EMAIL_LEVEL -ne 0 ] && [ $1 -ne 0 ] && cat $LOG_TEMP | mail -s "[ERROR] ${SCRIPT_NAME} on ${HOSTNAME}" ${EMAIL_ADDRESS}
	[ $EMAIL_LEVEL -eq 2 ] && [ $1 -eq 0 ] && cat $LOG_TEMP | mail -s "[OK] ${SCRIPT_NAME} on ${HOSTNAME}" ${EMAIL_ADDRESS}
	# Remove temp files/folder
	rm -R /tmp/mailmanSecondaryMX*
	exit ${1}
}

while getopts "hs:u:c:d:r:R:e:E:j:" OPTION
do
	case "$OPTION" in
		h)	help="yes"
						;;
		s)	REMOTE_SERVER_ADDRESS=${OPTARG}
						;;
		r) 	RELAY_RECIPIENT_MAP=${OPTARG}
						;;
		u)	REMOTE_SERVER_USER=${OPTARG}
						;;
		R)	REMOTE_RELAY_RECIPIENT_MAP=${OPTARG}
						;;
	    c) 	REMOTE_SERVER_POSTMAP_CMD=${OPTARG}
						;;
		d) 	DOMAINS=${OPTARG}
			if [[ ${DOMAINS} != "alldomains" ]] 
				then
				echo ${DOMAINS} | perl -p -e 's/%/\n/g' | perl -p -e 's/ //g' | awk '!x[$0]++' >> ${LIST_DOMAINS}
				DOMAINS_LIMIT=1
			elif [[ ${DOMAINS} = "alldomains" ]]
				then
				DOMAINS_LIMIT=0
			fi
						;;
        e)	EMAIL_REPORT=${OPTARG}
                        ;;                             
        E)	EMAIL_ADDRESS=${OPTARG}
                        ;;
        j)	[ $OPTARG != "default" ] && LOG=${OPTARG}
			LOG_ACTIVE=1
                        ;;
	esac
done

# Verifiy mandatory option
if [[ ${REMOTE_SERVER_ADDRESS} = "" ]]
	then
        help
        alldone 1
fi

# Redirect standard outpout to temp file
exec 6>&1
exec >> ${LOG_TEMP}

# Start temp log file
echo -e "\n****************************** `date` ******************************\n"
echo -e "$0 started with options:"
echo -e "\t-s ${REMOTE_SERVER_ADDRESS} (secondary server address)"
echo -e "\t-r ${RELAY_RECIPIENT_MAP} (local relay recipient map)"
echo -e "\t-u ${REMOTE_SERVER_USER} (remote user)"
echo -e "\t-R ${REMOTE_RELAY_RECIPIENT_MAP} (remote postfix map)"
echo -e "\t-c ${REMOTE_SERVER_POSTMAP_CMD} (remote postmap command)"
if [[ ${DOMAINS_LIMIT} = "1" ]]; then
	echo -e "\t-d (domains to extract):"
	for LINE in $(cat ${LIST_DOMAINS})
	do
		echo -e "\t   > ${LINE}"
	done
elif [[ ${DOMAINS_LIMIT} = "0" ]]; then
	echo -e "\t-d alldomains"
fi
echo -e "\t-e ${EMAIL_REPORT} (email report option)"
if [[ ${EMAIL_REPORT} != "nomail" ]] 
	then
	echo -e "\t-E ${EMAIL_ADDRESS} (email report address)"
fi
if [[ ${LOG_ACTIVE} != "0" ]]
	then
	echo -e "\t-j ${LOG} (log file)"
fi
echo ""

# Test of sending email parameter and check the consistency of the parameter email address
if [[ ${EMAIL_REPORT} = "forcemail" ]]
	then
	EMAIL_LEVEL=2
	if [[ -z $EMAIL_ADDRESS ]]
		then
		echo -e "You used option '-e ${EMAIL_REPORT}' but you have not entered any email info.\n\t> We continue the process without sending email."
		EMAIL_LEVEL=0
	else
		echo "${EMAIL_ADDRESS}" | grep '^[a-zA-Z0-9._-]*@[a-zA-Z0-9._-]*\.[a-zA-Z0-9._-]*$' > /dev/null 2>&1
		if [ $? -ne 0 ]
			then
    		echo -e "This address '${EMAIL_ADDRESS}' does not seem valid.\n\t> We continue the process without sending email."
    		EMAIL_LEVEL=0
    	fi
    fi
elif [[ ${EMAIL_REPORT} = "onerror" ]]
	then
	EMAIL_LEVEL=1
	if [[ -z $EMAIL_ADDRESS ]]
		then
		echo -e "You used option '-e ${EMAIL_REPORT}' but you have not entered any email info.\n\t> We continue the process without sending email."
		EMAIL_LEVEL=0
	else
		echo "${EMAIL_ADDRESS}" | grep '^[a-zA-Z0-9._-]*@[a-zA-Z0-9._-]*\.[a-zA-Z0-9._-]*$' > /dev/null 2>&1
		if [ $? -ne 0 ]
			then	
    		echo -e "This address '${EMAIL_ADDRESS}' does not seem valid.\n\t> We continue the process without sending email."
    		EMAIL_LEVEL=0
    	fi
    fi
elif [[ ${EMAIL_REPORT} != "nomail" ]]
	then
	echo -e "\nOption '-e ${EMAIL_REPORT}' is not valid (must be: 'onerror', 'forcemail' or 'nomail').\n\t> We continue the process without sending email."
	EMAIL_LEVEL=0
elif [[ ${EMAIL_REPORT} = "nomail" ]]
	then
	EMAIL_LEVEL=0
fi

# Test SSH connection
ssh -q -o "BatchMode=yes" ${REMOTE_SERVER_USER}@${REMOTE_SERVER_ADDRESS} "echo 2>&1" && SSH_TEST=1 || echo -e "Unable to access ssh://${REMOTE_SERVER_USER}@${REMOTE_SERVER_ADDRESS}."
if [[ ${SSH_TEST} = "0" ]]; then
	error "Your SSH connection to ${REMOTE_SERVER_USER}@${REMOTE_SERVER_ADDRESS} doesn't work.\nPlease verify parameters.\nPerhaps you need to set up SSH Keys as described here: http://goo.gl/475wy4."
fi

# Test if remote POSTMAP command exists
TEST_POSTMAP_CMD=$(ssh ${REMOTE_SERVER_ADDRESS} -l ${REMOTE_SERVER_USER} test -f ${REMOTE_SERVER_POSTMAP_CMD} && echo OK)
if [[ ! ${TEST_POSTMAP_CMD} = "OK" ]]; then
	error "Postmap command ${REMOTE_SERVER_USER}@${REMOTE_SERVER_ADDRESS}:${REMOTE_SERVER_POSTMAP_CMD} doesn't exist.\nPlease verify parameters."
fi

# Test RELAY_RECIPIENT_MAP file
if [[ ! -f ${RELAY_RECIPIENT_MAP} ]]; then
	error "Relay Recipient Map file '${RELAY_RECIPIENT_MAP}' to process doesn't exist.\nPlease verify parameters."
fi

# Test DOMAIN content
[[ ${DOMAINS_LIMIT} = "1" ]] && [[ -z $(cat ${LIST_DOMAINS}) ]] && echo "Option -d used without any domain. Process continues with '-d alldomains'." && DOMAINS="alldomains" && DOMAINS_LIMIT=0

# Step 1 : extract remote map
OLDIFS=$IFS; IFS=$'\n'
if [[ ${DOMAINS_LIMIT} = "1" ]]; then
	for RELAY_RECIPIENT in $(cat ${RELAY_RECIPIENT_MAP})
	do
		for DOMAIN in $(cat ${LIST_DOMAINS})
		do
			echo "${RELAY_RECIPIENT}" | grep ${DOMAIN} > /dev/null 2>&1
			[[ ${?} -eq 0 ]] && echo "${RELAY_RECIPIENT}" >> ${EXTRACTED_MAP_TEMP}
		done
	done
fi

[[ ${DOMAINS_LIMIT} = "1" ]] && [[ -z $(cat ${EXTRACTED_MAP_TEMP}) ]] && error "Nothing to extract. Please verify your parameters."

echo "# Relay recipient map file generated by ${0}" >> ${EXTRACTED_MAP}
echo "# on ${HOSTNAME}" >> ${EXTRACTED_MAP}
echo "# ${VERSION}" >> ${EXTRACTED_MAP}
echo "# `date`" >> ${EXTRACTED_MAP}
cat ${EXTRACTED_MAP_TEMP} | awk '!x[$0]++' >> ${EXTRACTED_MAP}

IFS=$OLDIFS

# Step 2 : send file to secondary MX Server
if [[ ${DOMAINS_LIMIT} = "0" ]]; then
	[[ -f ${EXTRACTED_MAP} ]] && rm ${EXTRACTED_MAP}
	echo -e "\n-> Sending original relay recipient map ${RELAY_RECIPIENT_MAP}..."
	rsync -cave ssh ${RELAY_RECIPIENT_MAP} ${REMOTE_SERVER_USER}@${REMOTE_SERVER_ADDRESS}:${REMOTE_RELAY_RECIPIENT_MAP}
	if [ $? -ne 0 ]; then
		ERROR_MESSAGE=$(echo $?)
		error "Error while sending file:\nrsync -cave ssh ${RELAY_RECIPIENT_MAP} ${REMOTE_SERVER_USER}@${REMOTE_SERVER_ADDRESS}:${REMOTE_RELAY_RECIPIENT_MAP}.\n${ERROR_MESSAGE}."
	else
		echo -e "\n-> Sending file to ${REMOTE_SERVER_ADDRESS}: OK"
	fi
elif [[ ${DOMAINS_LIMIT} = "1" ]]; then
	echo -e "\n-> Relay recipient map extracted to ${EXTRACTED_MAP}..."
	rsync -cave ssh ${EXTRACTED_MAP} ${REMOTE_SERVER_USER}@${REMOTE_SERVER_ADDRESS}:${REMOTE_RELAY_RECIPIENT_MAP}
	if [ $? -ne 0 ]; then
		ERROR_MESSAGE=$(echo $?)
		error "Error while sending file:\nrsync -cave ssh ${EXTRACTED_MAP} ${REMOTE_SERVER_USER}@${REMOTE_SERVER_ADDRESS}:${REMOTE_RELAY_RECIPIENT_MAP}.\n${ERROR_MESSAGE}."
	else
		echo -e "\n-> Sending file to ${REMOTE_SERVER_ADDRESS}: OK"
	fi
fi

# Step 3 : postmap 
ssh ${REMOTE_SERVER_USER}@${REMOTE_SERVER_ADDRESS} '${REMOTE_SERVER_POSTMAP_CMD} ${REMOTE_RELAY_RECIPIENT_MAP}'
if [ $? -ne 0 ]; then
	ERROR_MESSAGE=$(echo $?)
	error "Error while running command:\nssh ${REMOTE_SERVER_USER}@${REMOTE_SERVER_ADDRESS} '${REMOTE_SERVER_POSTMAP_CMD} ${REMOTE_RELAY_RECIPIENT_MAP}'.\n${ERROR_MESSAGE}."
else
	echo -e "\n-> Postmap on remote server (${REMOTE_SERVER_POSTMAP_CMD} ${REMOTE_RELAY_RECIPIENT_MAP}): OK"
fi

echo ""
echo "***************************** ${SCRIPT_NAME} finished ******************************"
alldone 0
