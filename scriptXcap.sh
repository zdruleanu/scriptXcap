#!/bin/bash

# Arguments: {User} {ServiceOption} {Action} [FTN]

#Variables used :
#   User
#   Action
#   Service
#   ServiceTypeOption
#   Method
#   Header
#	rule_head
#	conditions 
#	action
#	rule_end

# Sourcing in the configuration file
. ./configure.txt

valid_number()
{
    local  user=$1
    local  stat=1

    if [[ $user =~ ^((\+|(00)[1-9])|(0[1-9]))[0-9]*$ ]]; then
        stat=$?
    fi
    return $stat
}

check_arguments()
{
	if [[ $# -gt 4 || $# -lt 3 ]]; then
		echo "Invalid number of arguments provided";
		echo "Syntax: scriptXcap.sh [ {User} {ServiceOption} {Action} [FTN] ]"
		exit;
	fi		
	if ! valid_number $1; then
		echo "Format of the user number ($1) is incorrect";
		echo "Syntax: scriptXcap.sh [ {User} {ServiceOption} {Action} [FTN] ]"
		exit;
	else
		User=$1
		echo "use ok"
	fi
	if [[ $2 = ${CallForwardingUnconditional} || $2 = ${CallForwardingBusy} || $2 = ${CallForwardingNoReply} || $2 = ${CallForwardingNotReachable} ]]; then
		ServiceTypeOption="communication-diversion"
		ServiceOption=$2
	elif [[ $2 = ${BarAllIncomingCalls} || $2 = ${BarAllIncomingCallsWhenRoaming} ]]; then
		ServiceTypeOption="incoming-communication-barring"
		ServiceOption=$2
	elif [[ $2 = ${BarAllOutgoingCalls} || $2 = ${BarOutgoingInternationalCalls} || $2 = ${BarOutgoingInternationalCallsExceptHome} ]]; then
		ServiceTypeOption="outgoing-communication-barring"
		ServiceOption=$2
	else
		echo "Service type ($2) not defined";
		echo "Syntax: scriptXcap.sh [ {User} {ServiceOption} {Action} [FTN] ]";
		exit;
	fi
	if [[ $3 = "Query" || $3 = "Activate" || $3 = "Deactivate" ]]; then
		ActionOption=$3
	else
		echo "Action ($3) not defined";
		echo "Syntax: scriptXcap.sh [ {User} {ServiceOption} {Action} [FTN] ]";
		exit;
	fi
	if [[ ${ServiceTypeOption} = "communication-diversion" && ${ActionOption} = "Activate" ]]; then
		if ! valid_number $4; then
			echo "Format of the Forwarded-to-number ($4) is incorrect";
			echo "Syntax: scriptXcap.sh [ {User} {ServiceOption} {Action} [FTN] ]"
			exit;
		else
			FTN=$4
		fi
	fi
	return 0
}

menu_mode()
{
	while true; do
		read -p "Please input the MSISDN (ex. +4915250410557) " User
		if valid_number $User; then
			break;
		else
			echo "The provided number is not in the correct format";
		fi
	done

	echo "Please select a Supplementary Service type:"
	ServicesType="communication-diversion incoming-communication-barring outgoing-communication-barring exit"
	select ServiceTypeOption in $ServicesType; do
		case $ServiceTypeOption in
			communication-diversion )	Services="${CallForwardingUnconditional} ${CallForwardingBusy} ${CallForwardingNoReply} ${CallForwardingNotReachable} exit"
										break;;
			incoming-communication-barring )
										Services="${BarAllIncomingCalls} ${BarAllIncomingCallsWhenRoaming} exit"
										break;;
			outgoing-communication-barring	)
										Services="${BarAllOutgoingCalls} ${BarOutgoingInternationalCalls} ${BarOutgoingInternationalCallsExceptHome} exit";
										break;;
			exit	)					exit;;
			*	)						exit;;
		esac
	done
	select ServiceOption in $Services; do
	    case $ServiceOption in
				
	        exit ) exit;;
			
			*	)	break;;
	    esac
	done

	Actions="Query Activate Deactivate exit"

	select ActionOption in $Actions; do
		case $ActionOption in
			exit )	
				exit;;
			*	)	
				break;;
		esac
	done
	return 0
}

format_header()
{
    Request=" http://${IP}:${Port}/simservs.ngn.etsi.org/users/sip:${User}@${ImsDomain}/simservs.xml/~~/simservs/${ServiceTypeOption}/ruleset/rule%5B@id=%22${Service}%22%5D/"
    Accept=" -H Accept:*/*"
    Host=" -H Host:${HostName}"
    Connection=" -H Connection:Close"
    Cache=" -H cache-control:max-age=43200"
    UA=" -H user-agent:3gpp-gba"
    AcceptEncoding=" -H accept-encoding:compress"
    X3gppAssertedId=" -H x-3gpp-asserted-identity:\"sip:${User}@${ImsDomain}\""
	if [[ -z $ContentType ]];then
		Header=${Request}${Accept}${Host}${Connection}${Cache}${UA}${AcceptEncoding}${X3gppAssertedId}
	else
		Header=${Request}${Accept}${Host}${Connection}${ContentType}${Cache}${UA}${AcceptEncoding}${X3gppAssertedId}
	fi
}

