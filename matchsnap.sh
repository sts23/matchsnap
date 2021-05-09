#! /bin/sh

PR_AUFRUF() {
cat <<ENDE

Usage: $(basename $0) [-hq] [-t tag ] <Destination Dataset> [Source Dataset]

  Check if latest Snapshot on Destination exists on Source. 

  -h show help
  -q quietmode. Less output, more machine readable.  
  -t <Tag> Look (grep) only for Snapshots with a specific Name.
     Example: -t backup-daily to find only snapshots with backup-daily in its name

ENDE
}

ZFS() {
  HOST="$1"
  shift
  PORT="$1"
  shift
  if [ -z "$HOST" ] 
  then
    zfs "$@"
  else
    #echo "Connecting to $HOST" 1>&2
    ssh -C -p "$PORT" "$HOST" zfs "$@" 
  fi
}

PR_OUT() {
  if [ "$QUIET" != "true" ]
  then
    echo "$@" >&2
  fi
}

GET_LASTDSNP() {
  H="$1"
  P="$2"
  DS="$3"
  T="$4"

  PR_OUT "+ Get last snapshot from target (Name,Guid,Creation): $DESTDS $DHOST"

  LASTDESTSNP=`ZFS "$H" "$P" list -t snapshot -H -o name,guid,creation -p \
	       -s creation $DS | grep "@.*$T" | tail -1`


  DESTSNP_NAME=`echo $LASTDESTSNP|awk '{print $1}'`
  DESTSNP_GUID=`echo $LASTDESTSNP|awk '{print $2}'`
  DESTSNP_CREATE=`echo $LASTDESTSNP|awk '{$1=""; $2=""; print}'`
  NOW=`date +%s`

  if [ "$LASTDESTSNP" = "" ] 
  then 
    LASTDESTSNP="No snapshot found"
    STATDSTSNAP="NOSNP" 
    STATDSTDS="$DS" 
    DSTAGE="-1"
  else
    STATDSTSNAP="FOUND" 
    STATDSTDS="$DS" 
    DSTAGE=$(((NOW - DESTSNP_CREATE) / 60 /60))
  fi
  PR_OUT "  $LASTDESTSNP" 
  PR_OUT "+ Age of Snapshot:  ${DSTAGE}h" 
}

GET_MATCHSNP() {
  H="$1"
  P="$2"
  DS="$3"
  T="$4"
  PR_OUT "+ Get matching snapshots from source (Name,Guid,Creation): $SRCDS $SHOST"

  if [ "$SRCDS" = "" ]
  then
    SRCSNAPLIST=`ZFS "$H" "$P" list -t snapshot -H -o name,guid,creation -p \
                 -s creation | grep "$T"`
  else
    SRCSNAPLIST=`ZFS "$H" "$P" list -t snapshot -H -o name,guid,creation -p \
                 -s creation $DS | grep "$T"`
  fi

  # bash only:
  #while IFS= read -r LINE
  #do
  #  SRCSNP_NAME=`echo $LINE|awk '{print $1}'`
  #  SRCSNP_GUID=`echo $LINE|awk '{print $2}'`
  #  SRCSNP_CREATE=`echo $LINE|awk '{$1=""; $2=""; print}'`
  #
  #  if [ "$SRCSNP_GUID" = "$DESTSNP_GUID" ]
  #  then
  #    echo "$LINE"
  #    MATCH="true"
  #  fi 
  #done <<< "$SRCSNAPLIST" 


  #MATCHLINES=`echo "$SRCSNAPLIST" | awk -v TGUID=$DESTSNP_GUID -v HOSTA=$DHOST '{
  #  if( $2 == TGUID) {
  #    print $0;
  #  }
  #}'`

  SNAPCOUNT=`echo "$SRCSNAPLIST"|wc -l`
  LINECOUNT=0
  HITCOUNT=0
  echo "$SRCSNAPLIST" | while IFS= read -r LINE
  do
    LINECOUNT=$((LINECOUNT + 1))
    SRCSNP_NAME=`echo $LINE|awk '{print $1}'`
    SRCSNP_DS=`echo $LINE|sed 's/@.*$//'`
    SRCSNP_GUID=`echo $LINE|awk '{print $2}'`
    SRCSNP_CREATE=`echo $LINE|awk '{$1=""; $2=""; print}'`
  
    if [ "$SRCSNP_GUID" = "$DESTSNP_GUID" ]
    then
      if [ "$DHOST" = "$SHOST" ]
      then
        if [ ! "$LINE" = "$LASTDESTSNP" ]
        then
	  HITCOUNT=$((HITCOUNT + 1))
          PR_OUT "  $LINE"
          STATSRCSNAP="FOUND"
          STATSRCDS="$SRCSNP_DS"
        fi
      else
	HITCOUNT=$((HITCOUNT + 1))
        PR_OUT "  $LINE"
        STATSRCSNAP="FOUND"
        STATSRCDS="$SRCSNP_DS"
      fi
    fi 
    if [ "$LINECOUNT" = "$SNAPCOUNT" ]
    then
      if [ "$HITCOUNT" = "0" ]
      then
	 PR_OUT "  No Snapshot found"
         STATSRCSNAP="NOSNP"
         STATSRCDS="$DS"
      fi 
      if [ "$QUIET" = "true" ]
      then
        if [ "$STATDSTSNAP" = "FOUND" -a "$STATSRCSNAP" = "FOUND" ]
        then
	   MATCH="OK"
	else
	   MATCH="NO"
        fi
        printf "+ Match:$MATCH D:$STATDSTSNAP S:$STATSRCSNAP DA:$DSTAGE "
        printf "DDS:$STATDSTDS SDS:$STATSRCDS T:$TAG\n"
      fi
    fi
  done 
}

