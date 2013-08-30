#!/bin/sh
usage() {
  cat << END_HELP
  Usage: $0 -branch [dev|rel] -locale CODE
  $@
  
  Arguments 
      CODE   one or more of ja, ru or zh, 
             in a comma separated list if more than one is given 
  Requirements
      - The github i18n repository must be cloned
      - The WORKSPACE environment variable is set to the 
        directory where the i18n repository was cloned into
END_HELP
  exit 1
}

#
# To checkout star-ccm+ source files (release or development)
#
checkout_star() {
  STAR_HOME=${WORKSPACE}/star
  I18N_HOME=${WORKSPACE}/i18n

  # there should not be a star directory in the workspace, but just in case
  if [ -d "STAR_HOME" ] ; then
    \rm -rf STAR_HOME
  fi

  # Clone star
  cd $WORKSPACE
  git clone $GITROOT
  cd $STAR_HOME
  git pull origin master

  # set up some variables depending on release or development 
  if [ "$STREAM" = "rel" ] ; then
    SOURCE_TAG=`git branch -r | grep "origin/release" | sort -r | head -1 | sed 's/ //g'`
    STARMIRROR=/home/release/mirror
  else
    SOURCE_TAG=stable
    STARMIRROR=/home/star/mirror
  fi

  # create new branch in ccm+ repository (rel or dev) based on $SOURCE_TAG (stable in dev or head in the release branch)
  git checkout -b $STREAM $SOURCE_TAG
  git pull
  SOURCE_TAG=`echo $SOURCE_TAG | sed 's^origin/^^g'`
  make java
  
  # if we don't already have the release notes file, then generate it
  if [ ! -f ${WORKSPACE}/RELEASE_NOTES ] ; then
    make version
  else
    cp ${WORKSPACE}/RELEASE_NOTES ${WORKSPACE}/star
  fi
  if [ -z "$VERSION" ] ; then
    VERSION=`/home/test/hudson/tool/bin/get-bn $STAR_HOME/RELEASE_NOTES -bn`
  fi
}

#
# To commit github sources into star-ccm+ git (release or development)
#
commit_country() {
  # should have started with a clean workspace, but just in case
  \rm -rf $STAR_HOME/lib/i18n

  # generate the i18n properties files and get them into star/lib/i18n
  cd $STAR_HOME
  ant i18n -Di18n.lang=$COUNTRY_CODE

  # create a branch to use for the changes
  cd $I18N_HOME
  git checkout -b $VERSION

  # remove the english properties files from the working directory 
  # not sure why we should do this as the rsync will overwrite old files anyway  
  if [ -d $I18N_HOME/$COUNTRY_CODE ] ; then
    find $I18N_HOME/$COUNTRY_CODE -iname "*.properties" -not -iname "*$COUNTRY_CODE*properties" -exec \rm -rf {} \;
  fi

  # copy the english properties files from star/lib/i18n to the local i18n workspace 
  rsync -avz $STAR_HOME/lib/i18n/ $I18N_HOME/$COUNTRY_CODE/ \
    --include="*/" --include="Bundle.properties" --include="Bundle_star.properties" --include="Star.properties" \
    --exclude="*"

  if [ "$COUNTRY_CODE" = "ru" ] ; then
    MYLOCALE=ru_RU
  else
    MYLOCALE=$COUNTRY_CODE
  fi

  # detect English files that were deleted and then delete the corresponding localized files
  git status | grep deleted | sed 's/#//g' | sed 's/deleted://g' | sed "s/.properties/_$MYLOCALE.properties/g" | xargs rm -f

  git add .
  git commit -m "Update English properties files in the $COUNTRY_CODE directory from the $STREAM branch,b version $VERSION" .
}

while [ $# -gt 0 ]; do
  case "$1" in
    -branch )
      if [ $# -lt 2 ] ; then 
        usage "Error: missing argument using -branch"
      fi
      STREAM="$2"
      case "$STREAM" in
        dev | rel )
        ;;
	    
        * )
          usage "Error: -branch is valid only for dev|rel"
        ;;
      esac
      shift
    ;;

    -locale )
      if [ $# -lt 2 ] ; then
        usage "Error: missing argument using -locale"
      fi
      LOCALES="$2"
      shift
    ;;

    -help | * )
      usage
    ;;
  esac
  shift
done

if [ -z "$STREAM" ] ; then
  usage "Error: -branch is not specified"
fi
if [ -z "$LOCALES" ] ; then
  usage "Error: -locale is not specified"
fi
if [ -z "$WORKSPACE" ] ; then
  usage "Error: the WORKSPACE environment variable is not specified"
fi

# not sure why, but when using sudo the path seems to screwed up and git cannot be found
GIT_HOME=/home/star/mirror/git/latest/linux-x86_64/bin

checkout_star

IFS=,
for COUNTRY_CODE in $LOCALES ; do
  commit_country
done

cd ${I18N_HOME}
$GIT_HOME/git checkout $SOURCE_TAG
$GIT_HOME/git pull
$GIT_HOME/git merge $STREAM # into SOURCE_TAG
$GIT_HOME/git push