format_body()
{
	if [[ $ActionOption = "Query" ]]; then
		Body="";
	else
		Body=${rule_head}${conditions}${action}${rule_end};
# Remove the spces betweem elements
		Body="$(echo $Body | sed 's/> />/g')";
	fi
}



######## Starting main

# check if arguments provided 
if [[ $# -ne 0 ]]; then
	check_arguments $@
	echo "Arguments OK"
else
	echo "No arguments provided. Switching to interractive mode"
	menu_mode
fi


case $ServiceOption in

    ${CallForwardingUnconditional} ) 
		Service="${CallForwardingUnconditional}";
		rule_head="<cp:rule id=\"${CallForwardingUnconditional}\">";
		conditions="";
		;;
    ${CallForwardingBusy} ) 
		Service="${CallForwardingBusy}";
		rule_head="<cp:rule id=\"${CallForwardingBusy}\">"; 
			conditions="<busy/>";	
		;;	
    ${CallForwardingNoReply} ) 
		Service="${CallForwardingNoReply}";
		rule_head="<cp:rule id=\"${CallForwardingNoReply}\">";  
		conditions="<no-answer/>";
		;;
			
    ${CallForwardingNotReachable} ) 
		Service="${CallForwardingNotReachable}";
		rule_head="<cp:rule id=\"${CallForwardingNotReachable}\">";  
		conditions="<not-reachable/>";
		;;
			
	${BarAllIncomingCalls} )	
		Service="${BarAllIncomingCalls}";
		rule_head="<cp:rule id=\"${BarAllIncomingCalls}\">";  
		conditions="";
		action="<cp:actions>
				  <allow>false</allow>
				</cp:actions>";		
		;;
			
	${BarAllIncomingCallsWhenRoaming} )
		Service="${BarAllIncomingCallsWhenRoaming}";
		rule_head="<cp:rule id=\"${BarAllIncomingCallsWhenRoaming}\">";  
		conditions="<roaming/>";
		action="<cp:actions>
				  <allow>false</allow>
				</cp:actions>";		
		;;
			
	${BarAllOutgoingCalls} )	
		Service="${BarAllOutgoingCalls}";
		rule_head="<cp:rule id=\"${BarAllOutgoingCalls}\">";  
		conditions="";
		action="<cp:actions>
				  <allow>false</allow>
				</cp:actions>";		
		;;
			
	${BarOutgoingInternationalCalls} )	
		Service="${BarOutgoingInternationalCalls}";
		rule_head="<cp:rule id=\"${BarOutgoingInternationalCalls}\">";  
		conditions="<international/>";
		action="<cp:actions>
				  <allow>false</allow>
				</cp:actions>";
		;;
			
	${BarOutgoingInternationalCallsExceptHome} )
		Service="${BarOutgoingInternationalCallsExceptHome}";
		rule_head="<cp:rule id=\"${BarOutgoingInternationalCallsExceptHome}\">";  
		conditions="<international-exHC/>";
		action="<cp:actions>
				  <allow>false</allow>
				</cp:actions>";
		;;
esac

case $ActionOption in
	Query ) 
		Method="GET";
		;;
	Activate )	
		Method="PUT";
		ContentType=" -H Content-Type:application/xcap-el+xml";
		conditions="<cp:conditions>"${conditions}"</cp:conditions>"
		if [ $ServiceTypeOption = "communication-diversion" ]; then
			if ! ( valid_number $FTN ) ; then
				while true; do
					read -p "Please input the Forwarded-to-number " FTN
					if valid_number $FTN; then
						break;
					else
						echo "The provided number is not in the correct format";
					fi
				done
			fi
			action="<cp:actions>
						<forward-to>
							<target>tel:${FTN}</target>   
						</forward-to>
					</cp:actions>";
		fi
		;;
	Deactivate )
		Method="PUT";
		ContentType=" -H Content-Type:application/xcap-el+xml";
		conditions="<cp:conditions>"${conditions}"<rule-deactivated/></cp:conditions>"
		;;
esac
rule_end="</cp:rule>"

format_header
format_body


if [[ $Method = "GET" ]];then
	echo "dam cu GET";
	echo "metoda: "$Method;
	curl -g -X $Method $Header --trace-ascii /dev/stdout;
else
	echo "dam cu PUT";
	echo "metoda: "$Method;
	curl -g -X $Method $Header -d "${Body}" --trace-ascii /dev/stdout;
fi



