############################################################################
# INIT
############################################################################
source rcloneupload.sh
source init.sh
source settings.conf
source /opt/appdata/plexguide/supertransfer/usersettings.conf


init_DB(){
  [[ $gdsaImpersonate == 'your@email.com' ]] \
    && echo -e "[$(date +%m/%d\ %H:%M)] [FAIL]\tNo Email Configured. Please edit $usersettings" \
    && exit 1

  # get list of avail gdsa accounts
  gdsaList=$(rclone listremotes | sed 's/://' | egrep '^GDSA[0-9]+$')
  if [[ -n $gdsaList ]]; then
      numGdsa=$(echo $gdsaList | wc -w)
      maxDailyUpload=$(python3 -c "round($numGdsa * 750 / 1000, 3"))
      echo -e "[$(date +%m/%d\ %H:%M)] [INFO]\tInitializing $numGdsa Service Accounts:\t${maxDailyUpload}TB Max Daily Upload"
      echo -e "[$(date +%m/%d\ %H:%M)] [INFO]\tValidating Domain Wide Impersonation:\t$gdsaImpersonate"
  else
      echo -e "[$(date +%m/%d\ %H:%M)] [FAIL]\tNo Valid SA accounts found! Is Rclone Configured With GDSA## remotes?"
      exit 1
  fi

  # reset existing logs & db
  echo '' > /tmp/SA_error.log
  echo '' > $gdsaDB
  # test for working gdsa's and init gdsaDB
  for gdsa in $gdsaList; do
    s=0
    rclone touch --drive-impersonate $gdsaImpersonate ${gdsa}:/.test &>/tmp/.SA_error.log.tmp && s=1
    if [[ $s == 1 ]]; then
      echo -e "[$(date +%m/%d\ %H:%M)] [INFO]\tGDSA Impersonation Success:\t ${gdsa}"
      echo "${gdsa}=0" >> $gdsaDB
    else
      echo -e "[$(date +%m/%d\ %H:%M)] [WARN]\tGDSA Impersonation Failure:\t ${gdsa}"
      cat /tmp/.SA_error.log.tmp >> /tmp/SA_error.log
      ((gdsaFail++))
    fi
  done

  [[ -n $gdsaFail ]] \
    && echo -e "[$(date +%m/%d\ %H:%M)] [WARN]\t$gdsaFail Failure(s)."

}
init_DB

############################################################################
# Least Usage Load Balancing of GDSA Accounts
############################################################################


uploadQueueBuffer=$(find $localDir -mindepth 2 -mmin +${modTime} -type f \
  -exec du -s {} \; | awk -F'\t' '{print $1 "\t" "\"" $2 "\""}' | sort -gr)

# iterate through uploadQueueBuffer and update gdsaDB, incrementing usage values
while read -r line; do
  gdsaLeast=$(sort -gr -k2 -t'=' $gdsaDB | tail -1 | cut -f1 -d'=')
  export gdsaLeast
  # skip on files already queued or uploaded
  [[ ! -e $uploadHistory ]] || touch $uploadHistory
  if [[ ! $(grep "${line}" $uploadHistory) ]]; then
    file=$(awk '{print $2}' <<< $line)
    fileSize=$(awk '{print $1}' <<< $line)
    rclone_upload $gdsaLeast $file $remoteDir &
    # add timestamp & log
    echo -e "[$(date +%m/%d\ %H:%M)] [INFO]\t$gdsaLeast\tStarting Upload: $file"
    echo "$gdsaLeast $line $(date +s%)" >> $uploadHistory

    # load latest usage value from db
    source $gdsaDB
    Usage=$(( $gdsaLeast + $fileSize ))
    # update gdsaUsage file with latest usage value
    sed -i '/'^$gdsaLeast'=/ s/=.*/='$Usage'/' $gdsaDB
  fi
done <<< "$uploadQueueBuffer"

echo "script end"