#### End Functions ####

while getopts ":hqt:" opt
do
  case $opt in
    h) pr_aufruf
       exit 0
       ;;
    q) QUIET="true"
       ;;
    t) TAG="$OPTARG"
       ;;
   \?) echo "Unknown Option: -$OPTARG" 1>&2;;
    :) echo "Error option: -$OPTARG needs argument" 1>&2;;
  esac
done

shift $((OPTIND -1))

if [ "$1" = "" -o $# -gt 2 ]
then
  PR_AUFRUF
  exit 1
fi

# Default Port 22
DPORT="22"
SPORT="22"
DEST="$1"
SRC="$2"

COUNTPARTS=`echo "$DEST"|awk -F":" '{print NF-1}'`
case $COUNTPARTS in
     0) DHOST=""
        DESTDS="$DEST"
        ;;
     1) DHOST=`echo "$DEST"|cut -d':' -f1`
        DESTDS=`echo "$DEST"|cut -d':' -f2`
        ;;
     2) DHOST=`echo "$DEST"|cut -d':' -f1`
        DPORT=`echo "$DEST"|cut -d':' -f2`
        DESTDS=`echo "$DEST"|cut -d':' -f3`
        ;;
esac

if [ "$SRC" != "" ]
then
  COUNTPARTS=`echo "$SRC"|awk -F":" '{print NF-1}'`
  case $COUNTPARTS in
       0) SHOST=""
          SRCDS="$SRC"
          ;;
       1) SHOST=`echo "$SRC"|cut -d':' -f1`
          SRCDS=`echo "$SRC"|cut -d':' -f2`
          ;;
       2) SHOST=`echo "$SRC"|cut -d':' -f1`
          SPORT=`echo "$SRC"|cut -d':' -f2`
          SRCDS=`echo "$SRC"|cut -d':' -f3`
          ;;
  esac
fi

if [ "$DESTDS" = "alldatasets" ]
then
  PR_OUT "+ Get all Datasets $DHOST"
  ZFSSETLIST=`ZFS "$DHOST" "$DPORT" list -H -o name`
  PR_OUT "$ZFSSETLIST"
  for DATASET in $ZFSSETLIST
  do
    DESTDS="$DATASET"
    GET_LASTDSNP "$DHOST" "$DPORT" "$DESTDS" "$TAG"
    GET_MATCHSNP "$SHOST" "$SPORT" "$SRCDS" "$TAG"
    PR_OUT ""
  done
else
  GET_LASTDSNP "$DHOST" "$DPORT" "$DESTDS" "$TAG"
  GET_MATCHSNP "$SHOST" "$SPORT" "$SRCDS" "$TAG"
fi
exit 0
